import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

// ─── Helpers ─────────────────────────────────────────────

Color _tagColor(String? tag) {
  switch (tag?.toLowerCase()) {
    case 'wellness':
      return AppColors.success;
    case 'vent':
      return AppColors.error;
    case 'question':
      return AppColors.info;
    case 'support':
      return AppColors.primary;
    case 'motivation':
      return AppColors.tertiary;
    case 'anxiety':
      return const Color(0xFF8B5CF6);
    case 'depression':
      return const Color(0xFF6366F1);
    default:
      return AppColors.textMuted;
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

// ─── Risk Scoring ─────────────────────────────────────────

enum _Risk { high, medium, low }

_Risk _riskLevel(String content) {
  final c = content.toLowerCase();
  const highKeywords = [
    'suicide', 'kill myself', 'end my life', 'self harm', 'cut myself',
    'no reason to live', 'want to die', 'hurt myself',
  ];
  const medKeywords = [
    'depressed', 'hopeless', 'worthless', 'give up', 'can\'t anymore',
    'hate myself', 'nobody cares', 'disappear', 'overwhelmed',
  ];
  if (highKeywords.any((k) => c.contains(k))) return _Risk.high;
  if (medKeywords.any((k) => c.contains(k))) return _Risk.medium;
  return _Risk.low;
}

Color _riskColor(_Risk r) {
  switch (r) {
    case _Risk.high:
      return AppColors.error;
    case _Risk.medium:
      return AppColors.warning;
    case _Risk.low:
      return AppColors.success;
  }
}

String _riskLabel(_Risk r) {
  switch (r) {
    case _Risk.high:
      return 'HIGH RISK';
    case _Risk.medium:
      return 'MEDIUM';
    case _Risk.low:
      return 'CLEAR';
  }
}

// ─── Sort Options ─────────────────────────────────────────

enum _SortOption { newest, oldest, mostReactions, mostFlagged }

// ─── Main Screen ──────────────────────────────────────────

class ContentModerationScreen extends ConsumerStatefulWidget {
  const ContentModerationScreen({super.key});

  @override
  ConsumerState<ContentModerationScreen> createState() =>
      _ContentModerationScreenState();
}

class _ContentModerationScreenState
    extends ConsumerState<ContentModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _tabFilters = [
    'all', 'flagged', 'hidden', 'anonymous', 'pinned'
  ];
  static const _tabLabels = [
    'All Posts', 'Flagged', 'Hidden', 'Anonymous', 'Pinned'
  ];

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _SortOption _sort = _SortOption.newest;
  bool _bulkMode = false;
  final Set<String> _selected = {};
  bool _logExpanded = false;
  CommunityPostAdmin? _selectedPost; // for desktop split panel

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {
          _selected.clear();
          _bulkMode = false;
          _selectedPost = null;
        });
        ref.read(adminProvider.notifier).loadPosts(
              filter: _tabFilters[_tabs.index],
            );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).loadPosts();
      ref.read(adminProvider.notifier).loadModerationLog();
    });
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CommunityPostAdmin> _filteredPosts(List<CommunityPostAdmin> raw) {
    var posts = raw;
    if (_searchQuery.isNotEmpty) {
      posts = posts
          .where((p) =>
              p.content.toLowerCase().contains(_searchQuery) ||
              (p.authorName?.toLowerCase().contains(_searchQuery) ?? false))
          .toList();
    }
    switch (_sort) {
      case _SortOption.newest:
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortOption.oldest:
        posts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _SortOption.mostReactions:
        posts.sort((a, b) => b.reactionCount.compareTo(a.reactionCount));
        break;
      case _SortOption.mostFlagged:
        posts.sort((a, b) {
          final af = a.isFlagged ? 1 : 0;
          final bf = b.isFlagged ? 1 : 0;
          return bf.compareTo(af);
        });
        break;
    }
    return posts;
  }

  void _toggleBulkMode() => setState(() {
        _bulkMode = !_bulkMode;
        if (!_bulkMode) _selected.clear();
      });

  void _toggleSelect(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      });

  Future<void> _bulkHide(List<CommunityPostAdmin> posts) async {
    final notifier = ref.read(adminProvider.notifier);
    for (final id in _selected) {
      await notifier.hidePost(id, hide: true);
    }
    setState(() {
      _selected.clear();
      _bulkMode = false;
    });
  }

  Future<void> _bulkDelete(List<CommunityPostAdmin> posts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Delete Selected Posts?'),
        content: Text(
          'Permanently delete ${_selected.length} post(s). Cannot be undone.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final notifier = ref.read(adminProvider.notifier);
      for (final id in _selected) {
        await notifier.deletePost(id);
      }
      setState(() {
        _selected.clear();
        _bulkMode = false;
      });
    }
  }

  Future<void> _bulkApprove(List<CommunityPostAdmin> posts) async {
    final notifier = ref.read(adminProvider.notifier);
    for (final id in _selected) {
      await notifier.unflagPost(id);
    }
    setState(() {
      _selected.clear();
      _bulkMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final posts = _filteredPosts(state.posts);
    final flaggedCount = state.stats.flaggedPosts;
    final hiddenCount = state.stats.hiddenPosts;
    final pinnedCount = state.posts.where((p) => p.isPinned).length;
    final anonCount = state.posts.where((p) => p.isAnonymous).length;

    return Column(
      children: [
        // ── Hero Header ───────────────────────────────────
        _ModHeroHeader(
          total: state.stats.communityPosts,
          flagged: flaggedCount,
          hidden: hiddenCount,
          pinned: pinnedCount,
          anonymous: anonCount,
          onFilter: (filter) {
            final idx = _tabFilters.indexOf(filter);
            if (idx >= 0) {
              _tabs.animateTo(idx);
              ref.read(adminProvider.notifier).loadPosts(filter: filter);
            }
          },
        ),

        // ── Toolbar ───────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: AppRadius.smAll,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Search posts, authors…',
                          hintStyle: TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                          prefixIcon: Icon(LucideIcons.search,
                              size: 14, color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SortDropdown(
                      value: _sort,
                      onChanged: (v) => setState(() => _sort = v)),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _toggleBulkMode,
                    icon: Icon(
                      _bulkMode ? LucideIcons.x : LucideIcons.squareCheck,
                      size: 18,
                      color: _bulkMode ? AppColors.error : AppColors.textMuted,
                    ),
                    tooltip: _bulkMode ? 'Cancel selection' : 'Bulk select',
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(6)),
                  ),
                ],
              ),
              if (_bulkMode && _selected.isNotEmpty)
                _BulkActionsBar(
                  count: _selected.length,
                  allPosts: posts,
                  onSelectAll: () =>
                      setState(() => _selected.addAll(posts.map((p) => p.id))),
                  onApprove: () => _bulkApprove(posts),
                  onHide: () => _bulkHide(posts),
                  onDelete: () => _bulkDelete(posts),
                ).animate().slideY(begin: -0.3, duration: 200.ms),
            ],
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
            indicatorWeight: 2.5,
            isScrollable: true,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: _tabLabels.asMap().entries.map((e) {
              Widget label = Text(e.value);
              if (e.key == 1 && flaggedCount > 0) {
                label = Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.value),
                  const SizedBox(width: 4),
                  _CountBadge(flaggedCount, AppColors.error),
                ]);
              }
              return Tab(child: label);
            }).toList(),
          ),
        ),

        // ── Content ───────────────────────────────────────
        Expanded(
          child: state.isLoading && state.posts.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
              : Column(
                  children: [
                    Expanded(
                      child: posts.isEmpty
                          ? _EmptyState(filter: _tabFilters[_tabs.index])
                          : LayoutBuilder(
                              builder: (ctx, c) {
                                final wide = c.maxWidth > 760;
                                if (wide && _selectedPost != null) {
                                  return _DesktopSplitView(
                                    posts: posts,
                                    selected: _selectedPost,
                                    bulkMode: _bulkMode,
                                    selectedIds: _selected,
                                    onSelect: (p) => setState(
                                        () => _selectedPost = p),
                                    onToggleSelect: _toggleSelect,
                                    onClose: () =>
                                        setState(() => _selectedPost = null),
                                  );
                                }
                                if (wide) {
                                  return GridView.builder(
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.25,
                                    ),
                                    itemCount: posts.length,
                                    itemBuilder: (ctx, i) => _PostCard(
                                      post: posts[i],
                                      bulkMode: _bulkMode,
                                      isSelected:
                                          _selected.contains(posts[i].id),
                                      onToggleSelect: () =>
                                          _toggleSelect(posts[i].id),
                                      onViewFull: () {
                                        setState(
                                            () => _selectedPost = posts[i]);
                                      },
                                    )
                                        .animate(
                                            delay: Duration(
                                                milliseconds: i * 30))
                                        .fadeIn(duration: 200.ms)
                                        .slideY(begin: 0.04),
                                  );
                                }
                                return ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: posts.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (ctx, i) => _PostCard(
                                    post: posts[i],
                                    bulkMode: _bulkMode,
                                    isSelected: _selected.contains(posts[i].id),
                                    onToggleSelect: () =>
                                        _toggleSelect(posts[i].id),
                                    onViewFull: () =>
                                        _showPostDetail(context, posts[i]),
                                  )
                                      .animate(
                                          delay: Duration(milliseconds: i * 30))
                                      .fadeIn(duration: 200.ms)
                                      .slideY(begin: 0.04),
                                );
                              },
                            ),
                    ),
                    _ModerationLogPanel(
                      expanded: _logExpanded,
                      onToggle: () =>
                          setState(() => _logExpanded = !_logExpanded),
                      actions: state.moderationLog,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _showPostDetail(BuildContext context, CommunityPostAdmin post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostDetailSheet(post: post),
    );
  }
}

// ─── Hero Header ─────────────────────────────────────────

class _ModHeroHeader extends StatelessWidget {
  final int total, flagged, hidden, pinned, anonymous;
  final void Function(String) onFilter;

  const _ModHeroHeader({
    required this.total,
    required this.flagged,
    required this.hidden,
    required this.pinned,
    required this.anonymous,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: flagged > 0
                ? [const Color(0xFF7F1D1D), AppColors.error]
                : [const Color(0xFF0D5C57), AppColors.primary],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Content Moderation',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text(
                      flagged > 0
                          ? '$flagged item${flagged > 1 ? 's' : ''} need attention'
                          : 'Community looks clean',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ]),
                  const Spacer(),
                  if (flagged > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: AppRadius.pillAll,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.triangleAlert,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 5),
                        Text('$flagged flagged',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _HeaderChip('Total', total, AppColors.primary,
                        () => onFilter('all')),
                    const SizedBox(width: 8),
                    _HeaderChip('Flagged', flagged, AppColors.error,
                        () => onFilter('flagged')),
                    const SizedBox(width: 8),
                    _HeaderChip('Hidden', hidden, AppColors.textMuted,
                        () => onFilter('hidden')),
                    const SizedBox(width: 8),
                    _HeaderChip('Pinned', pinned, AppColors.tertiary,
                        () => onFilter('pinned')),
                    const SizedBox(width: 8),
                    _HeaderChip('Anonymous', anonymous, AppColors.info,
                        () => onFilter('anonymous')),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  const _HeaderChip(this.label, this.value, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: AppRadius.pillAll,
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: AppRadius.pillAll),
              child: Text('$value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
}

// ─── Desktop Split View ───────────────────────────────────

class _DesktopSplitView extends ConsumerWidget {
  final List<CommunityPostAdmin> posts;
  final CommunityPostAdmin? selected;
  final bool bulkMode;
  final Set<String> selectedIds;
  final ValueChanged<CommunityPostAdmin?> onSelect;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback onClose;

  const _DesktopSplitView({
    required this.posts,
    required this.selected,
    required this.bulkMode,
    required this.selectedIds,
    required this.onSelect,
    required this.onToggleSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post list pane
        SizedBox(
          width: 380,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _PostCard(
              post: posts[i],
              bulkMode: bulkMode,
              isSelected: selectedIds.contains(posts[i].id) ||
                  selected?.id == posts[i].id,
              onToggleSelect: () => onToggleSelect(posts[i].id),
              onViewFull: () => onSelect(posts[i]),
              compact: true,
            ),
          ),
        ),
        Container(width: 1, color: AppColors.border),
        // Detail pane
        Expanded(
          child: selected == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.mousePointerClick,
                          size: 32, color: AppColors.textMuted),
                      SizedBox(height: 10),
                      Text('Select a post to view details',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : _DetailPanel(
                  post: selected!,
                  onClose: onClose,
                ),
        ),
      ],
    );
  }
}

// ─── Detail Panel (Desktop) ───────────────────────────────

class _DetailPanel extends ConsumerWidget {
  final CommunityPostAdmin post;
  final VoidCallback onClose;

  const _DetailPanel({required this.post, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = _riskLevel(post.content);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Post Detail',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(LucideIcons.x,
                size: 16, color: AppColors.textMuted),
          ),
        ]),
        const Divider(height: 20, color: AppColors.border),

        // Author
        Row(children: [
          _AuthorAvatar(post: post),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  post.isAnonymous
                      ? (post.anonHandle ?? 'Anonymous')
                      : (post.authorName ?? 'User'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  DateFormat('MMM d, y · h:mm a').format(post.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ])),
          // Risk badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _riskColor(risk).withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
                border: Border.all(
                    color: _riskColor(risk).withValues(alpha: 0.3))),
            child: Text(_riskLabel(risk),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _riskColor(risk))),
          ),
        ]),
        const SizedBox(height: 14),

        // Status chips
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (post.tag != null) _TagChip(tag: post.tag!),
          if (post.isFlagged)
            _Badge('FLAGGED', AppColors.error, LucideIcons.flag),
          if (post.isHidden)
            _Badge('HIDDEN', AppColors.textMuted, LucideIcons.eyeOff),
          if (post.isPinned)
            _Badge('PINNED', AppColors.tertiary, LucideIcons.pin),
          if (post.isAnonymous)
            _Badge('ANONYMOUS', AppColors.info, LucideIcons.userX),
          _Badge(post.postType.toUpperCase(), AppColors.info, null),
        ]),
        const SizedBox(height: 14),

        // Content
        Container(
          padding: const EdgeInsets.all(14),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(post.content,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.55)),
        ),
        const SizedBox(height: 14),

        // Stats
        Row(children: [
          _DetailMetaItem(
              LucideIcons.heart, 'Reactions', '${post.reactionCount}'),
          const SizedBox(width: 20),
          _DetailMetaItem(LucideIcons.messageCircle, 'Comments',
              '${post.commentCount}'),
          const SizedBox(width: 20),
          _DetailMetaItem(LucideIcons.tag, 'Type', post.postType),
        ]),
        const SizedBox(height: 20),

        const Text('Actions',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (post.isFlagged)
            _SheetActionBtn(
              icon: LucideIcons.circleCheck,
              label: 'Clear Flag',
              color: AppColors.success,
              onTap: () => ref.read(adminProvider.notifier).unflagPost(post.id),
            ),
          _SheetActionBtn(
            icon: post.isHidden ? LucideIcons.eye : LucideIcons.eyeOff,
            label: post.isHidden ? 'Show Post' : 'Hide Post',
            color: AppColors.textSecondary,
            onTap: () => ref
                .read(adminProvider.notifier)
                .hidePost(post.id, hide: !post.isHidden),
          ),
          _SheetActionBtn(
            icon: post.isPinned ? LucideIcons.pinOff : LucideIcons.pin,
            label: post.isPinned ? 'Unpin' : 'Pin Post',
            color: AppColors.tertiary,
            onTap: () => ref
                .read(adminProvider.notifier)
                .pinPost(post.id, pin: !post.isPinned),
          ),
          _SheetActionBtn(
            icon: LucideIcons.mail,
            label: 'Warn Author',
            color: AppColors.warning,
            onTap: () => _showWarnDialog(context, ref),
          ),
          _SheetActionBtn(
            icon: LucideIcons.trash2,
            label: 'Delete Post',
            color: AppColors.error,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape:
                      RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
                  title: const Text('Delete Post?'),
                  content: const Text('Permanently deletes this post.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(adminProvider.notifier).deletePost(post.id);
              }
            },
          ),
        ]),
      ]),
    );
  }

  void _showWarnDialog(BuildContext ctx, WidgetRef ref) {
    final msgCtrl = TextEditingController(
      text:
          'Your post has been reviewed and found to violate our community guidelines. Please ensure future posts adhere to our standards.',
    );
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Send Warning to User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To: ${post.authorName ?? 'Unknown User'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Warning Message',
                border: OutlineInputBorder(borderRadius: AppRadius.smAll),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(adminProvider.notifier).emailUser(
                    toEmail: post.userId ?? '',
                    toName: post.authorName ?? 'User',
                    subject: 'Community Guidelines Warning',
                    message: msgCtrl.text,
                    fromAdminName: 'MindBridge Admin',
                  );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white),
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );
  }
}

// ─── Sort Dropdown ────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  final _SortOption value;
  final ValueChanged<_SortOption> onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_SortOption>(
            value: value,
            onChanged: (v) => v != null ? onChanged(v) : null,
            icon: const Icon(LucideIcons.chevronDown,
                size: 14, color: AppColors.textMuted),
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'Nunito'),
            items: const [
              DropdownMenuItem(
                  value: _SortOption.newest, child: Text('Newest')),
              DropdownMenuItem(
                  value: _SortOption.oldest, child: Text('Oldest')),
              DropdownMenuItem(
                  value: _SortOption.mostReactions,
                  child: Text('Most Reactions')),
              DropdownMenuItem(
                  value: _SortOption.mostFlagged,
                  child: Text('Most Flagged')),
            ],
          ),
        ),
      );
}

// ─── Bulk Actions Bar ─────────────────────────────────────

class _BulkActionsBar extends StatelessWidget {
  final int count;
  final List<CommunityPostAdmin> allPosts;
  final VoidCallback onSelectAll, onApprove, onHide, onDelete;

  const _BulkActionsBar({
    required this.count,
    required this.allPosts,
    required this.onSelectAll,
    required this.onApprove,
    required this.onHide,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Wrap(spacing: 8, runSpacing: 6, children: [
          Text('$count selected',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          _BulkBtn('All', LucideIcons.squareCheck, AppColors.primary,
              onSelectAll),
          _BulkBtn('Approve', LucideIcons.circleCheck, AppColors.success,
              onApprove),
          _BulkBtn('Hide', LucideIcons.eyeOff, AppColors.textMuted, onHide),
          _BulkBtn('Delete', LucideIcons.trash2, AppColors.error, onDelete),
        ]),
      );
}

class _BulkBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BulkBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.xsAll),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ─── Post Card ────────────────────────────────────────────

class _PostCard extends ConsumerStatefulWidget {
  final CommunityPostAdmin post;
  final bool bulkMode;
  final bool isSelected;
  final bool compact;
  final VoidCallback onToggleSelect;
  final VoidCallback onViewFull;

  const _PostCard({
    required this.post,
    required this.bulkMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onViewFull,
    this.compact = false,
  });

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final risk = post.isFlagged ? _riskLevel(post.content) : _Risk.low;

    final borderColor = post.isFlagged
        ? AppColors.error.withValues(alpha: 0.6)
        : widget.isSelected
            ? AppColors.primary.withValues(alpha: 0.5)
            : post.isHidden
                ? AppColors.textMuted.withValues(alpha: 0.25)
                : AppColors.border;

    final bgColor = post.isFlagged
        ? AppColors.errorContainer
        : widget.isSelected
            ? AppColors.primaryContainer
            : post.isHidden
                ? AppColors.surfaceVariant
                : Colors.white;

    return GestureDetector(
      onTap: widget.bulkMode
          ? widget.onToggleSelect
          : () => widget.onViewFull(),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
              color: borderColor,
              width: widget.isSelected || post.isFlagged ? 1.5 : 1),
          boxShadow: AppShadow.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flagged banner with risk level
            if (post.isFlagged)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _riskColor(risk),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.triangleAlert,
                      size: 11, color: Colors.white),
                  const SizedBox(width: 5),
                  Expanded(
                      child: Text('Flagged for review — ${_riskLabel(risk)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                ]),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (widget.bulkMode) ...[
                      Checkbox(
                        value: widget.isSelected,
                        onChanged: (_) => widget.onToggleSelect(),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 4),
                    ],
                    _AuthorAvatar(post: post),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                            post.isAnonymous
                                ? (post.anonHandle ?? 'Anonymous')
                                : (post.authorName ?? 'User'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(_relativeTime(post.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ])),
                    Wrap(spacing: 3, runSpacing: 3, children: [
                      if (post.isFlagged)
                        _Badge('FLAGGED', AppColors.error, LucideIcons.flag),
                      if (post.isHidden)
                        _Badge(
                            'HIDDEN', AppColors.textMuted, LucideIcons.eyeOff),
                      if (post.isPinned)
                        _Badge('PINNED', AppColors.tertiary, LucideIcons.pin),
                      if (post.isAnonymous)
                        _Badge('ANON', AppColors.info, LucideIcons.userX),
                    ]),
                  ]),

                  const SizedBox(height: 8),
                  if (post.tag != null) ...[
                    _TagChip(tag: post.tag!),
                    const SizedBox(height: 6),
                  ],

                  Text(
                    post.content,
                    style: TextStyle(
                        fontSize: 13,
                        color: post.isHidden
                            ? AppColors.textMuted
                            : AppColors.textSecondary,
                        height: 1.45),
                    maxLines: _expanded ? null : (widget.compact ? 2 : 3),
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
                  if (post.content.length > 120)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          _expanded ? 'Show less' : 'Read more',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),
                  Row(children: [
                    _InlineStat(LucideIcons.heart, post.reactionCount),
                    const SizedBox(width: 10),
                    _InlineStat(LucideIcons.messageCircle, post.commentCount),
                    const Spacer(),
                  ]),

                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 8),

                  // Actions — Wrap replaces horizontal scroll
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      if (post.isFlagged)
                        _ActionBtn(
                          icon: LucideIcons.circleCheck,
                          label: 'Approve',
                          color: AppColors.success,
                          onTap: () => ref
                              .read(adminProvider.notifier)
                              .unflagPost(post.id),
                        ),
                      _ActionBtn(
                        icon: post.isHidden
                            ? LucideIcons.eye
                            : LucideIcons.eyeOff,
                        label: post.isHidden ? 'Unhide' : 'Hide',
                        color: AppColors.textSecondary,
                        onTap: () => ref
                            .read(adminProvider.notifier)
                            .hidePost(post.id, hide: !post.isHidden),
                      ),
                      _ActionBtn(
                        icon: post.isPinned
                            ? LucideIcons.pinOff
                            : LucideIcons.pin,
                        label: post.isPinned ? 'Unpin' : 'Pin',
                        color: AppColors.tertiary,
                        onTap: () => ref
                            .read(adminProvider.notifier)
                            .pinPost(post.id, pin: !post.isPinned),
                      ),
                      _ActionBtn(
                        icon: LucideIcons.externalLink,
                        label: 'Details',
                        color: AppColors.info,
                        onTap: widget.onViewFull,
                      ),
                      _ActionBtn(
                        icon: LucideIcons.trash2,
                        label: 'Delete',
                        color: AppColors.error,
                        onTap: () => _confirmDelete(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Delete Post?'),
        content: const Text(
          'This action is permanent and cannot be undone.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(adminProvider.notifier).deletePost(widget.post.id);
    }
  }
}

// ─── Author Avatar ────────────────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  final CommunityPostAdmin post;

  const _AuthorAvatar({required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.isAnonymous) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: const Center(
            child: Icon(LucideIcons.userX, size: 14, color: AppColors.info)),
      );
    }
    final name = post.authorName ?? 'U';
    final initials = name
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Center(
          child: Text(initials,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary))),
    );
  }
}

// ─── Post Detail Sheet ────────────────────────────────────

class _PostDetailSheet extends ConsumerWidget {
  final CommunityPostAdmin post;

  const _PostDetailSheet({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: AppRadius.pillAll),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                const Text('Post Detail',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(LucideIcons.x,
                      size: 18, color: AppColors.textMuted),
                ),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _DetailPanel(post: post, onClose: () => Navigator.pop(ctx)),
            ),
          ]),
        ),
      );
}

// ─── Shared Widgets ───────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = _tagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(tag.toUpperCase(),
          style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.xsAll,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 2),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 8, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _InlineStat extends StatelessWidget {
  final IconData icon;
  final int value;
  const _InlineStat(this.icon, this.value);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text('$value',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xsAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.xsAll),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _SheetActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge(this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800))),
      );
}

class _DetailMetaItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailMetaItem(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );
}

// ─── Moderation Log Panel ─────────────────────────────────

class _ModerationLogPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final List<ModerationAction> actions;

  const _ModerationLogPanel({
    required this.expanded,
    required this.onToggle,
    required this.actions,
  });

  Color _actionColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('delete') || a.contains('ban')) return AppColors.error;
    if (a.contains('flag') || a.contains('hide')) return AppColors.warning;
    if (a.contains('approve') || a.contains('unflag')) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(LucideIcons.clipboardList,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 8),
                const Text('Moderation Log',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(width: 6),
                if (actions.isNotEmpty)
                  _CountBadge(actions.length, AppColors.textMuted),
                const Spacer(),
                Icon(
                  expanded ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ]),
            ),
          ),
          if (expanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              child: actions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: Text('No moderation actions yet',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted))),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      itemCount: actions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (ctx, i) {
                        final a = actions[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: _actionColor(a.action),
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12),
                                children: [
                                  TextSpan(
                                      text: '${a.adminName ?? 'Admin'} ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                  TextSpan(
                                      text: '${a.action} ${a.targetType}',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary)),
                                  if (a.reason != null)
                                    TextSpan(
                                        text: ' — ${a.reason}',
                                        style: const TextStyle(
                                            color: AppColors.textMuted)),
                                ],
                              ),
                            )),
                            const SizedBox(width: 8),
                            Text(_relativeTime(a.createdAt),
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textMuted)),
                          ]),
                        );
                      },
                    ),
            ).animate().fadeIn(duration: 150.ms),
        ]),
      );
}

// ─── Empty State ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final icon = filter == 'flagged'
        ? LucideIcons.shieldCheck
        : filter == 'hidden'
            ? LucideIcons.eye
            : filter == 'pinned'
                ? LucideIcons.pin
                : LucideIcons.messageSquare;

    final title = filter == 'flagged'
        ? 'No flagged posts'
        : filter == 'hidden'
            ? 'No hidden posts'
            : filter == 'pinned'
                ? 'No pinned posts'
                : filter == 'anonymous'
                    ? 'No anonymous posts'
                    : 'No posts found';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: AppColors.surfaceVariant, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            filter == 'flagged' ? 'Community content looks clean' : 'Nothing matches this filter',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
