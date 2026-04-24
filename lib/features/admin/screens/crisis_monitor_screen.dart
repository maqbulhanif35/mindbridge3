import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/crisis_ml_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum _Status {
  newCase,
  acknowledged,
  inProgress,
  escalated,
  resolved,
  closed;

  String get label => switch (this) {
    newCase      => 'New',
    acknowledged => 'Acknowledged',
    inProgress   => 'In Progress',
    escalated    => 'Escalated',
    resolved     => 'Resolved',
    closed       => 'Closed',
  };

  Color get color => switch (this) {
    newCase      => AppColors.error,
    acknowledged => AppColors.warning,
    inProgress   => AppColors.info,
    escalated    => const Color(0xFF7C3AED),
    resolved     => AppColors.success,
    closed       => AppColors.textMuted,
  };

  IconData get icon => switch (this) {
    newCase      => LucideIcons.circleAlert,
    acknowledged => LucideIcons.eye,
    inProgress   => LucideIcons.clock,
    escalated    => LucideIcons.triangleAlert,
    resolved     => LucideIcons.circleCheck,
    closed       => LucideIcons.archive,
  };

  bool get isActive => this != _Status.resolved && this != _Status.closed;
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _Note {
  final String id;
  final String text;
  final String author;
  final DateTime at;
  const _Note({required this.id, required this.text, required this.author, required this.at});
}

class _ContactLog {
  final String method;
  final String note;
  final DateTime at;
  const _ContactLog({required this.method, required this.note, required this.at});
}

class _Case {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? university;
  final String content;
  final int tier;
  final DateTime createdAt;
  _Status status;
  double riskScore;
  /// ML model crisis probability (0.0–1.0). Null until background scoring completes.
  double? mlScore;
  String? assignedTo;
  String? escalationTarget;
  DateTime? acknowledgedAt;
  DateTime? resolvedAt;
  List<_Note> notes;
  List<_ContactLog> contacts;
  List<String> categories;
  bool flagged;

  _Case({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.university,
    required this.content,
    required this.tier,
    required this.createdAt,
    this.status = _Status.newCase,
    this.riskScore = 0,
    this.mlScore,
    this.assignedTo,
    this.escalationTarget,
    this.acknowledgedAt,
    this.resolvedAt,
    List<_Note>? notes,
    List<_ContactLog>? contacts,
    List<String>? categories,
    this.flagged = false,
  })  : notes = notes ?? [],
        contacts = contacts ?? [],
        categories = categories ?? [];

  Duration get age => DateTime.now().difference(createdAt);
  bool get isActive => status.isActive;
  bool get isOverSla => isActive && age > _slaDuration(tier);
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyword Lists (4-tier)
// ─────────────────────────────────────────────────────────────────────────────

const _t4 = [
  'going to kill myself', 'have a plan', 'goodbye everyone', 'last message',
  'ending it tonight', 'have the pills ready', 'already decided',
  'by the time you read this', 'farewell', 'won\'t be here tomorrow',
  'tonight is my last', 'saying my goodbyes',
];

const _t3 = [
  'suicidal', 'suicide', 'kill myself', 'end my life', 'want to die',
  'take my life', 'no reason to live', 'rather be dead', 'better off dead',
  'not worth living', 'end it all', 'don\'t want to exist',
  'wishing i was dead', 'wish i could disappear forever',
];

const _t2 = [
  'self harm', 'self-harm', 'hurting myself', 'cutting myself',
  'hurt myself', 'hopeless', 'worthless', 'don\'t want to be here',
  'can\'t go on', 'give up on life', 'no point anymore',
  'everyone would be better without me', 'can\'t keep going',
  'nothing to live for', 'too tired to continue',
];

const _t1 = [
  'overwhelmed', 'can\'t cope', 'breaking down', 'falling apart',
  'exhausted by life', 'deeply depressed', 'completely lost',
  'no hope', 'can\'t handle this', 'rock bottom', 'losing my mind',
  'anxiety is unbearable', 'crying all the time', 'don\'t see the point',
];

int _detectTier(String content) {
  final lower = content.toLowerCase();
  for (final k in _t4) if (lower.contains(k)) return 4;
  for (final k in _t3) if (lower.contains(k)) return 3;
  for (final k in _t2) if (lower.contains(k)) return 2;
  for (final k in _t1) if (lower.contains(k)) return 1;
  return 0;
}

List<String> _detectCategories(String content) {
  final lower = content.toLowerCase();
  final cats = <String>[];
  if (lower.contains('suicid') || lower.contains('kill myself') || lower.contains('end my life')) cats.add('Suicidal Ideation');
  if (lower.contains('self harm') || lower.contains('cutting') || lower.contains('hurt myself')) cats.add('Self-Harm');
  if (lower.contains('anxi') || lower.contains('panic')) cats.add('Anxiety/Panic');
  if (lower.contains('depress')) cats.add('Depression');
  if (lower.contains('abus') || lower.contains('assault') || lower.contains('violen')) cats.add('Abuse/Violence');
  if (lower.contains('drug') || lower.contains('overdose') || lower.contains('substance')) cats.add('Substance Use');
  if (lower.contains('eating') || lower.contains('starv') || lower.contains('purge')) cats.add('Eating Disorder');
  if (lower.contains('alone') || lower.contains('lonely') || lower.contains('isolated')) cats.add('Isolation');
  if (lower.contains('academ') || lower.contains('exam') || lower.contains('fail')) cats.add('Academic Stress');
  return cats;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Duration _slaDuration(int tier) => switch (tier) {
  4 => const Duration(minutes: 5),
  3 => const Duration(minutes: 15),
  2 => const Duration(minutes: 30),
  _ => const Duration(hours: 2),
};

Color _tierColor(int tier) => switch (tier) {
  4 => const Color(0xFF991B1B),
  3 => AppColors.error,
  2 => AppColors.warning,
  _ => AppColors.info,
};

String _tierLabel(int tier) => switch (tier) {
  4 => 'IMMINENT',
  3 => 'CRITICAL',
  2 => 'HIGH RISK',
  _ => 'MODERATE',
};

Color _riskColor(double score) {
  if (score >= 70) return AppColors.error;
  if (score >= 45) return AppColors.warning;
  return AppColors.info;
}

String _relTime(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

String _slaText(Duration age, int tier) {
  final sla = _slaDuration(tier);
  if (age > sla) {
    final over = age - sla;
    return over.inMinutes < 60 ? '+${over.inMinutes}m OVERDUE' : '+${over.inHours}h OVERDUE';
  }
  final rem = sla - age;
  return rem.inMinutes < 60 ? '${rem.inMinutes}m left' : '${rem.inHours}h left';
}

Color _slaColor(Duration age, int tier) {
  final sla = _slaDuration(tier);
  if (age > sla) return AppColors.error;
  if (age.inSeconds / sla.inSeconds > 0.75) return AppColors.warning;
  return AppColors.success;
}

double _calcRisk(int tier, {bool late = false, bool repeated = false}) {
  double base = switch (tier) { 4 => 92, 3 => 72, 2 => 48, _ => 22 };
  if (repeated) base += 8;
  if (late) base += 5;
  return base.clamp(0, 100);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class CrisisMonitorScreen extends ConsumerStatefulWidget {
  const CrisisMonitorScreen({super.key});
  @override
  ConsumerState<CrisisMonitorScreen> createState() => _State();
}

class _State extends ConsumerState<CrisisMonitorScreen>
    with SingleTickerProviderStateMixin {
  List<_Case> _cases = [];
  bool _loading = true;
  bool _liveMode = true;
  String _search = '';
  int? _filterTier;
  _Status? _filterStatus;
  bool _unassignedOnly = false;
  Set<String> _selected = {};
  _Case? _detail;
  int _newAlerts = 0;
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  Timer? _ticker;
  RealtimeChannel? _channel;

  // ── Getters ──────────────────────────────────────────────

  List<_Case> get _new    => _filter(_cases.where((c) => c.status == _Status.newCase).toList());
  List<_Case> get _active => _filter(_cases.where((c) =>
    c.status == _Status.acknowledged ||
    c.status == _Status.inProgress ||
    c.status == _Status.escalated).toList());
  List<_Case> get _done   => _filter(_cases.where((c) =>
    c.status == _Status.resolved ||
    c.status == _Status.closed).toList());

  List<_Case> _filter(List<_Case> list) {
    var r = list;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      r = r.where((c) =>
        c.userName.toLowerCase().contains(q) ||
        c.userEmail.toLowerCase().contains(q) ||
        c.content.toLowerCase().contains(q) ||
        (c.university?.toLowerCase().contains(q) ?? false)).toList();
    }
    if (_filterTier != null) r = r.where((c) => c.tier == _filterTier).toList();
    if (_filterStatus != null) r = r.where((c) => c.status == _filterStatus).toList();
    if (_unassignedOnly) r = r.where((c) => c.assignedTo == null).toList();
    return r;
  }

  int get _overdueCount => _cases.where((c) => c.isOverSla).length;
  int get _criticalCount => _cases.where((c) => c.tier >= 3 && c.isActive).length;

  // ── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});           // refresh SLA timers
      if (_liveMode) _load(silent: true);
    });
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ticker?.cancel();
    _channel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client
      .channel('crisis-v5')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        callback: (p) {
          final row = p.newRecord;
          if ((row['role'] as String? ?? '') == 'user') {
            final t = _detectTier(row['content'] as String? ?? '');
            if (t > 0) {
              if (mounted) setState(() => _newAlerts++);
              _load(silent: true);
            }
          }
        },
      ).subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
        .from('chat_messages')
        .select('''
          id, content, created_at, session_id,
          chat_sessions!inner(user_id,
            profiles!inner(id, name, email, university))
        ''')
        .eq('role', 'user')
        .order('created_at', ascending: false)
        .limit(600);

      final entries = <_Case>[];
      for (final msg in rows) {
        final content = (msg['content'] as String? ?? '');
        final tier = _detectTier(content);
        if (tier == 0) continue;
        final session = msg['chat_sessions'] as Map<String, dynamic>?;
        final profile = session?['profiles'] as Map<String, dynamic>?;
        final created = DateTime.tryParse(msg['created_at'] as String? ?? '') ?? DateTime.now();
        final uid = profile?['id'] as String? ?? '';
        final existing = _cases.where((c) => c.id == msg['id']).firstOrNull;
        final repeated = entries.any((e) => e.userId == uid);
        final lateNight = created.hour >= 22 || created.hour <= 5;
        entries.add(_Case(
          id: msg['id'] as String,
          userId: uid,
          userName: profile?['name'] as String? ?? 'Unknown',
          userEmail: profile?['email'] as String? ?? '',
          university: profile?['university'] as String?,
          content: content,
          tier: tier,
          createdAt: created,
          status: existing?.status ?? _Status.newCase,
          riskScore: _calcRisk(tier, late: lateNight, repeated: repeated),
          assignedTo: existing?.assignedTo,
          escalationTarget: existing?.escalationTarget,
          acknowledgedAt: existing?.acknowledgedAt,
          resolvedAt: existing?.resolvedAt,
          notes: existing?.notes ?? [],
          contacts: existing?.contacts ?? [],
          categories: _detectCategories(content),
          flagged: existing?.flagged ?? false,
        ));
      }

      entries.sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        final tc = b.tier.compareTo(a.tier);
        if (tc != 0) return tc;
        if (a.isOverSla && !b.isOverSla) return -1;
        if (!a.isOverSla && b.isOverSla) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (mounted) setState(() {
        _cases = entries;
        _loading = false;
        _newAlerts = 0;
      });

      // Score top 50 active cases with the ML model in the background.
      // Updates roll in one-by-one as each inference completes (~15 ms each).
      _scoreWithMl(entries.where((c) => c.isActive).take(50).toList());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs ML inference on [cases] sequentially in the background isolate.
  /// Each result triggers a micro setState so the badge appears progressively.
  Future<void> _scoreWithMl(List<_Case> cases) async {
    if (!CrisisMlService.isAvailable) return;
    for (final c in cases) {
      if (!mounted) return;
      final score = await CrisisMlService.score(c.content);
      if (score.available && mounted) {
        setState(() => c.mlScore = score.crisis);
      }
    }
  }

  // ── Mutations ────────────────────────────────────────────

  void _setStatus(String id, _Status s) => setState(() {
    final c = _cases.firstWhere((c) => c.id == id);
    c.status = s;
    if (s == _Status.acknowledged) c.acknowledgedAt = DateTime.now();
    if (s == _Status.resolved || s == _Status.closed) c.resolvedAt = DateTime.now();
    if (_detail?.id == id) _detail = c;
  });

  void _addNote(String id, String text) => setState(() {
    final c = _cases.firstWhere((c) => c.id == id);
    c.notes.add(_Note(id: '${DateTime.now().millisecondsSinceEpoch}', text: text, author: 'Admin', at: DateTime.now()));
    if (_detail?.id == id) _detail = c;
  });

  void _assign(String id, String? admin) => setState(() {
    _cases.firstWhere((c) => c.id == id).assignedTo = admin;
  });

  void _toggleFlag(String id) => setState(() {
    final c = _cases.firstWhere((c) => c.id == id);
    c.flagged = !c.flagged;
    if (_detail?.id == id) _detail = c;
  });

  void _doEscalate(String id, String target) => setState(() {
    final c = _cases.firstWhere((c) => c.id == id);
    c.status = _Status.escalated;
    c.escalationTarget = target;
    c.contacts.add(_ContactLog(method: 'escalation', note: 'Escalated to $target', at: DateTime.now()));
    if (_detail?.id == id) _detail = c;
  });

  void _bulkAck() => setState(() {
    for (final id in _selected) {
      final c = _cases.firstWhere((c) => c.id == id, orElse: () => _cases.first);
      if (c.status == _Status.newCase) { c.status = _Status.acknowledged; c.acknowledgedAt = DateTime.now(); }
    }
    _selected.clear();
  });

  void _bulkResolve() => setState(() {
    for (final id in _selected) {
      final c = _cases.firstWhere((c) => c.id == id, orElse: () => _cases.first);
      c.status = _Status.resolved;
      c.resolvedAt = DateTime.now();
    }
    _selected.clear();
  });

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 960;
    final hasCritical = _criticalCount > 0;

    return Column(
      children: [
        _HeroHeader(
          newCount: _new.length,
          activeCount: _active.length,
          doneCount: _done.length,
          overdueCount: _overdueCount,
          criticalCount: _criticalCount,
          newAlerts: _newAlerts,
          liveMode: _liveMode,
          hasCritical: hasCritical,
          onToggleLive: () => setState(() => _liveMode = !_liveMode),
          onRefresh: _load,
        ),
        _ControlBar(
          searchCtrl: _searchCtrl,
          search: _search,
          filterTier: _filterTier,
          filterStatus: _filterStatus,
          unassignedOnly: _unassignedOnly,
          onSearch: (v) => setState(() => _search = v),
          onTierFilter: () => _showTierFilter(),
          onStatusFilter: () => _showStatusFilter(),
          onToggleUnassigned: () => setState(() => _unassignedOnly = !_unassignedOnly),
          onClearFilters: () => setState(() { _filterTier = null; _filterStatus = null; _unassignedOnly = false; }),
        ),
        if (_selected.isNotEmpty)
          _BulkBar(count: _selected.length, onAck: _bulkAck, onResolve: _bulkResolve, onClear: () => setState(() => _selected.clear())),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
            : isDesktop
              ? _KanbanView(
                  newCases: _new,
                  activeCases: _active,
                  doneCases: _done,
                  detail: _detail,
                  selectedIds: _selected,
                  allCases: _cases,
                  onTap: (c) => setState(() => _detail = _detail?.id == c.id ? null : c),
                  onToggleSelect: (c) => setState(() { if (_selected.contains(c.id)) _selected.remove(c.id); else _selected.add(c.id); }),
                  onSetStatus: _setStatus,
                  onAddNote: _addNote,
                  onAssign: _assign,
                  onToggleFlag: _toggleFlag,
                  onEscalate: (c, t) => _showEscalateDialog(c, t),
                  onContact: (c) => _showContactDialog(c),
                  onCloseDetail: () => setState(() => _detail = null),
                )
              : _TabsView(
                  tabs: _tabs,
                  newCases: _new,
                  activeCases: _active,
                  doneCases: _done,
                  selectedIds: _selected,
                  onTap: (c) => _showDetailSheet(c),
                  onLongPress: (c) => setState(() { if (_selected.contains(c.id)) _selected.remove(c.id); else _selected.add(c.id); }),
                  onSetStatus: _setStatus,
                ),
        ),
      ],
    );
  }

  // ── Dialogs ──────────────────────────────────────────────

  void _showDetailSheet(_Case c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (bCtx, ctrl) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: _CaseDetailPanel(
            key: ValueKey(c.id),
            c: _cases.firstWhere((e) => e.id == c.id, orElse: () => c),
            allCases: _cases,
            scrollCtrl: ctrl,
            onClose: () => Navigator.pop(bCtx),
            onSetStatus: (s) { _setStatus(c.id, s); Navigator.pop(bCtx); },
            onAddNote: (t) => _addNote(c.id, t),
            onAssign: (a) => _assign(c.id, a),
            onToggleFlag: () => _toggleFlag(c.id),
            onEscalate: (t) { Navigator.pop(bCtx); _showEscalateDialog(c, t); },
            onContact: () { Navigator.pop(bCtx); _showContactDialog(c); },
          ),
        ),
      ),
    );
  }

  void _showTierFilter() => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Filter by Tier', style: TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.x, size: 16, color: AppColors.textMuted),
            title: const Text('All Tiers'),
            selected: _filterTier == null,
            onTap: () { setState(() => _filterTier = null); Navigator.pop(ctx); },
          ),
          for (int t = 4; t >= 1; t--)
            ListTile(
              leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: _tierColor(t), borderRadius: BorderRadius.circular(3))),
              title: Text(_tierLabel(t)),
              selected: _filterTier == t,
              selectedColor: _tierColor(t),
              onTap: () { setState(() => _filterTier = _filterTier == t ? null : t); Navigator.pop(ctx); },
            ),
        ],
      ),
    ),
  );

  void _showStatusFilter() => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Filter by Status', style: TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _Status.values.map((s) => ListTile(
          leading: Icon(s.icon, color: s.color, size: 16),
          title: Text(s.label),
          selected: _filterStatus == s,
          onTap: () { setState(() => _filterStatus = _filterStatus == s ? null : s); Navigator.pop(ctx); },
        )).toList(),
      ),
    ),
  );

  void _showEscalateDialog(_Case c, String target) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      title: Row(children: [
        const Icon(LucideIcons.triangleAlert, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Text('Escalate to $target', style: const TextStyle(fontSize: 15)),
      ]),
      content: Text('Mark ${c.userName}\'s case as escalated to $target and log the contact. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            _doEscalate(c.id, target);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Case escalated to $target'),
              backgroundColor: const Color(0xFF7C3AED),
            ));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
          child: Text('Escalate to $target'),
        ),
      ],
    ),
  );

  void _showContactDialog(_Case c) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      title: Row(children: [
        const Icon(LucideIcons.phone, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text('Contact ${c.userName}', style: const TextStyle(fontSize: 15)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ContactOption(icon: LucideIcons.mail, title: 'Send Email', subtitle: c.userEmail, color: AppColors.primary, onTap: () {
            setState(() => c.contacts.add(_ContactLog(method: 'email', note: 'Email sent to ${c.userEmail}', at: DateTime.now())));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email contact logged')));
          }),
          _ContactOption(icon: LucideIcons.messageCircle, title: 'In-App Message', subtitle: 'Send through MindBridge', color: AppColors.info, onTap: () {
            setState(() => c.contacts.add(_ContactLog(method: 'message', note: 'In-app message sent', at: DateTime.now())));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message contact logged')));
          }),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final int newCount, activeCount, doneCount, overdueCount, criticalCount, newAlerts;
  final bool liveMode, hasCritical;
  final VoidCallback onToggleLive, onRefresh;

  const _HeroHeader({
    required this.newCount, required this.activeCount, required this.doneCount,
    required this.overdueCount, required this.criticalCount, required this.newAlerts,
    required this.liveMode, required this.hasCritical,
    required this.onToggleLive, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final grad = hasCritical
      ? [const Color(0xFF7F1D1D), const Color(0xFFB91C1C)]
      : [const Color(0xFF0D5C57), AppColors.primary];

    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: AppRadius.mdAll),
            child: Icon(hasCritical ? LucideIcons.triangleAlert : LucideIcons.shieldCheck, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Crisis Monitor', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              Text(
                hasCritical
                  ? '$criticalCount critical — immediate attention required'
                  : 'Real-time student crisis management',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Wrap(spacing: 6, children: [
            _HChip(label: '$newCount',     sub: 'New',     color: newCount > 0 ? AppColors.error : Colors.white54),
            _HChip(label: '$activeCount',  sub: 'Active',  color: activeCount > 0 ? AppColors.warning : Colors.white54),
            _HChip(label: '$overdueCount', sub: 'Overdue', color: overdueCount > 0 ? const Color(0xFFFCA5A5) : Colors.white54),
            _HChip(label: '$doneCount',    sub: 'Done',    color: Colors.white54),
          ]),
          const SizedBox(width: 8),
          // Live toggle
          GestureDetector(
            onTap: onToggleLive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: liveMode ? 0.2 : 0.08),
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(color: liveMode ? const Color(0xFF4ADE80) : Colors.white38, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(onPressed: onRefresh, icon: const Icon(LucideIcons.refreshCw, color: Colors.white, size: 16), tooltip: 'Refresh'),
          if (newAlerts > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: AppRadius.pillAll),
              child: Text('$newAlerts new', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _HChip extends StatelessWidget {
  final String label, sub;
  final Color color;
  const _HChip({required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: AppRadius.mdAll),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Control Bar
// ─────────────────────────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String search;
  final int? filterTier;
  final _Status? filterStatus;
  final bool unassignedOnly;
  final void Function(String) onSearch;
  final VoidCallback onTierFilter, onStatusFilter, onToggleUnassigned, onClearFilters;

  const _ControlBar({
    required this.searchCtrl, required this.search, required this.filterTier,
    required this.filterStatus, required this.unassignedOnly, required this.onSearch,
    required this.onTierFilter, required this.onStatusFilter,
    required this.onToggleUnassigned, required this.onClearFilters,
  });

  bool get _hasFilters => filterTier != null || filterStatus != null || unassignedOnly;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _FChip(
        label: filterTier != null ? _tierLabel(filterTier!) : 'Tier',
        selected: filterTier != null,
        color: filterTier != null ? _tierColor(filterTier!) : null,
        onTap: onTierFilter,
      ),
      _FChip(
        label: filterStatus != null ? filterStatus!.label : 'Status',
        selected: filterStatus != null,
        color: filterStatus?.color,
        onTap: onStatusFilter,
      ),
      _FChip(
        label: 'Unassigned',
        selected: unassignedOnly,
        onTap: onToggleUnassigned,
      ),
      if (_hasFilters)
        GestureDetector(
          onTap: onClearFilters,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: AppRadius.pillAll,
            ),
            child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 240,
            height: 36,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search name, email, message…',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                prefixIcon: const Icon(LucideIcons.search, size: 14, color: AppColors.textMuted),
                suffixIcon: search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 12, color: AppColors.textMuted),
                      onPressed: () { searchCtrl.clear(); onSearch(''); },
                    )
                  : null,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: AppRadius.pillAll, borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final c in chips) Padding(padding: const EdgeInsets.only(right: 6), child: c),
            ]),
          )),
        ],
      ),
    );
  }
}

class _FChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.1) : AppColors.surfaceVariant,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: selected ? c.withValues(alpha: 0.35) : AppColors.border),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          color: selected ? c : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulk Bar
// ─────────────────────────────────────────────────────────────────────────────

class _BulkBar extends StatelessWidget {
  final int count;
  final VoidCallback onAck, onResolve, onClear;
  const _BulkBar({required this.count, required this.onAck, required this.onResolve, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.primary.withValues(alpha: 0.07),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.pillAll),
        child: Text('$count selected', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      const Spacer(),
      _SolidBtn(label: 'Acknowledge All', icon: LucideIcons.eye, color: AppColors.warning, onTap: onAck),
      const SizedBox(width: 8),
      _SolidBtn(label: 'Resolve All', icon: LucideIcons.circleCheck, color: AppColors.success, onTap: onResolve),
      const SizedBox(width: 8),
      TextButton(onPressed: onClear, child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
    ]),
  );
}

class _SolidBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SolidBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Kanban View (Desktop)
// ─────────────────────────────────────────────────────────────────────────────

class _KanbanView extends StatelessWidget {
  final List<_Case> newCases, activeCases, doneCases;
  final _Case? detail;
  final Set<String> selectedIds;
  final List<_Case> allCases;
  final void Function(_Case) onTap, onToggleSelect;
  final void Function(String, _Status) onSetStatus;
  final void Function(String, String) onAddNote;
  final void Function(String, String?) onAssign;
  final void Function(String) onToggleFlag;
  final void Function(_Case, String) onEscalate;
  final void Function(_Case) onContact;
  final VoidCallback onCloseDetail;

  const _KanbanView({
    required this.newCases, required this.activeCases, required this.doneCases,
    required this.detail, required this.selectedIds, required this.allCases,
    required this.onTap, required this.onToggleSelect, required this.onSetStatus,
    required this.onAddNote, required this.onAssign, required this.onToggleFlag,
    required this.onEscalate, required this.onContact, required this.onCloseDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KanbanCol(
          title: 'New Cases', icon: LucideIcons.circleAlert, color: AppColors.error,
          cases: newCases, detail: detail, selectedIds: selectedIds,
          onTap: onTap, onToggleSelect: onToggleSelect, onSetStatus: onSetStatus,
        ),
        const VerticalDivider(width: 1, color: AppColors.border),
        _KanbanCol(
          title: 'Active', icon: LucideIcons.clock, color: AppColors.warning,
          cases: activeCases, detail: detail, selectedIds: selectedIds,
          onTap: onTap, onToggleSelect: onToggleSelect, onSetStatus: onSetStatus,
        ),
        const VerticalDivider(width: 1, color: AppColors.border),
        _KanbanCol(
          title: 'Resolved', icon: LucideIcons.circleCheck, color: AppColors.success,
          cases: doneCases, detail: detail, selectedIds: selectedIds,
          onTap: onTap, onToggleSelect: onToggleSelect, onSetStatus: onSetStatus,
        ),
        if (detail != null) ...[
          const VerticalDivider(width: 1, color: AppColors.border),
          SizedBox(
            width: 360,
            child: _CaseDetailPanel(
              key: ValueKey(detail!.id),
              c: detail!,
              allCases: allCases,
              onClose: onCloseDetail,
              onSetStatus: (s) => onSetStatus(detail!.id, s),
              onAddNote: (t) => onAddNote(detail!.id, t),
              onAssign: (a) => onAssign(detail!.id, a),
              onToggleFlag: () => onToggleFlag(detail!.id),
              onEscalate: (t) => onEscalate(detail!, t),
              onContact: () => onContact(detail!),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kanban Column — uses SingleChildScrollView > Column (ALWAYS renders cards)
// ─────────────────────────────────────────────────────────────────────────────

class _KanbanCol extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_Case> cases;
  final _Case? detail;
  final Set<String> selectedIds;
  final void Function(_Case) onTap, onToggleSelect;
  final void Function(String, _Status) onSetStatus;

  const _KanbanCol({
    required this.title, required this.icon, required this.color,
    required this.cases, required this.detail, required this.selectedIds,
    required this.onTap, required this.onToggleSelect, required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.smAll),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: AppRadius.pillAll),
                child: Text('${cases.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
              ),
            ]),
          ),
          // Cards — SingleChildScrollView renders ALL children eagerly = always visible
          Flexible(
            child: cases.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 32, color: AppColors.border),
                    const SizedBox(height: 8),
                    Text('No $title', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ]),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      for (final c in cases)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CrisisCard(
                            key: ValueKey(c.id),
                            c: c,
                            isSelected: detail?.id == c.id,
                            isChecked: selectedIds.contains(c.id),
                            onTap: () => onTap(c),
                            onLongPress: () => onToggleSelect(c),
                            onSetStatus: onSetStatus,
                          ),
                        ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Crisis Card — plain Container, zero animations, always fully visible
// ─────────────────────────────────────────────────────────────────────────────

class _CrisisCard extends StatelessWidget {
  final _Case c;
  final bool isSelected;
  final bool isChecked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(String, _Status) onSetStatus;

  const _CrisisCard({
    super.key,
    required this.c,
    required this.isSelected,
    required this.isChecked,
    required this.onTap,
    this.onLongPress,
    required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    final tc = _tierColor(c.tier);
    final slaTxt = c.isActive ? _slaText(c.age, c.tier) : null;
    final slaClr = c.isActive ? _slaColor(c.age, c.tier) : null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isChecked
            ? AppColors.primary.withValues(alpha: 0.05)
            : isSelected
              ? tc.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border(
            left: BorderSide(color: tc, width: 4),
            top: BorderSide(color: isSelected ? tc.withValues(alpha: 0.2) : AppColors.border),
            right: BorderSide(color: isSelected ? tc.withValues(alpha: 0.2) : AppColors.border),
            bottom: BorderSide(color: isSelected ? tc.withValues(alpha: 0.2) : AppColors.border),
          ),
        ),
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: badges + risk + SLA
            Row(children: [
              _TierPill(tier: c.tier),
              const SizedBox(width: 5),
              _StatusPill(status: c.status),
              if (c.flagged) ...[
                const SizedBox(width: 5),
                const Icon(LucideIcons.flag, size: 11, color: AppColors.error),
              ],
              // ML score badge — appears once background scoring completes
              if (c.mlScore != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    'ML ${(c.mlScore! * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Risk score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _riskColor(c.riskScore).withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text('${c.riskScore.toInt()}',
                    style: TextStyle(fontSize: 9, color: _riskColor(c.riskScore), fontWeight: FontWeight.w800)),
              ),
              if (slaTxt != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: slaClr!.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(slaTxt, style: TextStyle(fontSize: 9, color: slaClr, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 7),

            // Row 2: Avatar + name + time
            Row(children: [
              _Avatar(name: c.userName, color: tc, radius: 13),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.userName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  Text(
                    c.university != null ? '${c.userEmail} · ${c.university}' : c.userEmail,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ]),
              ),
              Text(_relTime(c.createdAt), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 7),

            // Row 3: Message preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tc.withValues(alpha: 0.04),
                borderRadius: AppRadius.smAll,
                border: Border.all(color: tc.withValues(alpha: 0.1)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (c.categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Wrap(spacing: 4, children: c.categories.take(2).map((cat) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: tc.withValues(alpha: 0.12), borderRadius: AppRadius.xsAll),
                        child: Text(cat, style: TextStyle(fontSize: 8, color: tc, fontWeight: FontWeight.w700)),
                      )).toList(),
                    ),
                  ),
                Text(
                  c.content.length > 90 ? '${c.content.substring(0, 90)}…' : c.content,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            const SizedBox(height: 7),

            // Row 4: metadata + quick actions
            Row(children: [
              if (c.assignedTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.userCheck, size: 9, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(c.assignedTo!, style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (c.notes.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.smAll),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.messageSquare, size: 9, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Text('${c.notes.length}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  ]),
                ),
              ],
              const Spacer(),
              ..._buildQuickActions(c),
            ]),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQuickActions(_Case c) {
    final actions = <({IconData icon, String label, Color color, _Status next})>[];
    switch (c.status) {
      case _Status.newCase:
        actions.add((icon: LucideIcons.eye, label: 'Ack', color: AppColors.warning, next: _Status.acknowledged));
        actions.add((icon: LucideIcons.circleCheck, label: 'Resolve', color: AppColors.success, next: _Status.resolved));
      case _Status.acknowledged:
        actions.add((icon: LucideIcons.clock, label: 'Start', color: AppColors.info, next: _Status.inProgress));
        actions.add((icon: LucideIcons.circleCheck, label: 'Resolve', color: AppColors.success, next: _Status.resolved));
      case _Status.inProgress:
      case _Status.escalated:
        actions.add((icon: LucideIcons.circleCheck, label: 'Resolve', color: AppColors.success, next: _Status.resolved));
      case _Status.resolved:
        actions.add((icon: LucideIcons.rotateCcw, label: 'Re-open', color: AppColors.warning, next: _Status.newCase));
        actions.add((icon: LucideIcons.archive, label: 'Close', color: AppColors.textMuted, next: _Status.closed));
      case _Status.closed:
        actions.add((icon: LucideIcons.rotateCcw, label: 'Re-open', color: AppColors.warning, next: _Status.newCase));
    }
    return actions.map((a) => Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onTap: () => onSetStatus(c.id, a.next),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: a.color.withValues(alpha: 0.1),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: a.color.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(a.icon, size: 10, color: a.color),
            const SizedBox(width: 4),
            Text(a.label, style: TextStyle(fontSize: 10, color: a.color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    )).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Tabs View
// ─────────────────────────────────────────────────────────────────────────────

class _TabsView extends StatelessWidget {
  final TabController tabs;
  final List<_Case> newCases, activeCases, doneCases;
  final Set<String> selectedIds;
  final void Function(_Case) onTap, onLongPress;
  final void Function(String, _Status) onSetStatus;

  const _TabsView({
    required this.tabs, required this.newCases, required this.activeCases,
    required this.doneCases, required this.selectedIds,
    required this.onTap, required this.onLongPress, required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: tabs,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        tabs: [
          Tab(text: 'New (${newCases.length})'),
          Tab(text: 'Active (${activeCases.length})'),
          Tab(text: 'Done (${doneCases.length})'),
        ],
      ),
      const Divider(height: 1, color: AppColors.border),
      Expanded(
        child: TabBarView(
          controller: tabs,
          children: [
            _MobileList(cases: newCases, selectedIds: selectedIds, onTap: onTap, onLongPress: onLongPress, onSetStatus: onSetStatus, emptyIcon: LucideIcons.shieldCheck, emptyText: 'No new cases'),
            _MobileList(cases: activeCases, selectedIds: selectedIds, onTap: onTap, onLongPress: onLongPress, onSetStatus: onSetStatus, emptyIcon: LucideIcons.clock, emptyText: 'No active cases'),
            _MobileList(cases: doneCases, selectedIds: selectedIds, onTap: onTap, onLongPress: onLongPress, onSetStatus: onSetStatus, emptyIcon: LucideIcons.circleCheck, emptyText: 'No resolved cases'),
          ],
        ),
      ),
    ]);
  }
}

class _MobileList extends StatelessWidget {
  final List<_Case> cases;
  final Set<String> selectedIds;
  final void Function(_Case) onTap, onLongPress;
  final void Function(String, _Status) onSetStatus;
  final IconData emptyIcon;
  final String emptyText;

  const _MobileList({
    required this.cases, required this.selectedIds, required this.onTap,
    required this.onLongPress, required this.onSetStatus,
    required this.emptyIcon, required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(emptyIcon, size: 40, color: AppColors.border),
      const SizedBox(height: 8),
      Text(emptyText, style: const TextStyle(color: AppColors.textMuted)),
    ]));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final c in cases)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CrisisCard(
              key: ValueKey(c.id),
              c: c,
              isSelected: false,
              isChecked: selectedIds.contains(c.id),
              onTap: () => onTap(c),
              onLongPress: () => onLongPress(c),
              onSetStatus: onSetStatus,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Case Detail Panel
// ─────────────────────────────────────────────────────────────────────────────

class _CaseDetailPanel extends StatefulWidget {
  final _Case c;
  final List<_Case> allCases;
  final ScrollController? scrollCtrl;
  final VoidCallback onClose;
  final void Function(_Status) onSetStatus;
  final void Function(String) onAddNote;
  final void Function(String?) onAssign;
  final VoidCallback onToggleFlag;
  final void Function(String) onEscalate;
  final VoidCallback onContact;

  const _CaseDetailPanel({
    super.key,
    required this.c, required this.allCases, this.scrollCtrl,
    required this.onClose, required this.onSetStatus, required this.onAddNote,
    required this.onAssign, required this.onToggleFlag,
    required this.onEscalate, required this.onContact,
  });

  @override
  State<_CaseDetailPanel> createState() => _CaseDetailPanelState();
}

class _CaseDetailPanelState extends State<_CaseDetailPanel> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final tc = _tierColor(c.tier);
    final history = widget.allCases.where((e) => e.userId == c.userId && e.id != c.id).toList();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: tc.withValues(alpha: 0.06),
              border: Border(bottom: BorderSide(color: tc.withValues(alpha: 0.2))),
            ),
            child: Row(children: [
              _TierPill(tier: c.tier),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c.userName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                onPressed: widget.onToggleFlag,
                icon: Icon(LucideIcons.flag, size: 15, color: c.flagged ? AppColors.error : AppColors.textMuted),
                tooltip: c.flagged ? 'Unflag' : 'Flag',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          // Body
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollCtrl,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // User card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.mdAll),
                  child: Row(children: [
                    _Avatar(name: c.userName, color: tc, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(c.userEmail, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      if (c.university != null)
                        Text(c.university!, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(height: 5),
                      Wrap(spacing: 6, children: [
                        _InfoPill(label: 'Risk: ${c.riskScore.toInt()}', color: _riskColor(c.riskScore)),
                        if (c.mlScore != null)
                          _InfoPill(
                            label: 'ML Crisis: ${(c.mlScore! * 100).toInt()}%',
                            color: const Color(0xFF7C3AED),
                          ),
                        if (history.isNotEmpty) _InfoPill(label: '${history.length} prior', color: AppColors.error),
                        if (c.escalationTarget != null) _InfoPill(label: 'Escalated: ${c.escalationTarget}', color: const Color(0xFF7C3AED)),
                      ]),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),

                // Status actions
                _SectionLbl('STATUS'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.status.color.withValues(alpha: 0.06),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: c.status.color.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(c.status.icon, size: 14, color: c.status.color),
                    const SizedBox(width: 6),
                    Text(c.status.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.status.color)),
                    const Spacer(),
                    Text(_relTime(c.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ]),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: _Status.values.where((s) => s != c.status).map((s) =>
                  GestureDetector(
                    onTap: () => widget.onSetStatus(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.08),
                        borderRadius: AppRadius.pillAll,
                        border: Border.all(color: s.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(s.icon, size: 11, color: s.color),
                        const SizedBox(width: 5),
                        Text(s.label, style: TextStyle(fontSize: 11, color: s.color, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  )
                ).toList()),
                const SizedBox(height: 12),

                // Assign
                _SectionLbl('ASSIGN TO'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: c.assignedTo,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: const BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unassigned', style: TextStyle(fontSize: 12))),
                    ...['Dr. Sarah Mitchell', 'Dr. James Okafor', 'Counselor A. Rivera', 'Counselor B. Chen'].map(
                      (a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12))),
                    ),
                  ],
                  onChanged: widget.onAssign,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),

                // Escalation
                _SectionLbl('ESCALATE'),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _EscBtn(label: 'Supervisor', icon: LucideIcons.settings, color: AppColors.warning, onTap: () => widget.onEscalate('Supervisor')),
                  _EscBtn(label: 'Counseling', icon: LucideIcons.heartHandshake, color: const Color(0xFF7C3AED), onTap: () => widget.onEscalate('Counseling')),
                  _EscBtn(label: 'Emergency', icon: LucideIcons.phone, color: AppColors.error, onTap: () => widget.onEscalate('Emergency Services')),
                ]),
                const SizedBox(height: 12),

                // Full message
                _SectionLbl('FLAGGED MESSAGE'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tc.withValues(alpha: 0.03),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: tc.withValues(alpha: 0.15)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(DateFormat('MMM d, y · h:mm a').format(c.createdAt),
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () { Clipboard.setData(ClipboardData(text: c.content)); },
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(LucideIcons.copy, size: 11, color: AppColors.textMuted),
                          SizedBox(width: 3),
                          Text('Copy', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(c.content, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.55)),
                  ]),
                ),
                const SizedBox(height: 12),

                // Risk categories
                if (c.categories.isNotEmpty) ...[
                  _SectionLbl('RISK CATEGORIES'),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: c.categories.map((cat) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: tc.withValues(alpha: 0.08), borderRadius: AppRadius.smAll),
                      child: Text(cat, style: TextStyle(fontSize: 11, color: tc, fontWeight: FontWeight.w600)),
                    )).toList()),
                  const SizedBox(height: 12),
                ],

                // SLA info
                if (c.isActive) ...[
                  _SectionLbl('SLA TARGET'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _slaColor(c.age, c.tier).withValues(alpha: 0.06),
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: _slaColor(c.age, c.tier).withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.clock, size: 13, color: _slaColor(c.age, c.tier)),
                      const SizedBox(width: 6),
                      Text(_slaText(c.age, c.tier),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _slaColor(c.age, c.tier))),
                      const Spacer(),
                      Text('Target: ${_slaDuration(c.tier).inMinutes < 60 ? '${_slaDuration(c.tier).inMinutes}min' : '${_slaDuration(c.tier).inHours}hr'}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // Contact log
                if (c.contacts.isNotEmpty) ...[
                  _SectionLbl('CONTACT LOG (${c.contacts.length})'),
                  const SizedBox(height: 6),
                  ...c.contacts.map((ct) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.smAll),
                        child: Icon(_contactIcon(ct.method), size: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(ct.note, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                      Text(_relTime(ct.at), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ]),
                  )),
                  const SizedBox(height: 12),
                ],

                // Notes
                _SectionLbl('ADMIN NOTES (${c.notes.length})'),
                const SizedBox(height: 6),
                ...c.notes.map((n) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.smAll),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(n.author, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const Spacer(),
                      Text(_relTime(n.at), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ]),
                    const SizedBox(height: 3),
                    Text(n.text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                  ]),
                )),
                // Add note input
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _noteCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Add a note…',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onSubmitted: (v) { if (v.trim().isEmpty) return; widget.onAddNote(v.trim()); _noteCtrl.clear(); },
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () { final t = _noteCtrl.text.trim(); if (t.isEmpty) return; widget.onAddNote(t); _noteCtrl.clear(); },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.mdAll),
                      child: const Icon(LucideIcons.send, size: 14, color: Colors.white),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Prior cases
                if (history.isNotEmpty) ...[
                  _SectionLbl('PRIOR CASES (${history.length})'),
                  const SizedBox(height: 6),
                  ...history.take(4).map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.smAll,
                      border: Border(left: BorderSide(color: _tierColor(e.tier), width: 3)),
                    ),
                    child: Row(children: [
                      _TierPill(tier: e.tier),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.content.length > 48 ? '${e.content.substring(0, 48)}…' : e.content,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_relTime(e.createdAt), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                    ]),
                  )),
                  const SizedBox(height: 12),
                ],

                // Contact button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onContact,
                    icon: const Icon(LucideIcons.mail, size: 14),
                    label: const Text('Contact ${'\u2022'} Log Outreach'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  IconData _contactIcon(String method) => switch (method) {
    'email'      => LucideIcons.mail,
    'message'    => LucideIcons.messageCircle,
    'phone'      => LucideIcons.phone,
    _            => LucideIcons.triangleAlert,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TierPill extends StatelessWidget {
  final int tier;
  const _TierPill({required this.tier});
  @override
  Widget build(BuildContext context) {
    final c = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: c, borderRadius: AppRadius.smAll),
      child: Text(_tierLabel(tier),
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final _Status status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: status.color.withValues(alpha: 0.1),
      borderRadius: AppRadius.smAll,
      border: Border.all(color: status.color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(status.icon, size: 8, color: status.color),
      const SizedBox(width: 3),
      Text(status.label.toUpperCase(),
          style: TextStyle(fontSize: 8, color: status.color, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    ]),
  );
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  final double radius;
  const _Avatar({required this.name, required this.color, required this.radius});
  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(initials, style: TextStyle(fontSize: radius * 0.65, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.smAll),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );
}

class _EscBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _EscBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _SectionLbl extends StatelessWidget {
  final String text;
  const _SectionLbl(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8));
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ContactOption({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.smAll),
      child: Icon(icon, size: 18, color: color),
    ),
    title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    onTap: onTap,
    contentPadding: EdgeInsets.zero,
  );
}
