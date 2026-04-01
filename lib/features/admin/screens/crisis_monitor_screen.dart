import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

// ─── Models ───────────────────────────────────────────────

class _CrisisNote {
  final String id;
  final String text;
  final String adminName;
  final DateTime createdAt;

  const _CrisisNote({
    required this.id,
    required this.text,
    required this.adminName,
    required this.createdAt,
  });
}

class _ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' | 'assistant'
  final DateTime createdAt;
  final int tier; // 0 if not flagged

  const _ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.createdAt,
    required this.tier,
  });
}

class _CrisisEntry {
  final String messageId;
  final String sessionId;
  final String content;
  final String userId;
  final String userName;
  final String userEmail;
  final String? university;
  final int tier;
  final DateTime createdAt;
  bool resolved;
  DateTime? resolvedAt;
  String? assignedTo;
  List<_CrisisNote> notes;

  _CrisisEntry({
    required this.messageId,
    required this.sessionId,
    required this.content,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.university,
    required this.tier,
    required this.createdAt,
    this.resolved = false,
    this.resolvedAt,
    this.assignedTo,
    List<_CrisisNote>? notes,
  }) : notes = notes ?? [];

  _CrisisEntry copyWith({
    bool? resolved,
    DateTime? resolvedAt,
    String? assignedTo,
    List<_CrisisNote>? notes,
  }) => _CrisisEntry(
    messageId: messageId,
    sessionId: sessionId,
    content: content,
    userId: userId,
    userName: userName,
    userEmail: userEmail,
    university: university,
    tier: tier,
    createdAt: createdAt,
    resolved: resolved ?? this.resolved,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    assignedTo: assignedTo ?? this.assignedTo,
    notes: notes ?? this.notes,
  );
}

// ─── Tier Detection ───────────────────────────────────────

const _tier3Keywords = [
  'suicide', 'kill myself', 'end it all', 'dont want to live',
  'want to die', 'harm myself', 'self harm', 'overdose',
  'end my life', 'no reason to live', 'want to end',
  'take my life', 'not worth living',
];
const _tier2Keywords = [
  'hopeless', 'no point', 'cant go on', "can't go on", 'giving up',
  'worthless', 'nobody cares', 'depressed', 'crying', 'hurt myself',
  'cutting', 'not okay', 'cant handle', "can't handle",
];
const _tier1Keywords = [
  'stressed', 'overwhelmed', 'anxious', 'struggling', 'hard time',
  'exhausted', 'help me', "can't take it", 'breaking down',
  'falling apart', 'all alone', 'hate myself', 'so tired',
];

int _detectTier(String content) {
  final lower = content.toLowerCase();
  if (_tier3Keywords.any((k) => lower.contains(k))) return 3;
  if (_tier2Keywords.any((k) => lower.contains(k))) return 2;
  if (_tier1Keywords.any((k) => lower.contains(k))) return 1;
  return 0;
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

enum _TierFilter { all, critical, high, moderate }

// ─── Main Screen ──────────────────────────────────────────

class CrisisMonitorScreen extends ConsumerStatefulWidget {
  const CrisisMonitorScreen({super.key});

  @override
  ConsumerState<CrisisMonitorScreen> createState() =>
      _CrisisMonitorScreenState();
}

class _CrisisMonitorScreenState extends ConsumerState<CrisisMonitorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<_CrisisEntry> _active = [];
  List<_CrisisEntry> _resolved = [];
  bool _loading = true;
  DateTime? _lastChecked;
  Timer? _autoRefresh;
  _TierFilter _tierFilter = _TierFilter.all;
  bool _keywordPanelExpanded = false;
  String _searchQuery = '';
  bool _liveMode = true;
  RealtimeChannel? _realtimeChannel;
  int _newAlertsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
    _autoRefresh = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_liveMode) _load(silent: true);
    });
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _autoRefresh?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    final db = Supabase.instance.client;
    _realtimeChannel = db
        .channel('crisis-monitor')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            final row = payload.newRecord;
            final role = row['role'] as String? ?? '';
            final content = row['content'] as String? ?? '';
            if (role == 'user' && _detectTier(content) > 0) {
              setState(() => _newAlertsCount++);
              _load(silent: true);
            }
          },
        )
        .subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final db = Supabase.instance.client;
      final messages = await db
          .from('chat_messages')
          .select('''
            id, content, created_at, session_id,
            chat_sessions!inner(user_id, title,
              profiles!inner(id, name, email, university))
          ''')
          .eq('role', 'user')
          .order('created_at', ascending: false)
          .limit(500);

      final entries = <_CrisisEntry>[];
      for (final msg in messages) {
        final content = (msg['content'] as String? ?? '');
        final tier = _detectTier(content);
        if (tier > 0) {
          final session = msg['chat_sessions'] as Map<String, dynamic>?;
          final profile = session?['profiles'] as Map<String, dynamic>?;
          // Preserve existing notes/assignment if already loaded
          final existing = [
            ..._active, ..._resolved
          ].where((e) => e.messageId == msg['id']).firstOrNull;
          entries.add(_CrisisEntry(
            messageId: msg['id'] as String,
            sessionId: msg['session_id'] as String,
            content: content,
            createdAt: DateTime.parse(msg['created_at'] as String),
            tier: tier,
            userId: profile?['id'] as String? ?? '',
            userName: profile?['name'] as String? ?? 'Unknown',
            userEmail: profile?['email'] as String? ?? '',
            university: profile?['university'] as String?,
            resolved: existing?.resolved ?? false,
            resolvedAt: existing?.resolvedAt,
            assignedTo: existing?.assignedTo,
            notes: existing?.notes ?? [],
          ));
        }
      }

      entries.sort((a, b) {
        if (!a.resolved && b.resolved) return -1;
        if (a.resolved && !b.resolved) return 1;
        final tc = b.tier.compareTo(a.tier);
        return tc != 0 ? tc : b.createdAt.compareTo(a.createdAt);
      });

      if (mounted) {
        setState(() {
          _active = entries.where((e) => !e.resolved).toList();
          _resolved = entries.where((e) => e.resolved).toList();
          _loading = false;
          _lastChecked = DateTime.now();
          _newAlertsCount = 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _markResolved(String messageId) {
    setState(() {
      final idx = _active.indexWhere((e) => e.messageId == messageId);
      if (idx >= 0) {
        final entry = _active[idx].copyWith(
          resolved: true,
          resolvedAt: DateTime.now(),
        );
        _active.removeAt(idx);
        _resolved.insert(0, entry);
      }
    });
  }

  void _markUnresolved(String messageId) {
    setState(() {
      final idx = _resolved.indexWhere((e) => e.messageId == messageId);
      if (idx >= 0) {
        final entry = _resolved[idx].copyWith(resolved: false);
        _resolved.removeAt(idx);
        _active.insert(0, entry);
      }
    });
  }

  void _addNote(String messageId, String text) {
    setState(() {
      final noteId = DateTime.now().millisecondsSinceEpoch.toString();
      final note = _CrisisNote(
        id: noteId,
        text: text,
        adminName: 'Admin',
        createdAt: DateTime.now(),
      );
      // Try active first
      final ai = _active.indexWhere((e) => e.messageId == messageId);
      if (ai >= 0) {
        final updated = _active[ai].copyWith(
          notes: [..._active[ai].notes, note],
        );
        _active[ai] = updated;
        return;
      }
      final ri = _resolved.indexWhere((e) => e.messageId == messageId);
      if (ri >= 0) {
        final updated = _resolved[ri].copyWith(
          notes: [..._resolved[ri].notes, note],
        );
        _resolved[ri] = updated;
      }
    });
  }

  void _assignCase(String messageId, String adminName) {
    setState(() {
      final ai = _active.indexWhere((e) => e.messageId == messageId);
      if (ai >= 0) {
        _active[ai] = _active[ai].copyWith(assignedTo: adminName);
      }
    });
  }

  List<_CrisisEntry> _filtered(List<_CrisisEntry> entries) {
    var list = entries;
    switch (_tierFilter) {
      case _TierFilter.critical:
        list = list.where((e) => e.tier == 3).toList();
      case _TierFilter.high:
        list = list.where((e) => e.tier == 2).toList();
      case _TierFilter.moderate:
        list = list.where((e) => e.tier == 1).toList();
      case _TierFilter.all:
        break;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) =>
        e.userName.toLowerCase().contains(q) ||
        e.userEmail.toLowerCase().contains(q) ||
        e.content.toLowerCase().contains(q) ||
        (e.university?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    return list;
  }

  String get _lastCheckedLabel {
    if (_lastChecked == null) return 'Never';
    final diff = DateTime.now().difference(_lastChecked!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final activeTier3 = _active.where((e) => e.tier == 3).length;
    final activeTier2 = _active.where((e) => e.tier == 2).length;
    final activeTier1 = _active.where((e) => e.tier == 1).length;

    return Column(
      children: [
        // ── Header ────────────────────────────────────────
        _CrisisSummaryHeader(
          total: _active.length,
          tier3: activeTier3,
          tier2: activeTier2,
          tier1: activeTier1,
          lastChecked: _lastCheckedLabel,
          liveMode: _liveMode,
          newAlerts: _newAlertsCount,
          isMobile: isMobile,
          onRefresh: _load,
          onToggleLive: () => setState(() => _liveMode = !_liveMode),
        ),

        // ── Search Bar ────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by name, email, university or message…',
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(LucideIcons.search,
                  size: 16, color: AppColors.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x,
                          size: 14, color: AppColors.textMuted),
                      onPressed: () =>
                          setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Tier Filter Chips ─────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TierFilterChip(
                  label: 'All',
                  count: _active.length,
                  color: AppColors.textSecondary,
                  selected: _tierFilter == _TierFilter.all,
                  onTap: () =>
                      setState(() => _tierFilter = _TierFilter.all),
                ),
                const SizedBox(width: 8),
                _TierFilterChip(
                  label: 'Critical',
                  count: activeTier3,
                  color: AppColors.error,
                  selected: _tierFilter == _TierFilter.critical,
                  onTap: () =>
                      setState(() => _tierFilter = _TierFilter.critical),
                ),
                const SizedBox(width: 8),
                _TierFilterChip(
                  label: 'High Risk',
                  count: activeTier2,
                  color: AppColors.warning,
                  selected: _tierFilter == _TierFilter.high,
                  onTap: () =>
                      setState(() => _tierFilter = _TierFilter.high),
                ),
                const SizedBox(width: 8),
                _TierFilterChip(
                  label: 'Moderate',
                  count: activeTier1,
                  color: AppColors.info,
                  selected: _tierFilter == _TierFilter.moderate,
                  onTap: () =>
                      setState(() => _tierFilter = _TierFilter.moderate),
                ),
              ],
            ),
          ),
        ),

        // ── Tab Bar ───────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Active'),
                    if (_active.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _TabBadge(_active.length, AppColors.error),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Resolved'),
                    if (_resolved.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _TabBadge(_resolved.length,
                          AppColors.success.withValues(alpha: 0.8)),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'All'),
            ],
          ),
        ),

        // ── Content ───────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
              : Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _CrisisListView(
                            entries: _filtered(_active),
                            onResolve: _markResolved,
                            onContact: (e) =>
                                _showContactDialog(context, e),
                            onEscalate: (e) =>
                                _showEscalateDialog(context, e),
                            onViewChat: (e) =>
                                _showFullChatDialog(context, e),
                            onViewDetail: (e) =>
                                _showCrisisDetail(context, e),
                            onAddNote: (e) =>
                                _showAddNoteDialog(context, e),
                            onUserHistory: (e) =>
                                _showUserHistory(context, e),
                            onAssign: (e) =>
                                _showAssignDialog(context, e),
                            onQuickBan: (e) =>
                                _quickBan(context, e),
                            emptyTitle: _active.isEmpty
                                ? 'No active crises'
                                : 'No entries for this filter',
                            emptySubtitle: _active.isEmpty
                                ? 'No crisis indicators detected'
                                : 'Try a different filter or search',
                            emptyIcon: LucideIcons.shieldCheck,
                            isGreenState: _active.isEmpty,
                          ),
                          _CrisisListView(
                            entries: _filtered(_resolved),
                            onResolve: null,
                            onUnresolve: _markUnresolved,
                            onContact: (e) =>
                                _showContactDialog(context, e),
                            onEscalate: null,
                            onViewChat: (e) =>
                                _showFullChatDialog(context, e),
                            onViewDetail: (e) =>
                                _showCrisisDetail(context, e),
                            onAddNote: (e) =>
                                _showAddNoteDialog(context, e),
                            onUserHistory: (e) =>
                                _showUserHistory(context, e),
                            onAssign: null,
                            onQuickBan: null,
                            emptyTitle: 'No resolved entries',
                            emptySubtitle:
                                'Resolved crises will appear here',
                            emptyIcon: LucideIcons.circleCheck,
                            isGreenState: false,
                          ),
                          _CrisisListView(
                            entries: _filtered([
                              ..._active,
                              ..._resolved,
                            ]..sort((a, b) {
                                if (!a.resolved && b.resolved)
                                  return -1;
                                if (a.resolved && !b.resolved) return 1;
                                return b.createdAt
                                    .compareTo(a.createdAt);
                              })),
                            onResolve: _markResolved,
                            onUnresolve: _markUnresolved,
                            onContact: (e) =>
                                _showContactDialog(context, e),
                            onEscalate: (e) =>
                                _showEscalateDialog(context, e),
                            onViewChat: (e) =>
                                _showFullChatDialog(context, e),
                            onViewDetail: (e) =>
                                _showCrisisDetail(context, e),
                            onAddNote: (e) =>
                                _showAddNoteDialog(context, e),
                            onUserHistory: (e) =>
                                _showUserHistory(context, e),
                            onAssign: (e) =>
                                _showAssignDialog(context, e),
                            onQuickBan: (e) =>
                                _quickBan(context, e),
                            emptyTitle: 'No crisis entries',
                            emptySubtitle:
                                'Crisis-flagged messages will appear here',
                            emptyIcon: LucideIcons.shieldCheck,
                            isGreenState:
                                _active.isEmpty && _resolved.isEmpty,
                          ),
                        ],
                      ),
                    ),
                    _KeywordsPanel(
                      expanded: _keywordPanelExpanded,
                      onToggle: () => setState(
                          () => _keywordPanelExpanded = !_keywordPanelExpanded),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ─── View Full Chat Dialog ────────────────────────────

  Future<void> _showFullChatDialog(
      BuildContext context, _CrisisEntry entry) async {
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    // Show loading indicator immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      ),
    );

    List<_ChatMessage> messages = [];
    try {
      final db = Supabase.instance.client;
      final rows = await db
          .from('chat_messages')
          .select('id, content, role, created_at')
          .eq('session_id', entry.sessionId)
          .order('created_at', ascending: true);

      messages = (rows as List).map((r) {
        final content = r['content'] as String? ?? '';
        final role = r['role'] as String? ?? 'user';
        return _ChatMessage(
          id: r['id'] as String,
          content: content,
          role: role,
          createdAt: DateTime.parse(r['created_at'] as String),
          tier: role == 'user' ? _detectTier(content) : 0,
        );
      }).toList();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load chat: $e'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Remove loader

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.97,
          builder: (_, ctrl) => _ChatViewSheet(
            entry: entry,
            messages: messages,
            scrollCtrl: ctrl,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          child: SizedBox(
            width: 600,
            height: MediaQuery.sizeOf(context).height * 0.8,
            child: _ChatViewSheet(entry: entry, messages: messages),
          ),
        ),
      );
    }
  }

  // ─── Crisis Detail Panel ──────────────────────────────

  void _showCrisisDetail(BuildContext context, _CrisisEntry entry) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.97,
          builder: (bCtx, ctrl) => _CrisisDetailSheet(
            entry: entry,
            scrollCtrl: ctrl,
            onResolve: entry.resolved
                ? null
                : () {
                    _markResolved(entry.messageId);
                    Navigator.pop(bCtx);
                  },
            onContact: () => _showContactDialog(context, entry),
            onViewChat: () => _showFullChatDialog(context, entry),
            onEscalate: entry.resolved
                ? null
                : () => _showEscalateDialog(context, entry),
            onAddNote: (txt) => _addNote(entry.messageId, txt),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          child: SizedBox(
            width: 540,
            height: MediaQuery.sizeOf(context).height * 0.85,
            child: _CrisisDetailSheet(
              entry: entry,
              onResolve: entry.resolved
                  ? null
                  : () {
                      _markResolved(entry.messageId);
                      Navigator.pop(_);
                    },
              onContact: () => _showContactDialog(context, entry),
              onViewChat: () => _showFullChatDialog(context, entry),
              onEscalate: entry.resolved
                  ? null
                  : () => _showEscalateDialog(context, entry),
              onAddNote: (txt) => _addNote(entry.messageId, txt),
            ),
          ),
        ),
      );
    }
  }

  // ─── Add Note Dialog ──────────────────────────────────

  void _showAddNoteDialog(BuildContext context, _CrisisEntry entry) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Row(
          children: [
            const Icon(LucideIcons.notebookPen,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Add Case Note'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Case: ${entry.userName} (Tier ${entry.tier})',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Write your admin note here…',
                  border: OutlineInputBorder(
                      borderRadius: AppRadius.smAll),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide:
                        const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              if (entry.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Previous notes (${entry.notes.length}):',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                ...entry.notes.take(3).map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.text,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                            '${n.adminName} · ${_relativeTime(n.createdAt)}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              _addNote(entry.messageId, ctrl.text.trim());
              Navigator.pop(_);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note added'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  // ─── User History Dialog ──────────────────────────────

  Future<void> _showUserHistory(
      BuildContext context, _CrisisEntry entry) async {
    // Gather all flagged messages for this user across all lists
    final all = [..._active, ..._resolved];
    final userEntries = all
        .where((e) => e.userId == entry.userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  entry.userName.isNotEmpty
                      ? entry.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.userName}\'s Crisis History',
                      style: const TextStyle(fontSize: 15)),
                  Text(entry.userEmail,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          height: 400,
          child: userEntries.isEmpty
              ? const Center(child: Text('No history found'))
              : ListView.separated(
                  itemCount: userEntries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = userEntries[i];
                    final col = e.tier == 3
                        ? AppColors.error
                        : e.tier == 2
                            ? AppColors.warning
                            : AppColors.info;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: e.resolved
                            ? AppColors.surfaceVariant
                            : col.withValues(alpha: 0.06),
                        borderRadius: AppRadius.smAll,
                        border: Border(
                            left: BorderSide(color: col, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _TierBadgeSmall(tier: e.tier),
                              const SizedBox(width: 6),
                              if (e.resolved)
                                const _TierBadgeSmall(
                                    tier: -1, label: 'RESOLVED'),
                              const Spacer(),
                              Text(_relativeTime(e.createdAt),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.content.length > 120
                                ? '${e.content.substring(0, 120)}…'
                                : e.content,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          if (e.notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('${e.notes.length} admin note(s)',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(_);
              _showContactDialog(context, entry);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Contact User'),
          ),
        ],
      ),
    );
  }

  // ─── Assign Dialog ────────────────────────────────────

  void _showAssignDialog(BuildContext context, _CrisisEntry entry) {
    final admins = ['Admin', 'Dr. Sarah', 'Counselor Mike', 'Dr. Aisha'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Row(
          children: [
            Icon(LucideIcons.userCheck,
                size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Assign Case'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: admins
                .map((a) => ListTile(
                      title: Text(a,
                          style: const TextStyle(fontSize: 14)),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppColors.primaryContainer,
                        child: Text(a[0],
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                      trailing: entry.assignedTo == a
                          ? const Icon(LucideIcons.circleCheck,
                              size: 16, color: AppColors.success)
                          : null,
                      onTap: () {
                        _assignCase(entry.messageId, a);
                        Navigator.pop(_);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Case assigned to $a'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.smAll),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  // ─── Quick Ban ────────────────────────────────────────

  Future<void> _quickBan(
      BuildContext context, _CrisisEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: AppRadius.xsAll,
              ),
              child: const Icon(LucideIcons.ban,
                  size: 16, color: AppColors.error),
            ),
            const SizedBox(width: 8),
            const Text('Ban User'),
          ],
        ),
        content: Text(
          'Ban ${entry.userName} (${entry.userEmail})?\n\nThis will prevent them from logging in. You can reverse this from User Management.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Ban User'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final ok = await ref
        .read(adminProvider.notifier)
        .banUser(entry.userId, 'Crisis monitor — admin ban');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            ok ? '${entry.userName} banned' : 'Failed to ban user'),
        backgroundColor: ok ? AppColors.warning : AppColors.error,
      ));
    }
  }

  // ─── Contact Dialog ───────────────────────────────────

  void _showContactDialog(BuildContext context, _CrisisEntry entry) {
    final subjectCtrl = TextEditingController(
        text: 'We noticed you might be going through a tough time');
    final msgCtrl = TextEditingController(
      text: 'Hi ${entry.userName},\n\nWe noticed from your recent '
          'activity that you might be struggling. We\'re here to help '
          'and want you to know you\'re not alone.\n\nPlease reach out '
          'to our support team or a local crisis resource. Your '
          'wellbeing matters to us.\n\nWith care,\nMindBridge Team',
    );

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Row(
          children: [
            const Icon(LucideIcons.mail,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Contact User'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info strip
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          entry.userName.isNotEmpty
                              ? entry.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.userName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                const Icon(LucideIcons.mail,
                                    size: 10,
                                    color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                Text(entry.userEmail,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Copy email
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: entry.userEmail));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Email copied'),
                                duration: Duration(seconds: 1)),
                          );
                        },
                        icon: const Icon(LucideIcons.copy,
                            size: 14, color: AppColors.textMuted),
                        tooltip: 'Copy email',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(
                        borderRadius: AppRadius.smAll),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.smAll,
                      borderSide:
                          const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: msgCtrl,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                        borderRadius: AppRadius.smAll),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.smAll,
                      borderSide:
                          const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                // Crisis resources
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: AppRadius.smAll,
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.phone,
                              size: 12, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text(
                            'Crisis Resources (Kenya)',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• Befrienders Kenya: +254 722 178 177\n'
                        '• Niskize: 0800 723 253\n'
                        '• Red Cross: +254 703 037 000',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          // Mailto fallback
          OutlinedButton.icon(
            onPressed: () {
              final mailto =
                  'mailto:${entry.userEmail}?subject=${Uri.encodeComponent(subjectCtrl.text)}&body=${Uri.encodeComponent(msgCtrl.text)}';
              // Copy the mailto link to clipboard as fallback
              Clipboard.setData(ClipboardData(text: mailto));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Email template copied — paste in your email client'),
                  backgroundColor: AppColors.info,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 13),
            label: const Text('Copy Template'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              final success = await ref
                  .read(adminProvider.notifier)
                  .emailUser(
                    toEmail: entry.userEmail,
                    toName: entry.userName,
                    subject: subjectCtrl.text,
                    message: msgCtrl.text,
                    fromAdminName: 'MindBridge Admin',
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? 'Email sent to ${entry.userName}'
                      : 'Backend offline — use "Copy Template" to send manually'),
                  backgroundColor:
                      success ? AppColors.success : AppColors.warning,
                  duration: const Duration(seconds: 4),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Send via Backend'),
          ),
        ],
      ),
    );
  }

  // ─── Escalate Dialog ──────────────────────────────────

  void _showEscalateDialog(BuildContext context, _CrisisEntry entry) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: AppRadius.xsAll,
              ),
              child: const Icon(LucideIcons.triangleAlert,
                  size: 16, color: AppColors.error),
            ),
            const SizedBox(width: 8),
            const Text('Escalate Case'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${entry.userName} (${entry.userEmail})',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (entry.university != null) ...[
                const SizedBox(height: 4),
                Text('University: ${entry.university}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Escalation notes (optional)',
                  alignLabelWithHint: true,
                  border:
                      OutlineInputBorder(borderRadius: AppRadius.smAll),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide:
                        const BorderSide(color: AppColors.error),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Escalation Protocol',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Contact the university counseling center directly\n'
                      '2. Reach out to the student\'s emergency contact if available\n'
                      '3. If immediate danger, contact emergency services\n'
                      '4. Document all actions in the case notes',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Emergency: 999 (Kenya) / 112',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              final notes = notesCtrl.text.trim();
              if (notes.isNotEmpty) {
                _addNote(entry.messageId, 'ESCALATED: $notes');
              } else {
                _addNote(entry.messageId,
                    'ESCALATED — protocol initiated at ${DateFormat('MMM d, y HH:mm').format(DateTime.now())}');
              }
              Navigator.pop(dCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Escalation logged. Follow protocol above.'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Log Escalation'),
          ),
        ],
      ),
    );
  }
}

// ─── Chat View Sheet ──────────────────────────────────────

class _ChatViewSheet extends StatelessWidget {
  final _CrisisEntry entry;
  final List<_ChatMessage> messages;
  final ScrollController? scrollCtrl;

  const _ChatViewSheet({
    required this.entry,
    required this.messages,
    this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: scrollCtrl != null
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : AppRadius.lgAll,
      ),
      child: Column(
        children: [
          // Handle
          if (scrollCtrl != null)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    entry.userName.isNotEmpty
                        ? entry.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry.userName}\'s Chat Session',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text(
                        '${messages.length} messages · ${entry.userEmail}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                // Flagged count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.flag,
                          size: 11, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        '${messages.where((m) => m.tier > 0).length} flagged',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x,
                      size: 18, color: AppColors.textMuted),
                  style: IconButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('No messages found',
                        style: TextStyle(color: AppColors.textMuted)))
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      final isUser = m.role == 'user';
                      final isFlagged = m.tier > 0;
                      final flagColor = m.tier == 3
                          ? AppColors.error
                          : m.tier == 2
                              ? AppColors.warning
                              : AppColors.info;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Role label
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 3, left: 4, right: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isUser ? entry.userName : 'Maya AI',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _relativeTime(m.createdAt),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted),
                                  ),
                                  if (isFlagged) ...[
                                    const SizedBox(width: 4),
                                    Icon(LucideIcons.flag,
                                        size: 10, color: flagColor),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(
                                  maxWidth: 400),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isFlagged
                                    ? flagColor.withValues(alpha: 0.08)
                                    : isUser
                                        ? AppColors.primaryContainer
                                        : AppColors.surfaceVariant,
                                borderRadius: AppRadius.mdAll,
                                border: isFlagged
                                    ? Border.all(
                                        color: flagColor
                                            .withValues(alpha: 0.4))
                                    : null,
                              ),
                              child: isFlagged
                                  ? _HighlightedText(
                                      text: m.content,
                                      highlightColor: flagColor,
                                    )
                                  : Text(
                                      m.content,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          height: 1.4),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Crisis Detail Sheet ──────────────────────────────────

class _CrisisDetailSheet extends StatefulWidget {
  final _CrisisEntry entry;
  final ScrollController? scrollCtrl;
  final VoidCallback? onResolve;
  final VoidCallback onContact;
  final VoidCallback onViewChat;
  final VoidCallback? onEscalate;
  final void Function(String) onAddNote;

  const _CrisisDetailSheet({
    required this.entry,
    this.scrollCtrl,
    this.onResolve,
    required this.onContact,
    required this.onViewChat,
    this.onEscalate,
    required this.onAddNote,
  });

  @override
  State<_CrisisDetailSheet> createState() => _CrisisDetailSheetState();
}

class _CrisisDetailSheetState extends State<_CrisisDetailSheet> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Color get _tc => widget.entry.tier == 3
      ? AppColors.error
      : widget.entry.tier == 2
          ? AppColors.warning
          : AppColors.info;

  String get _tl => widget.entry.tier == 3
      ? 'CRITICAL'
      : widget.entry.tier == 2
          ? 'HIGH RISK'
          : 'MODERATE';

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.scrollCtrl != null
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : AppRadius.lgAll,
      ),
      child: Column(
        children: [
          if (widget.scrollCtrl != null)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: _tc.withValues(alpha: 0.04),
              border: Border(
                bottom: const BorderSide(color: AppColors.border),
                left: BorderSide(color: _tc, width: 4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tc.withValues(alpha: 0.12),
                    borderRadius: AppRadius.xsAll,
                  ),
                  child: Text(_tl,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _tc)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Crisis Detail',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x,
                      size: 18, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollCtrl,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: _tc.withValues(alpha: 0.12),
                          child: Text(
                            e.userName.isNotEmpty
                                ? e.userName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _tc),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.userName,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              Text(e.userEmail,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted)),
                              if (e.university != null)
                                Text(e.university!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Flagged message
                  _SectionLabel('Flagged Message', LucideIcons.flag, _tc),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _tc.withValues(alpha: 0.05),
                      borderRadius: AppRadius.smAll,
                      border:
                          Border.all(color: _tc.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                            text: e.content, highlightColor: _tc),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MMM d, y · h:mm a')
                              .format(e.createdAt),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Assignment
                  if (e.assignedTo != null) ...[
                    _SectionLabel(
                        'Assigned To', LucideIcons.userCheck, AppColors.primary),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text(e.assignedTo!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.primary)),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Quick actions
                  _SectionLabel(
                      'Actions', LucideIcons.zap, AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.onResolve != null)
                        _ActionBtn(
                          icon: LucideIcons.circleCheck,
                          label: 'Resolve',
                          color: AppColors.success,
                          onTap: widget.onResolve!,
                        ),
                      _ActionBtn(
                        icon: LucideIcons.messageCircle,
                        label: 'View Chat',
                        color: AppColors.info,
                        onTap: widget.onViewChat,
                      ),
                      _ActionBtn(
                        icon: LucideIcons.mail,
                        label: 'Contact',
                        color: AppColors.primary,
                        onTap: widget.onContact,
                      ),
                      if (widget.onEscalate != null)
                        _ActionBtn(
                          icon: LucideIcons.triangleAlert,
                          label: 'Escalate',
                          color: AppColors.error,
                          onTap: widget.onEscalate!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Notes
                  _SectionLabel(
                      'Case Notes (${e.notes.length})',
                      LucideIcons.notebookPen,
                      AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _noteCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Add a note…',
                            hintStyle: const TextStyle(
                                fontSize: 13, color: AppColors.textMuted),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.smAll,
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_noteCtrl.text.trim().isEmpty) return;
                          widget.onAddNote(_noteCtrl.text.trim());
                          _noteCtrl.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.smAll),
                        ),
                        child: const Text('Add',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  if (e.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...e.notes.reversed.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: AppRadius.smAll,
                              border: Border.all(
                                  color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(n.text,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  '${n.adminName} · ${DateFormat('MMM d, y HH:mm').format(n.createdAt)}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Crisis Summary Header ────────────────────────────────

class _CrisisSummaryHeader extends StatelessWidget {
  final int total, tier3, tier2, tier1, newAlerts;
  final String lastChecked;
  final bool liveMode;
  final bool isMobile;
  final VoidCallback onRefresh;
  final VoidCallback onToggleLive;

  const _CrisisSummaryHeader({
    required this.total,
    required this.tier3,
    required this.tier2,
    required this.tier1,
    required this.newAlerts,
    required this.lastChecked,
    required this.liveMode,
    required this.isMobile,
    required this.onRefresh,
    required this.onToggleLive,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, 16, 16, isMobile ? 8 : 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: total > 0
                        ? AppColors.errorContainer
                        : AppColors.successContainer,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(
                    total > 0
                        ? LucideIcons.triangleAlert
                        : LucideIcons.shieldCheck,
                    color: total > 0
                        ? AppColors.error
                        : AppColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Crisis Monitor',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary),
                      ),
                      if (!isMobile)
                        const Text(
                          'AI-scanned chat messages for crisis indicators',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                // New alerts badge
                if (newAlerts > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.bellRing,
                            size: 11, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          '$newAlerts new',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                // Live toggle
                GestureDetector(
                  onTap: onToggleLive,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: liveMode
                          ? AppColors.successContainer
                          : AppColors.surfaceVariant,
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(
                          color: liveMode
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: liveMode
                                ? AppColors.success
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          liveMode ? 'LIVE' : 'PAUSED',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: liveMode
                                  ? AppColors.success
                                  : AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (!isMobile)
                  Text(
                    'Checked: $lastChecked',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(LucideIcons.refreshCw,
                      size: 16, color: AppColors.textMuted),
                  tooltip: 'Refresh now',
                  style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(6)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            isMobile
                ? Row(
                    children: [
                      _SummaryCounter(
                          label: 'Active',
                          value: total,
                          color: total > 0
                              ? AppColors.error
                              : AppColors.success),
                      const SizedBox(width: 8),
                      _SummaryCounter(
                          label: 'T3',
                          value: tier3,
                          color: AppColors.error),
                      const SizedBox(width: 8),
                      _SummaryCounter(
                          label: 'T2',
                          value: tier2,
                          color: AppColors.warning),
                      const SizedBox(width: 8),
                      _SummaryCounter(
                          label: 'T1',
                          value: tier1,
                          color: AppColors.info),
                    ],
                  )
                : Row(
                    children: [
                      _SummaryCounter(
                        label: 'Total Active',
                        value: total,
                        color: total > 0
                            ? AppColors.error
                            : AppColors.success,
                        large: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            _SummaryCounter(
                                label: 'Critical (T3)',
                                value: tier3,
                                color: AppColors.error),
                            const SizedBox(width: 8),
                            _SummaryCounter(
                                label: 'High (T2)',
                                value: tier2,
                                color: AppColors.warning),
                            const SizedBox(width: 8),
                            _SummaryCounter(
                                label: 'Moderate (T1)',
                                value: tier1,
                                color: AppColors.info),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      );
}

class _SummaryCounter extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool large;

  const _SummaryCounter({
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: large ? 16 : 12, vertical: large ? 12 : 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                  fontSize: large ? 28 : 18,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
}

// ─── Tier Filter Chip ─────────────────────────────────────

class _TierFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TierFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: AppRadius.pillAll,
            border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : color,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.3)
                      : color.withValues(alpha: 0.15),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : color),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Crisis List View ─────────────────────────────────────

class _CrisisListView extends StatelessWidget {
  final List<_CrisisEntry> entries;
  final ValueChanged<String>? onResolve;
  final ValueChanged<String>? onUnresolve;
  final ValueChanged<_CrisisEntry> onContact;
  final ValueChanged<_CrisisEntry>? onEscalate;
  final ValueChanged<_CrisisEntry> onViewChat;
  final ValueChanged<_CrisisEntry> onViewDetail;
  final ValueChanged<_CrisisEntry> onAddNote;
  final ValueChanged<_CrisisEntry> onUserHistory;
  final ValueChanged<_CrisisEntry>? onAssign;
  final ValueChanged<_CrisisEntry>? onQuickBan;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final bool isGreenState;

  const _CrisisListView({
    required this.entries,
    required this.onResolve,
    this.onUnresolve,
    required this.onContact,
    required this.onEscalate,
    required this.onViewChat,
    required this.onViewDetail,
    required this.onAddNote,
    required this.onUserHistory,
    required this.onAssign,
    required this.onQuickBan,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.isGreenState,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isGreenState
                    ? AppColors.successContainer
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon,
                  size: 48,
                  color: isGreenState
                      ? AppColors.success
                      : AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(emptySubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _CrisisCard(
        entry: entries[i],
        onResolve: onResolve,
        onUnresolve: onUnresolve,
        onContact: onContact,
        onEscalate: onEscalate,
        onViewChat: onViewChat,
        onViewDetail: onViewDetail,
        onAddNote: onAddNote,
        onUserHistory: onUserHistory,
        onAssign: onAssign,
        onQuickBan: onQuickBan,
        delay: Duration(milliseconds: i * 40),
      ),
    );
  }
}

// ─── Crisis Card ──────────────────────────────────────────

class _CrisisCard extends StatefulWidget {
  final _CrisisEntry entry;
  final ValueChanged<String>? onResolve;
  final ValueChanged<String>? onUnresolve;
  final ValueChanged<_CrisisEntry> onContact;
  final ValueChanged<_CrisisEntry>? onEscalate;
  final ValueChanged<_CrisisEntry> onViewChat;
  final ValueChanged<_CrisisEntry> onViewDetail;
  final ValueChanged<_CrisisEntry> onAddNote;
  final ValueChanged<_CrisisEntry> onUserHistory;
  final ValueChanged<_CrisisEntry>? onAssign;
  final ValueChanged<_CrisisEntry>? onQuickBan;
  final Duration delay;

  const _CrisisCard({
    required this.entry,
    required this.onResolve,
    this.onUnresolve,
    required this.onContact,
    required this.onEscalate,
    required this.onViewChat,
    required this.onViewDetail,
    required this.onAddNote,
    required this.onUserHistory,
    required this.onAssign,
    required this.onQuickBan,
    required this.delay,
  });

  @override
  State<_CrisisCard> createState() => _CrisisCardState();
}

class _CrisisCardState extends State<_CrisisCard> {
  bool _expanded = false;

  Color get _tc => widget.entry.tier == 3
      ? AppColors.error
      : widget.entry.tier == 2
          ? AppColors.warning
          : AppColors.info;

  String get _tl => widget.entry.tier == 3
      ? 'CRITICAL'
      : widget.entry.tier == 2
          ? 'HIGH RISK'
          : 'MODERATE';

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;

    Widget card = InkWell(
      onTap: () => widget.onViewDetail(e),
      borderRadius: AppRadius.lgAll,
      child: Container(
        decoration: BoxDecoration(
          color: e.resolved ? AppColors.surfaceVariant : Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border(
            left: BorderSide(color: _tc, width: 4),
            top: const BorderSide(color: AppColors.border),
            right: const BorderSide(color: AppColors.border),
            bottom: const BorderSide(color: AppColors.border),
          ),
          boxShadow: e.resolved ? [] : AppShadow.sm,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────
              Row(
                children: [
                  _TierBadgeSmall(tier: e.tier),
                  const SizedBox(width: 6),
                  if (e.resolved)
                    const _TierBadgeSmall(
                        tier: -1, label: 'RESOLVED'),
                  if (e.assignedTo != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.userCheck,
                              size: 9, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(e.assignedTo!,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                  if (e.notes.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: AppRadius.pillAll,
                        border:
                            Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.notebookPen,
                              size: 9,
                              color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text('${e.notes.length}',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _relativeTime(e.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── User Info ─────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _tc.withValues(alpha: 0.1),
                    child: Text(
                      e.userName.isNotEmpty
                          ? e.userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _tc),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.userName,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: e.resolved
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary)),
                        Text(e.userEmail,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (e.university != null)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Text(
                        e.university!,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Flagged Message ───────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _tc.withValues(alpha: 0.05),
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                      color: _tc.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.messageCircle,
                            size: 10, color: _tc),
                        const SizedBox(width: 4),
                        Text('Flagged Message',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _tc)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _expanded = !_expanded),
                          child: Text(
                            _expanded ? 'Show less' : 'Show more',
                            style: TextStyle(
                                fontSize: 10,
                                color: _tc,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _HighlightedText(
                      text: _expanded
                          ? e.content
                          : (e.content.length > 130
                              ? '${e.content.substring(0, 130)}…'
                              : e.content),
                      highlightColor: _tc,
                    ),
                  ],
                ),
              ),
              // Resolved info
              if (e.resolved && e.resolvedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Resolved ${_relativeTime(e.resolvedAt!)} · ${DateFormat('MMM d, y').format(e.resolvedAt!)}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.success,
                      fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 10),
              // ── Actions ───────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (widget.onResolve != null && !e.resolved) ...[
                      _CrisisActionBtn(
                        icon: LucideIcons.circleCheck,
                        label: 'Resolve',
                        color: AppColors.success,
                        onTap: () =>
                            widget.onResolve!(e.messageId),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (widget.onUnresolve != null && e.resolved) ...[
                      _CrisisActionBtn(
                        icon: LucideIcons.rotateCcw,
                        label: 'Re-open',
                        color: AppColors.warning,
                        onTap: () =>
                            widget.onUnresolve!(e.messageId),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _CrisisActionBtn(
                      icon: LucideIcons.messageCircle,
                      label: 'View Chat',
                      color: AppColors.info,
                      onTap: () => widget.onViewChat(e),
                    ),
                    const SizedBox(width: 6),
                    _CrisisActionBtn(
                      icon: LucideIcons.mail,
                      label: 'Contact',
                      color: AppColors.primary,
                      onTap: () => widget.onContact(e),
                    ),
                    const SizedBox(width: 6),
                    _CrisisActionBtn(
                      icon: LucideIcons.history,
                      label: 'History',
                      color: AppColors.textSecondary,
                      onTap: () => widget.onUserHistory(e),
                    ),
                    const SizedBox(width: 6),
                    _CrisisActionBtn(
                      icon: LucideIcons.notebookPen,
                      label: 'Note',
                      color: AppColors.textSecondary,
                      onTap: () => widget.onAddNote(e),
                    ),
                    if (widget.onAssign != null && !e.resolved) ...[
                      const SizedBox(width: 6),
                      _CrisisActionBtn(
                        icon: LucideIcons.userCheck,
                        label: 'Assign',
                        color: AppColors.primary,
                        onTap: () => widget.onAssign!(e),
                      ),
                    ],
                    if (widget.onEscalate != null && !e.resolved) ...[
                      const SizedBox(width: 6),
                      _CrisisActionBtn(
                        icon: LucideIcons.triangleAlert,
                        label: 'Escalate',
                        color: AppColors.warning,
                        onTap: () => widget.onEscalate!(e),
                      ),
                    ],
                    if (widget.onQuickBan != null && !e.resolved) ...[
                      const SizedBox(width: 6),
                      _CrisisActionBtn(
                        icon: LucideIcons.ban,
                        label: 'Ban',
                        color: AppColors.error,
                        onTap: () => widget.onQuickBan!(e),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (e.tier == 3 && !e.resolved) {
      card = card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .custom(
            duration: 1200.ms,
            builder: (ctx, value, child) => Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.3 * value),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          );
    }

    return card
        .animate(delay: widget.delay)
        .fadeIn(duration: 250.ms)
        .slideX(begin: -0.02);
  }
}

// ─── Helpers ──────────────────────────────────────────────

class _TierBadgeSmall extends StatelessWidget {
  final int tier;
  final String? label;

  const _TierBadgeSmall({required this.tier, this.label});

  @override
  Widget build(BuildContext context) {
    final Color col;
    final String txt;
    if (tier == -1) {
      col = AppColors.success;
      txt = label ?? 'RESOLVED';
    } else if (tier == 3) {
      col = AppColors.error;
      txt = label ?? 'CRITICAL';
    } else if (tier == 2) {
      col = AppColors.warning;
      txt = label ?? 'HIGH';
    } else {
      col = AppColors.info;
      txt = label ?? 'MODERATE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: col.withValues(alpha: 0.35)),
      ),
      child: Text(txt,
          style: TextStyle(
              color: col,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SectionLabel(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ─── Highlighted Text ─────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final Color highlightColor;

  static const _allKeywords = [
    ..._tier3Keywords, ..._tier2Keywords, ..._tier1Keywords,
  ];

  const _HighlightedText(
      {required this.text, required this.highlightColor});

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    final matches = <MapEntry<int, String>>[];
    for (final kw in _allKeywords) {
      int idx = lower.indexOf(kw);
      while (idx >= 0) {
        matches.add(MapEntry(idx, kw));
        idx = lower.indexOf(kw, idx + 1);
      }
    }
    matches.sort((a, b) => a.key.compareTo(b.key));
    int cursor = 0;
    for (final m in matches) {
      if (m.key < cursor) continue;
      if (m.key > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, m.key),
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(m.key, m.key + m.value.length),
        style: TextStyle(
          fontSize: 13,
          color: highlightColor,
          fontWeight: FontWeight.w700,
          backgroundColor: highlightColor.withValues(alpha: 0.12),
        ),
      ));
      cursor = m.key + m.value.length;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary),
      ));
    }
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─── Crisis Action Button ─────────────────────────────────

class _CrisisActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CrisisActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

// ─── Tab Badge ────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _TabBadge(this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration:
            BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '$count',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800),
          ),
        ),
      );
}

// ─── Keywords Reference Panel ─────────────────────────────

class _KeywordsPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _KeywordsPanel(
      {required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(LucideIcons.bookOpen,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    const Text(
                      'Keyword Reference',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Icon(
                      expanded
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronUp,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _KeywordTier(
                      label: 'Critical — Tier 3',
                      color: AppColors.error,
                      keywords: _tier3Keywords,
                    ),
                    const SizedBox(height: 8),
                    _KeywordTier(
                      label: 'High Risk — Tier 2',
                      color: AppColors.warning,
                      keywords: _tier2Keywords,
                    ),
                    const SizedBox(height: 8),
                    _KeywordTier(
                      label: 'Moderate — Tier 1',
                      color: AppColors.info,
                      keywords: _tier1Keywords,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 150.ms),
          ],
        ),
      );
}

class _KeywordTier extends StatelessWidget {
  final String label;
  final Color color;
  final List<String> keywords;

  const _KeywordTier({
    required this.label,
    required this.color,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: AppRadius.smAll,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: keywords
                  .map((kw) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(kw,
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
            ),
          ],
        ),
      );
}
