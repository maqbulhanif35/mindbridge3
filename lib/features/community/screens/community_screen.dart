import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/peer_chat_model.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/providers/peer_chat_provider.dart';
import 'peer_chat_page.dart';

// ─── Constants ───────────────────────────────────────────

const _kTags = [
  'All', 'Anxiety', 'Depression', 'Stress', 'Sleep',
  'Relationships', 'Academic', 'Self-Care', 'General'
];

const _kTagEmoji = {
  'All': '🌐', 'Anxiety': '😰', 'Depression': '💙', 'Stress': '😤',
  'Sleep': '😴', 'Relationships': '💛', 'Academic': '📚',
  'Self-Care': '🌸', 'General': '💬',
};

const _kReactionEmoji = {'love': '❤️', 'relate': '🤝', 'strong': '💪', 'hug': '🤗'};
const _kSortLabels = {'recent': 'Recent', 'popular': 'Popular', 'unanswered': 'Unanswered'};

const _kCrisisKeywords = [
  'suicide', 'kill myself', 'end it all', 'give up',
  "can't go on", 'no reason to live', 'self harm', 'hurt myself'
];

const _kHotReactions = 5;
const _kHotComments = 3;
const _kNewMinutes = 30;
const _kTrendingEngagementMin = 4;

const _kTagColors = {
  'Anxiety':       Color(0xFFF59E0B),
  'Depression':    Color(0xFF6366F1),
  'Stress':        Color(0xFFEF4444),
  'Sleep':         Color(0xFF8B5CF6),
  'Relationships': Color(0xFFEC4899),
  'Academic':      Color(0xFF3B82F6),
  'Self-Care':     Color(0xFF10B981),
  'General':       Color(0xFF64748B),
  'All':           Color(0xFF00BEB4),
};

// ─── Helpers ─────────────────────────────────────────────

Color _tagColor(String tag) => _kTagColors[tag] ?? AppColors.primary;

Color _avatarColorFor(String name) {
  final palette = [
    const Color(0xFF00BEB4), const Color(0xFF6366F1), const Color(0xFFEC4899),
    const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFF3B82F6),
    const Color(0xFFEF4444), const Color(0xFF8B5CF6),
  ];
  int hash = 0;
  for (final c in name.codeUnits) hash = (hash * 31 + c) & 0xFFFFFFFF;
  return palette[hash % palette.length];
}

bool _isHot(CommunityPost p) =>
    p.totalReactions >= _kHotReactions || p.commentCount >= _kHotComments;

bool _isNew(CommunityPost p) =>
    DateTime.now().difference(p.createdAt).inMinutes < _kNewMinutes;

int _engagementScore(CommunityPost p) => p.totalReactions * 2 + p.commentCount * 3;

bool _hasCrisis(String text) =>
    _kCrisisKeywords.any((k) => text.toLowerCase().contains(k));

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ─── Navigation helper ───────────────────────────────────

PageRoute<T> _slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 320),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
);

// ─── Screen ───────────────────────────────────────────────

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  int _newPostsBanner = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communityProvider.notifier).markSeen();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final before = ref.read(communityProvider).value?.posts.length ?? 0;
    await ref.read(communityProvider.notifier).refresh();
    final after = ref.read(communityProvider).value?.posts.length ?? 0;
    final diff = after - before;
    if (diff > 0 && mounted) {
      setState(() => _newPostsBanner = diff);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _newPostsBanner = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(communityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildAppBar(asyncState.value)],
        body: asyncState.when(
          loading: () => const _LoadingFeed(),
          error: (e, _) => _ErrorFeed(
            error: e.toString(),
            onRetry: () => ref.refresh(communityProvider),
          ),
          data: (state) => Column(
            children: [
              if (_showSearch && _tabs.index != 4) _SearchBar(ctrl: _searchCtrl),
              if (_tabs.index != 4) _TagChips(state: state),
              if (_newPostsBanner > 0 && _tabs.index != 4)
                _NewPostsBanner(
                  count: _newPostsBanner,
                  onTap: () => setState(() => _newPostsBanner = 0),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _FeedTab(state: state, onRefresh: _refresh),
                    _TrendingTab(state: state),
                    _MyTab(state: state, onRefresh: _refresh),
                    _SavedTab(state: state),
                    const _ConnectTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _tabs.index != 4 ? const _ComposeFab() : null,
    );
  }

  SliverAppBar _buildAppBar(CommunityState? state) {
    final postCount = state?.posts.length ?? 0;
    final todayCount = state?.posts.where((p) =>
        p.createdAt.isAfter(DateTime.now().subtract(const Duration(hours: 24)))).length ?? 0;
    final activeCount = state?.posts.where((p) =>
        DateTime.now().difference(p.createdAt).inHours < 1).length ?? 0;

    return SliverAppBar(
      expandedHeight: 195,
      pinned: true,
      backgroundColor: const Color(0xFF007A72),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00C9BE), Color(0xFF006D64)],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(18),
                  ),
                ),
              ),
              Positioned(
                right: 50, top: 40,
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(12),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(45),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: Colors.white.withAlpha(60)),
                            ),
                            child: const Icon(LucideIcons.users, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Community',
                                style: TextStyle(
                                  color: Colors.white, fontSize: 22,
                                  fontWeight: FontWeight.w800, letterSpacing: -0.5,
                                )),
                              Text('Safe space to share & connect',
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          _AppBarBtn(
                            icon: _showSearch ? LucideIcons.x : LucideIcons.search,
                            onTap: () => setState(() => _showSearch = !_showSearch),
                          ),
                          const SizedBox(width: 8),
                          _AppBarBtn(
                            icon: LucideIcons.slidersHorizontal,
                            onTap: () => _showSortSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _HeaderStat(icon: LucideIcons.messageSquare, value: '$postCount', label: 'Posts'),
                          const SizedBox(width: 10),
                          _HeaderStat(icon: LucideIcons.calendarDays, value: '$todayCount', label: 'Today'),
                          const SizedBox(width: 10),
                          _HeaderStat(icon: LucideIcons.zap, value: '$activeCount', label: 'Active now'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicator: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white60,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: '✨ Feed'),
                          Tab(text: '🔥 Trending'),
                          Tab(text: '👤 Mine'),
                          Tab(text: '🔖 Saved'),
                          Tab(text: '💬 Connect'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _SortSheet(),
    );
  }
}

// ─── App Bar helpers ─────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(55)),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _HeaderStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(45)),
      ),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── New Posts Banner ─────────────────────────────────────

class _NewPostsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NewPostsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00BEB4), Color(0xFF0097A7)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BEB4).withAlpha(80),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.arrowUp, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Text('$count new post${count > 1 ? "s" : ""} since your last visit',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Dismiss',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),
  );
}

// ─── Search Bar ───────────────────────────────────────────

class _SearchBar extends ConsumerWidget {
  final TextEditingController ctrl;
  const _SearchBar({required this.ctrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: TextField(
      controller: ctrl,
      autofocus: true,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: 'Search posts, topics, people...',
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF64748B)),
        suffixIcon: ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF64748B)),
                onPressed: () {
                  ctrl.clear();
                  ref.read(communityProvider.notifier).setSearch('');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: (v) => ref.read(communityProvider.notifier).setSearch(v),
    ),
  );
}

// ─── Tag Chips ────────────────────────────────────────────

class _TagChips extends ConsumerWidget {
  final CommunityState state;
  const _TagChips({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
    ),
    height: 52,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      itemCount: _kTags.length,
      itemBuilder: (_, i) {
        final tag = _kTags[i];
        final active = state.activeTag == tag;
        final color = _tagColor(tag);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(communityProvider.notifier).setTag(tag);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: active ? color : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: active ? color : const Color(0xFFE2E8F0),
                width: active ? 0 : 1,
              ),
              boxShadow: active ? [
                BoxShadow(color: color.withAlpha(70), blurRadius: 8, offset: const Offset(0, 2)),
              ] : null,
            ),
            child: Text(
              '${_kTagEmoji[tag] ?? ''} $tag',
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFF475569),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ─── Sort Sheet ───────────────────────────────────────────

class _SortSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(communityProvider).value?.sortMode ?? 'recent';
    const icons = {
      'recent': LucideIcons.clock,
      'popular': LucideIcons.trendingUp,
      'unanswered': LucideIcons.messageCircle,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Icon(LucideIcons.listFilter, size: 20, color: Color(0xFF334155)),
            SizedBox(width: 10),
            Text('Sort Posts',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1E293B))),
          ]),
        ),
        const SizedBox(height: 12),
        ..._kSortLabels.entries.map((e) {
          final active = current == e.key;
          return ListTile(
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icons[e.key]!, size: 18,
                color: active ? Colors.white : const Color(0xFF64748B)),
            ),
            title: Text(e.value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: active ? AppColors.primary : const Color(0xFF1E293B),
                fontSize: 15,
              )),
            trailing: active
                ? Icon(LucideIcons.circleCheck, size: 20, color: AppColors.primary)
                : null,
            onTap: () {
              ref.read(communityProvider.notifier).setSortMode(e.key);
              Navigator.pop(context);
            },
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Feed Tab ─────────────────────────────────────────────

class _FeedTab extends StatelessWidget {
  final CommunityState state;
  final Future<void> Function() onRefresh;
  const _FeedTab({required this.state, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final posts = state.filteredPosts;
    if (posts.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.messageSquare,
        title: 'No posts yet',
        subtitle: 'Be the first to share something\nwith the community',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: posts.length,
        itemBuilder: (ctx, i) => _PostCard(post: posts[i]),
      ),
    );
  }
}

// ─── Trending Tab ─────────────────────────────────────────

class _TrendingTab extends StatelessWidget {
  final CommunityState state;
  const _TrendingTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final trending = state.posts
        .where((p) => p.createdAt.isAfter(cutoff) && _engagementScore(p) >= _kTrendingEngagementMin)
        .toList()
      ..sort((a, b) => _engagementScore(b).compareTo(_engagementScore(a)));

    if (trending.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.flame,
        title: 'Nothing trending yet',
        subtitle: 'Posts with high engagement from\nthe last 48 hours show here',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        // Trending header banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFEF4444)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withAlpha(60),
                blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text('🔥', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trending Now',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  Text('${trending.length} hot post${trending.length != 1 ? 's' : ''} · last 48h',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${trending.fold(0, (s, p) => s + _engagementScore(p))} pts',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ),

        // Top 3 podium
        if (trending.length >= 2) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('🏆 Top Posts',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF64748B), letterSpacing: 0.5)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (trending.length >= 2)
                Expanded(child: _PodiumCard(post: trending[1], rank: 2, medal: '🥈')),
              const SizedBox(width: 8),
              Expanded(child: _PodiumCard(post: trending[0], rank: 1, medal: '🥇', tall: true)),
              const SizedBox(width: 8),
              if (trending.length >= 3)
                Expanded(child: _PodiumCard(post: trending[2], rank: 3, medal: '🥉'))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (trending.length > 3) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('More Trending',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF64748B), letterSpacing: 0.5)),
          ),
          ...trending.skip(3).toList().asMap().entries.map((e) =>
            _PostCard(post: e.value, rank: e.key + 4)),
        ] else if (trending.length <= 3)
          ...trending.asMap().entries.map((e) =>
            _PostCard(post: e.value, rank: e.key + 1)),
      ],
    );
  }
}

// ─── Podium Card ─────────────────────────────────────────

class _PodiumCard extends ConsumerWidget {
  final CommunityPost post;
  final int rank;
  final String medal;
  final bool tall;
  const _PodiumCard({required this.post, required this.rank, required this.medal, this.tall = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = _tagColor(post.tag);
    return GestureDetector(
      onTap: () => Navigator.push(context, _slideRoute(PostDetailPage(postId: post.id))),
      child: Container(
        height: tall ? 160 : 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tc.withAlpha(50)),
          boxShadow: [
            BoxShadow(color: tc.withAlpha(40), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(medal, style: TextStyle(fontSize: tall ? 22 : 18)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: tc.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${_engagementScore(post)}pt',
                    style: TextStyle(fontSize: 10, color: tc, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: tall ? 12 : 11,
                color: const Color(0xFF334155),
                height: 1.4,
                fontWeight: FontWeight.w500,
              )),
            const Spacer(),
            Row(
              children: [
                _ColoredAvatar(name: post.displayName, size: 18),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(post.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── My Posts Tab ─────────────────────────────────────────

class _MyTab extends ConsumerWidget {
  final CommunityState state;
  final Future<void> Function() onRefresh;
  const _MyTab({required this.state, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = state.myPosts;
    if (posts.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.user,
        title: "You haven't posted yet",
        subtitle: 'Share your thoughts and\nconnect with peers',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: posts.length,
        itemBuilder: (ctx, i) => _PostCard(post: posts[i], showDelete: true),
      ),
    );
  }
}

// ─── Saved Tab ────────────────────────────────────────────

class _SavedTab extends StatelessWidget {
  final CommunityState state;
  const _SavedTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final posts = state.savedPosts;
    if (posts.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.bookmark,
        title: 'No saved posts',
        subtitle: 'Tap the bookmark icon on any post\nto save it for later',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: posts.length,
      itemBuilder: (ctx, i) => _PostCard(post: posts[i]),
    );
  }
}

// ─── Post Card ────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final CommunityPost post;
  final int? rank;
  final bool showDelete;

  const _PostCard({
    required this.post,
    this.rank,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = _tagColor(post.tag);
    final hasCrisis = _hasCrisis(post.content);
    final type = post.postType;

    final typeAccent = type == 'question'
        ? const Color(0xFF6366F1)
        : type == 'poll'
            ? const Color(0xFF3B82F6)
            : type == 'milestone'
                ? const Color(0xFFF59E0B)
                : tc;

    return GestureDetector(
      onTap: () => Navigator.push(context, _slideRoute(PostDetailPage(postId: post.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: typeAccent.withAlpha(28),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type-specific top banner ────────────────
              if (type == 'question') _QuestionBanner()
              else if (type == 'milestone') _MilestoneBanner()
              else if (type == 'poll') _PollBanner()
              else
                // Regular text post: thin colored top line
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tc, tc.withAlpha(120)],
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Author row ──────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ColoredAvatar(name: post.displayName, size: 42),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                  child: Text(post.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: Color(0xFF1E293B),
                                    )),
                                ),
                                if (post.isAnonymous) ...[
                                  const SizedBox(width: 6),
                                  _AnonBadge(),
                                ],
                              ]),
                              const SizedBox(height: 3),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tc.withAlpha(18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('${_kTagEmoji[post.tag] ?? ''} ${post.tag}',
                                    style: TextStyle(fontSize: 10, color: tc, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 6),
                                Icon(LucideIcons.clock, size: 10, color: const Color(0xFFCBD5E1)),
                                const SizedBox(width: 3),
                                Text(_timeAgo(post.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ]),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _PostMenu(post: post, showDelete: showDelete),
                            if (rank != null) _BadgePill(label: '#$rank', color: const Color(0xFF94A3B8)),
                            if (post.isPinned) _BadgePill(label: '📌', color: const Color(0xFF475569)),
                            if (_isHot(post)) _BadgePill(label: '🔥 Hot', color: const Color(0xFFEF4444)),
                            if (_isNew(post)) _BadgePill(label: '✨ New', color: AppColors.primary),
                          ],
                        ),
                      ],
                    ),

                    if (hasCrisis) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: const Border(left: BorderSide(color: Color(0xFFEF4444), width: 3)),
                        ),
                        child: const Row(children: [
                          Icon(LucideIcons.heartHandshake, size: 14, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'Support is available. Reach out to a counsellor anytime.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                          )),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ── Content ──────────────────────────────────
                    if (type == 'question')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0FE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF6366F1).withAlpha(35)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('❓', style: TextStyle(fontSize: 17)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(post.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14, height: 1.55, color: Color(0xFF3730A3),
                              fontStyle: FontStyle.italic,
                            ))),
                        ]),
                      )
                    else if (type == 'milestone')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF59E0B).withAlpha(70)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('🏆', style: TextStyle(fontSize: 19)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(post.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14, height: 1.55, color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                            ))),
                        ]),
                      )
                    else
                      Text(post.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14, height: 1.6, color: Color(0xFF334155))),

                    if (post.postType == 'poll' && post.pollOptions != null) ...[
                      const SizedBox(height: 10),
                      _PollPreview(post: post),
                    ],

                    if (post.moodScore != null) ...[
                      const SizedBox(height: 8),
                      _MoodChip(score: post.moodScore!),
                    ],

                    const SizedBox(height: 12),

                    // ── Divider ──────────────────────────────────
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            typeAccent.withAlpha(40),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Action bar ───────────────────────────────
                    Row(children: [
                      _AnimatedReactionRow(post: post),
                      const Spacer(),
                      // Comment count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(LucideIcons.messageCircle, size: 13,
                            color: post.commentCount > 0 ? AppColors.primary : const Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text('${post.commentCount}',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: post.commentCount > 0 ? AppColors.primary : const Color(0xFF94A3B8),
                            )),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      _BookmarkBtn(post: post),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Post type banners ────────────────────────────────────

class _QuestionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(22),
          ),
        ),
        child: Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('❓', style: TextStyle(fontSize: 12))),
          ),
          const SizedBox(width: 8),
          const Text('Seeking answers',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Help out →',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _MilestoneBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFFFBF49)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(22),
          ),
        ),
        child: Row(children: [
          const Text('🎉', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Text('Personal Win',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Celebrate 🙌',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _PollBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(22),
          ),
        ),
        child: Row(children: [
          const Text('📊', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Text('Community Poll',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Cast your vote →',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _AnonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.eyeOff, size: 8, color: Color(0xFF94A3B8)),
          SizedBox(width: 3),
          Text('anon', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
        ]),
      );
}

// ─── Badge Pill ───────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(50)),
    ),
    child: Text(label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );
}

// ─── Post Type Pill ───────────────────────────────────────

class _PostTypePill extends StatelessWidget {
  final String type;
  const _PostTypePill({required this.type});

  static final _info = {
    'question': ('❓ Question', Color(0xFF6366F1)),
    'poll':     ('📊 Poll',     Color(0xFF3B82F6)),
    'milestone':('🏆 Win',      Color(0xFFF59E0B)),
  };

  @override
  Widget build(BuildContext context) {
    final d = _info[type];
    if (d == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: d.$2.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: d.$2.withAlpha(50)),
      ),
      child: Text(d.$1,
        style: TextStyle(color: d.$2, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Post Menu ────────────────────────────────────────────

class _PostMenu extends ConsumerWidget {
  final CommunityPost post;
  final bool showDelete;
  const _PostMenu({required this.post, required this.showDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = post.userId == uid;

    return PopupMenuButton<String>(
      icon: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withAlpha(10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(LucideIcons.ellipsisVertical, size: 14, color: Color(0xFF64748B)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      itemBuilder: (_) => [
        if (isOwner || showDelete)
          PopupMenuItem(
            value: 'delete',
            child: Row(children: const [
              Icon(LucideIcons.trash2, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Delete post', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
            ])),
        PopupMenuItem(
          value: 'share',
          child: Row(children: const [
            Icon(LucideIcons.copy, size: 16, color: Color(0xFF334155)),
            SizedBox(width: 10),
            Text('Copy text', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          ])),
        PopupMenuItem(
          value: 'report',
          child: Row(children: const [
            Icon(LucideIcons.flag, size: 16, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text('Report', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
          ])),
      ],
      onSelected: (val) async {
        if (val == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Delete post?',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              content: const Text('This cannot be undone.',
                style: TextStyle(color: Color(0xFF64748B))),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
          if (confirm == true) await ref.read(communityProvider.notifier).deletePost(post.id);
        } else if (val == 'share') {
          await Clipboard.setData(ClipboardData(text: post.content));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [
                Icon(LucideIcons.clipboardCheck, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Copied to clipboard'),
              ]),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          }
        } else if (val == 'report') {
          if (context.mounted) _showReportDialog(context);
        }
      },
    );
  }

  void _showReportDialog(BuildContext context) {
    String? selected;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, st) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(LucideIcons.flag, size: 20, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text('Report Post', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a reason:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              const SizedBox(height: 8),
              ...[
                'Harmful content', 'Harassment or bullying',
                'Misinformation', 'Spam', 'Other',
              ].map((r) => RadioListTile<String>(
                value: r, groupValue: selected,
                title: Text(r, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                dense: true,
                activeColor: AppColors.primary,
                onChanged: (v) => st(() => selected = v),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: selected == null ? null : () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Report submitted — thank you'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated Reaction Row ────────────────────────────────

class _AnimatedReactionRow extends ConsumerWidget {
  final CommunityPost post;
  const _AnimatedReactionRow({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: _kReactionEmoji.entries.map((e) {
      final count = post.reactions[e.key] ?? 0;
      final active = post.userReaction == e.key;
      return _ReactionBtn(
        emoji: e.value,
        count: count,
        active: active,
        onTap: () => ref.read(communityProvider.notifier).toggleReaction(post.id, e.key),
      );
    }).toList(),
  );
}

class _ReactionBtn extends StatefulWidget {
  final String emoji;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _ReactionBtn({required this.emoji, required this.count, required this.active, required this.onTap});
  @override
  State<_ReactionBtn> createState() => _ReactionBtnState();
}

class _ReactionBtnState extends State<_ReactionBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { _ctrl.forward(from: 0); widget.onTap(); },
    child: ScaleTransition(
      scale: _scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.active ? AppColors.primary.withAlpha(20) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.active ? AppColors.primary.withAlpha(100) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 13)),
            if (widget.count > 0) ...[
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Text('${widget.count}',
                  key: ValueKey(widget.count),
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: widget.active ? AppColors.primary : const Color(0xFF64748B),
                  )),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ─── Comment Count Btn ────────────────────────────────────

class _CommentCountBtn extends StatelessWidget {
  final int count;
  const _CommentCountBtn({required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.messageCircle, size: 13, color: Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text('$count',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
      ],
    ),
  );
}

// ─── Bookmark Button ──────────────────────────────────────

class _BookmarkBtn extends ConsumerWidget {
  final CommunityPost post;
  const _BookmarkBtn({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    onTap: () => ref.read(communityProvider.notifier).toggleBookmark(post.id),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: post.isBookmarked ? AppColors.primary.withAlpha(20) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: post.isBookmarked ? AppColors.primary.withAlpha(80) : Colors.transparent,
        ),
      ),
      child: Icon(
        post.isBookmarked ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
        size: 15,
        color: post.isBookmarked ? AppColors.primary : const Color(0xFF64748B),
      ),
    ),
  );
}

// ─── Poll Preview ─────────────────────────────────────────

class _PollPreview extends ConsumerWidget {
  final CommunityPost post;
  const _PollPreview({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = post.pollOptions!;
    final total = options.fold(0, (s, o) => s + o.votes);
    final voted = post.userVoteIndex != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: options.asMap().entries.take(3).map((e) {
          final pct = total == 0 ? 0.0 : e.value.votes / total;
          final isChosen = post.userVoteIndex == e.key;
          return GestureDetector(
            onTap: voted ? null : () =>
                ref.read(communityProvider.notifier).votePoll(post.id, e.key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              height: 34,
              decoration: BoxDecoration(
                color: isChosen ? AppColors.primary.withAlpha(20) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isChosen ? AppColors.primary : const Color(0xFFCBD5E1),
                  width: isChosen ? 1.5 : 1,
                ),
              ),
              child: Stack(
                children: [
                  if (voted)
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isChosen ? AppColors.primary.withAlpha(30) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(e.value.option,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                              color: isChosen ? AppColors.primary : const Color(0xFF334155),
                            )),
                        ),
                        if (voted)
                          Text('${(pct * 100).round()}%',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: isChosen ? AppColors.primary : const Color(0xFF94A3B8),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Mood Chip ────────────────────────────────────────────

class _MoodChip extends StatelessWidget {
  final int score;
  const _MoodChip({required this.score});

  @override
  Widget build(BuildContext context) {
    final emoji = score >= 8 ? '😁' : score >= 6 ? '🙂' : score >= 4 ? '😐' : score >= 2 ? '😔' : '😢';
    final color = score >= 7 ? const Color(0xFF10B981)
        : score >= 4 ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text('Mood $score/10',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Colored Avatar ───────────────────────────────────────

class _ColoredAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _ColoredAvatar({required this.name, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = _avatarColorFor(name);
    final initials = name.isEmpty ? '?'
        : name.trim().split(' ').take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withAlpha(190)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withAlpha(55), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(initials,
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          )),
      ),
    );
  }
}

// ─── Post Detail Page ─────────────────────────────────────

class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});
  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  List<CommunityComment> _comments = [];
  bool _loadingComments = true;
  bool _submitting = false;
  final _commentCtrl = TextEditingController();
  bool _anonComment = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final result = await ref.read(communityProvider.notifier).fetchComments(widget.postId);
    if (mounted) setState(() { _comments = result; _loadingComments = false; });
  }

  Future<void> _submit() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    await ref.read(communityProvider.notifier).addComment(
      postId: widget.postId,
      content: text,
      isAnonymous: _anonComment,
    );
    _commentCtrl.clear();
    await _loadComments();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete comment?',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        content: const Text('This cannot be undone.',
          style: TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(communityProvider.notifier).deleteComment(commentId, widget.postId);
      await _loadComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityProvider).value;
    if (state == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final post = state.posts.where((p) => p.id == widget.postId).firstOrNull;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: const Center(child: Text('Post not found')),
      );
    }

    final tc = _tagColor(post.tag);
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.06),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.arrowLeft, color: Color(0xFF334155), size: 18),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tc.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_kTagEmoji[post.tag] ?? '💬', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(post.tag,
                    style: TextStyle(color: tc, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          _BookmarkBtn(post: post),
          const SizedBox(width: 4),
          _PostMenu(post: post, showDelete: post.userId == uid),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Post body card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 12, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [tc.withOpacity(0.08), tc.withOpacity(0.03)],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          border: Border(
                            bottom: BorderSide(color: tc.withOpacity(0.15)),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Avatar with gradient
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [tc, tc.withOpacity(0.7)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(color: tc.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  post.displayName.isNotEmpty ? post.displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(post.displayName,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    Icon(LucideIcons.clock, size: 11, color: tc.withOpacity(0.6)),
                                    const SizedBox(width: 4),
                                    Text(_timeAgo(post.createdAt),
                                      style: TextStyle(color: tc.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                                    if (post.isAnonymous) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          const Icon(LucideIcons.eyeOff, size: 9, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 3),
                                          const Text('anon', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                        ]),
                                      ),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_isHot(post)) _BadgePill(label: '🔥 Hot', color: const Color(0xFFFF6B6B)),
                                if (_isNew(post)) _BadgePill(label: '✨ New', color: AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_hasCrisis(post.content)) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: const Border(left: BorderSide(color: Color(0xFFEF4444), width: 3)),
                                ),
                                child: const Row(children: [
                                  Icon(LucideIcons.heartHandshake, size: 16, color: Color(0xFFDC2626)),
                                  SizedBox(width: 8),
                                  Expanded(child: Text(
                                    'If you\'re struggling, support is available. Reach out anytime.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600))),
                                ]),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(post.content,
                              style: const TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF1E293B))),
                            if (post.postType == 'poll' && post.pollOptions != null) ...[
                              const SizedBox(height: 16),
                              _FullPoll(post: post),
                            ],
                            if (post.moodScore != null) ...[
                              const SizedBox(height: 12),
                              _MoodChip(score: post.moodScore!),
                            ],
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 10),
                            _AnimatedReactionRow(post: post),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Engagement stats
                Row(
                  children: [
                    _StatCard(icon: LucideIcons.heart, label: 'Reactions',
                      value: '${post.totalReactions}', color: const Color(0xFFEF4444)),
                    const SizedBox(width: 10),
                    _StatCard(icon: LucideIcons.messageCircle, label: 'Comments',
                      value: '${post.commentCount}', color: AppColors.primary),
                    const SizedBox(width: 10),
                    _StatCard(icon: LucideIcons.trendingUp, label: 'Score',
                      value: '${_engagementScore(post)}', color: const Color(0xFF8B5CF6)),
                  ],
                ),

                const SizedBox(height: 20),

                // Comments header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(LucideIcons.messageCircle, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text('Comments (${_comments.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B))),
                    const Spacer(),
                    GestureDetector(
                      onTap: _loadComments,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.refreshCw, size: 12, color: Color(0xFF64748B)),
                            SizedBox(width: 4),
                            Text('Refresh', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_loadingComments)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator()))
                else if (_comments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Column(children: [
                      Text('💬', style: TextStyle(fontSize: 36)),
                      SizedBox(height: 10),
                      Text('No comments yet',
                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155), fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Be the first to reply!',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFBFD7FF), width: 1),
                    ),
                    child: Column(
                      children: _comments.map((c) => _CommentBubble(
                        comment: c,
                        onDelete: c.userId == uid ? () => _deleteComment(c.id) : null,
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),

          _CommentInput(
            ctrl: _commentCtrl,
            isAnon: _anonComment,
            submitting: _submitting,
            onToggleAnon: () => setState(() => _anonComment = !_anonComment),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// ─── Full Poll ────────────────────────────────────────────

class _FullPoll extends ConsumerWidget {
  final CommunityPost post;
  const _FullPoll({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = post.pollOptions!;
    final total = options.fold(0, (s, o) => s + o.votes);
    final voted = post.userVoteIndex != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.chartBar, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Community Poll',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
            if (total > 0) ...[
              const Spacer(),
              Text('$total vote${total != 1 ? "s" : ""}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ]),
          const SizedBox(height: 10),
          ...options.asMap().entries.map((e) {
            final pct = total == 0 ? 0.0 : e.value.votes / total;
            final isChosen = post.userVoteIndex == e.key;
            return GestureDetector(
              onTap: voted ? null : () =>
                  ref.read(communityProvider.notifier).votePoll(post.id, e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 46,
                decoration: BoxDecoration(
                  color: isChosen ? AppColors.primary.withAlpha(15) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isChosen ? AppColors.primary : const Color(0xFFCBD5E1),
                    width: isChosen ? 2 : 1,
                  ),
                ),
                child: Stack(children: [
                  if (voted)
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      widthFactor: pct,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isChosen ? AppColors.primary.withAlpha(25) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      if (!voted)
                        Container(width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                          )),
                      if (isChosen && voted)
                        Icon(LucideIcons.circleCheck, size: 18, color: AppColors.primary),
                      if (!isChosen && voted)
                        const Icon(LucideIcons.circle, size: 18, color: Color(0xFFCBD5E1)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value.option,
                          style: TextStyle(
                            fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                            color: isChosen ? AppColors.primary : const Color(0xFF334155),
                          )),
                      ),
                      if (voted)
                        Text('${(pct * 100).round()}%',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: isChosen ? AppColors.primary : const Color(0xFF94A3B8),
                          )),
                    ]),
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withAlpha(22), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─── Comment Bubble ───────────────────────────────────────

class _CommentBubble extends StatefulWidget {
  final CommunityComment comment;
  final VoidCallback? onDelete;
  const _CommentBubble({required this.comment, this.onDelete});

  @override
  State<_CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<_CommentBubble>
    with SingleTickerProviderStateMixin {
  int _localLikes = 0;
  bool _liked = false;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _localLikes += _liked ? 1 : -1;
    });
    if (_liked) _heartCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final ac = _avatarColorFor(c.displayName);
    final initials = c.displayName.isNotEmpty
        ? c.displayName.trim().split(' ').take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ac, ac.withAlpha(200)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: ac.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: Text(initials,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              if (c.isAnonymous)
                Positioned(
                  right: -3, bottom: -3,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(LucideIcons.eyeOff, size: 8, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time row
                Row(children: [
                  Text(c.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: ac)),
                  if (c.isAnonymous) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('anon',
                        style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  Text(_timeAgo(c.createdAt),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ]),
                const SizedBox(height: 5),
                // Comment body card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border.all(color: ac.withAlpha(60), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: ac.withAlpha(30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(c.content,
                    style: const TextStyle(
                      fontSize: 13.5, height: 1.55, color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    )),
                ),
                const SizedBox(height: 6),
                // Actions
                Row(children: [
                  // Like button
                  GestureDetector(
                    onTap: _toggleLike,
                    child: ScaleTransition(
                      scale: _heartScale,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _liked ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _liked ? const Color(0xFFEF4444).withAlpha(100) : Colors.transparent,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            LucideIcons.heart,
                            size: 13,
                            color: _liked ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                          ),
                          if (_localLikes > 0) ...[
                            const SizedBox(width: 4),
                            Text('$_localLikes',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                color: _liked ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                              )),
                          ],
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Reply button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ac.withAlpha(15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ac.withAlpha(50)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.cornerDownRight, size: 11, color: ac),
                      const SizedBox(width: 4),
                      Text('Reply', style: TextStyle(fontSize: 11, color: ac, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const Spacer(),
                  if (widget.onDelete != null)
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444).withAlpha(60)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(LucideIcons.trash2, size: 11, color: Color(0xFFEF4444)),
                          SizedBox(width: 4),
                          Text('Delete', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comment Input ────────────────────────────────────────

class _CommentInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isAnon;
  final bool submitting;
  final VoidCallback onToggleAnon;
  final VoidCallback onSubmit;
  const _CommentInput({
    required this.ctrl, required this.isAnon,
    required this.submitting, required this.onToggleAnon,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, -3))],
    ),
    padding: EdgeInsets.only(
      left: 14, right: 14, top: 10,
      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onToggleAnon,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isAnon ? AppColors.primary.withAlpha(12) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isAnon ? AppColors.primary.withAlpha(80) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isAnon ? LucideIcons.eyeOff : LucideIcons.eye, size: 14,
                    color: isAnon ? AppColors.primary : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(isAnon ? 'Anonymous mode ON' : 'Posting as yourself',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isAnon ? AppColors.primary : const Color(0xFF64748B),
                    )),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 30, height: 17,
                    decoration: BoxDecoration(
                      color: isAnon ? AppColors.primary : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: isAnon ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 13, height: 13,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Write a supportive reply...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: submitting ? null : onSubmit,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: submitting
                    ? const Padding(padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.sendHorizontal, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ],
      ),
    ),
  );
}

// ─── Compose FAB ──────────────────────────────────────────

class _ComposeFab extends ConsumerWidget {
  const _ComposeFab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton.extended(
    onPressed: () => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(),
    ),
    backgroundColor: AppColors.primary,
    elevation: 6,
    icon: const Icon(LucideIcons.penLine, color: Colors.white, size: 18),
    label: const Text('Share',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
  );
}

// ─── Compose Sheet ────────────────────────────────────────

class _ComposeSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _contentCtrl = TextEditingController();
  String _tag = 'General';
  String _postType = 'text';
  bool _isAnon = false;
  int? _moodScore;
  bool _submitting = false;
  final List<TextEditingController> _pollCtrls = [
    TextEditingController(), TextEditingController(),
  ];

  @override
  void dispose() {
    _contentCtrl.dispose();
    for (final c in _pollCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;

    List<PollOption>? pollOptions;
    if (_postType == 'poll') {
      final opts = _pollCtrls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .map((label) => PollOption(option: label, votes: 0))
          .toList();
      if (opts.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least 2 poll options')));
        return;
      }
      pollOptions = opts;
    }

    setState(() => _submitting = true);
    await ref.read(communityProvider.notifier).createPost(
      content: content,
      tag: _tag,
      postType: _postType,
      isAnonymous: _isAnon,
      moodScore: _moodScore,
      pollOptions: pollOptions,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_contentCtrl.text.isEmpty) { Navigator.pop(context); return; }
        final discard = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Discard post?',
              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            content: const Text('Your draft will be lost.',
              style: TextStyle(color: Color(0xFF64748B))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep', style: TextStyle(fontWeight: FontWeight.w600))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        if (discard == true && mounted) Navigator.pop(context);
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Column(children: [
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(LucideIcons.penLine, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text('New Post',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B))),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                ]),
              ]),
            ),

            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(18),
                children: [
                  const Text('Post Type',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  _PostTypeSelector(
                    current: _postType,
                    onChange: (t) => setState(() => _postType = t),
                  ),
                  const SizedBox(height: 18),

                  const Text('What\'s on your mind?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: 5,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts, feelings, or questions...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFFAFBFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                        counterStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_postType == 'poll') ...[
                    const Text('Poll Options',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    ..._pollCtrls.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20), shape: BoxShape.circle),
                          child: Center(child: Text('${e.key + 1}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: e.value,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                            decoration: InputDecoration(
                              hintText: 'Option ${e.key + 1}',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              filled: true, fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.primary)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                      ]),
                    )),
                    if (_pollCtrls.length < 4)
                      TextButton.icon(
                        onPressed: () => setState(() => _pollCtrls.add(TextEditingController())),
                        icon: Icon(LucideIcons.plus, size: 16, color: AppColors.primary),
                        label: Text('Add option',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 10),
                  ],

                  const Text('Category',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _kTags.skip(1).map((tag) {
                      final active = _tag == tag;
                      final color = _tagColor(tag);
                      return GestureDetector(
                        onTap: () => setState(() => _tag = tag),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? color : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: active ? color : const Color(0xFFE2E8F0)),
                            boxShadow: active ? [
                              BoxShadow(color: color.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))
                            ] : null,
                          ),
                          child: Text('${_kTagEmoji[tag] ?? ''} $tag',
                            style: TextStyle(
                              color: active ? Colors.white : const Color(0xFF475569),
                              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 12,
                            )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  Row(children: [
                    const Text('Current Mood',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: const Text('optional',
                        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(children: [
                      Text(_moodScore == null ? '—' : '$_moodScore/10',
                        style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 20,
                          color: _moodScore == null ? const Color(0xFFCBD5E1) : AppColors.primary,
                        )),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          value: _moodScore?.toDouble() ?? 5,
                          min: 1, max: 10, divisions: 9,
                          activeColor: AppColors.primary,
                          inactiveColor: const Color(0xFFE2E8F0),
                          onChanged: (v) => setState(() => _moodScore = v.round()),
                        ),
                      ),
                      if (_moodScore != null)
                        GestureDetector(
                          onTap: () => setState(() => _moodScore = null),
                          child: const Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8))),
                    ]),
                  ),
                  const SizedBox(height: 18),

                  GestureDetector(
                    onTap: () => setState(() => _isAnon = !_isAnon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isAnon ? AppColors.primary.withAlpha(12) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isAnon ? AppColors.primary.withAlpha(80) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: _isAnon ? AppColors.primary.withAlpha(25) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(LucideIcons.eyeOff, size: 18,
                            color: _isAnon ? AppColors.primary : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Post Anonymously',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14,
                                  color: _isAnon ? AppColors.primary : const Color(0xFF1E293B))),
                              const Text('Your name won\'t be visible',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isAnon,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _isAnon = v),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            Container(
              padding: EdgeInsets.fromLTRB(18, 12, 18,
                  MediaQuery.of(context).viewInsets.bottom + 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.send, size: 18, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Post to Community',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Post Type Selector ───────────────────────────────────

class _PostTypeSelector extends StatelessWidget {
  final String current;
  final void Function(String) onChange;
  const _PostTypeSelector({required this.current, required this.onChange});

  static const _types = [
    ('text',      '💬', 'Story',    Color(0xFF00BEB4)),
    ('question',  '❓', 'Question', Color(0xFF6366F1)),
    ('poll',      '📊', 'Poll',     Color(0xFF3B82F6)),
    ('milestone', '🏆', 'Win',      Color(0xFFF59E0B)),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: _types.map((t) {
      final active = current == t.$1;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChange(t.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? t.$4 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: active ? [
                BoxShadow(color: t.$4.withAlpha(70), blurRadius: 8, offset: const Offset(0, 3))
              ] : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.$2, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 3),
                Text(t.$3,
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF64748B),
                  )),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  );
}

// ─── Loading / Error / Empty ──────────────────────────────

class _LoadingFeed extends StatefulWidget {
  const _LoadingFeed();
  @override
  State<_LoadingFeed> createState() => _LoadingFeedState();
}

class _LoadingFeedState extends State<_LoadingFeed> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 4,
    itemBuilder: (_, __) => AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        height: 160,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + _ctrl.value * 3, 0),
            end: Alignment(0.5 + _ctrl.value * 3, 0),
            colors: const [Color(0xFFEFF2F5), Color(0xFFE2E8F0), Color(0xFFEFF2F5)],
          ),
        ),
      ),
    ),
  );
}

class _ErrorFeed extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorFeed({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFECACA), width: 2),
            ),
            child: const Icon(LucideIcons.wifiOff, size: 30, color: Color(0xFFEF4444)),
          ),
          const SizedBox(height: 16),
          const Text('Failed to load',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          Text(error,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(LucideIcons.refreshCw, size: 16, color: Colors.white),
            label: const Text('Try again',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary.withAlpha(28), AppColors.primary.withAlpha(12)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withAlpha(55), width: 2),
            ),
            child: Icon(icon, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 20),
          Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B)),
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
            textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// ─── Connect Tab ─────────────────────────────────────────
// ═══════════════════════════════════════════════════════════

class _ConnectTab extends ConsumerStatefulWidget {
  const _ConnectTab();

  @override
  ConsumerState<_ConnectTab> createState() => _ConnectTabState();
}

class _ConnectTabState extends ConsumerState<_ConnectTab> {
  RealtimeChannel? _queueChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(peerChatProvider.notifier).ensureSelfReflect();
      ref.read(peerChatProvider.notifier).loadOpenRequests();
    });
    _queueChannel = Supabase.instance.client.channel('connect_tab_queue')
      ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'peer_queue',
          callback: (_) => ref.read(peerChatProvider.notifier).loadOpenRequests())
      ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'peer_queue',
          callback: (_) => ref.read(peerChatProvider.notifier).loadOpenRequests())
      ..subscribe();
  }

  @override
  void dispose() {
    _queueChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _joinRequest(PeerQueueEntry entry) async {
    final notifier = ref.read(peerChatProvider.notifier);
    final conv = await notifier.joinRequest(entry);
    if (!mounted) return;
    if (conv == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Someone else just joined that request. Try another!'),
        backgroundColor: Color(0xFFF59E0B),
      ));
      notifier.loadOpenRequests();
      return;
    }
    Navigator.of(context).push(_slideRoute(PeerChatPage(conversation: conv)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(peerChatProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      data: (state) {
        final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
        final otherRequests = state.openRequests
            .where((e) => e.userId != myUid && e.isOpen)
            .toList();
        final myRequest = state.openRequests
            .where((e) => e.userId == myUid && e.isOpen)
            .firstOrNull;

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(peerChatProvider.notifier).refresh();
            await ref.read(peerChatProvider.notifier).loadOpenRequests();
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Hero section ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00BEB4), Color(0xFF0097A7)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withAlpha(70),
                                blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Icon(LucideIcons.heartHandshake, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Space',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                            Text('Private conversations & peer support',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ]),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Feature Cards ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: _SelfReflectCard(selfReflectConvo: state.selfReflect)),
                    const SizedBox(width: 12),
                    Expanded(child: _PeerSupportCard(unreadCount: state.unreadCount)),
                  ]),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── My Waiting Request ────────────────────────
              if (myRequest != null) ...[
                SliverToBoxAdapter(
                  child: _SectionLabel(icon: LucideIcons.clock, label: 'Your Request', color: const Color(0xFFD97706)),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _MyWaitingCard(
                      entry: myRequest,
                      onOpen: () {
                        final conv = state.peerConversations
                            .where((c) => c.id == myRequest.conversationId)
                            .firstOrNull;
                        if (conv != null && context.mounted) {
                          Navigator.of(context).push(_slideRoute(PeerChatPage(conversation: conv)));
                        }
                      },
                      onCancel: () async {
                        await ref.read(peerChatProvider.notifier).cancelRequest(myRequest.id);
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],

              // ── Open Requests Board ───────────────────────
              if (otherRequests.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionLabel(icon: LucideIcons.radio, label: 'Looking for Support', color: AppColors.primary),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: otherRequests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _QueueEntryCard(
                      entry: otherRequests[i],
                      onJoin: () => _joinRequest(otherRequests[i]),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // ── Active Conversations ──────────────────────
              if (state.peerConversations.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionLabel(icon: LucideIcons.messageCircle, label: 'Your Chats', color: AppColors.primary),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: state.peerConversations.length,
                    itemBuilder: (_, i) {
                      final conv = state.peerConversations[i];
                      final isFirst = i == 0;
                      final isLast = i == state.peerConversations.length - 1;
                      return _ConversationTile(conv: conv, isFirst: isFirst, isLast: isLast);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],

              // ── Ended Conversations ────────────────────────
              if (state.endedConversations.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionLabel(icon: LucideIcons.archiveX, label: 'Past Chats', color: const Color(0xFF94A3B8)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: state.endedConversations.length,
                    itemBuilder: (_, i) {
                      final conv = state.endedConversations[i];
                      final isFirst = i == 0;
                      final isLast = i == state.endedConversations.length - 1;
                      return _ConversationTile(conv: conv, isFirst: isFirst, isLast: isLast, dimmed: true);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],

              // ── Empty state ──────────────────────────────
              if (state.peerConversations.isEmpty && state.endedConversations.isEmpty)
                const SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: LucideIcons.users,
                    title: 'No peer chats yet',
                    subtitle: 'Tap "Peer Support" above to start\na supportive conversation.',
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Section Label ────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 8),
      Text(label,
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: color, letterSpacing: 0.2)),
    ]),
  );
}

// ─── Self Reflect Card ────────────────────────────────────

class _SelfReflectCard extends ConsumerWidget {
  final PeerConversation? selfReflectConvo;
  const _SelfReflectCard({this.selfReflectConvo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final notifier = ref.read(peerChatProvider.notifier);
        final id = await notifier.ensureSelfReflect();
        if (id == null || !context.mounted) return;
        Navigator.of(context).push(_slideRoute(SelfReflectPage(conversationId: id)));
      },
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withAlpha(90),
              blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(children: [
          Positioned(right: -24, top: -24,
            child: Container(width: 90, height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withAlpha(18)))),
          Positioned(right: 14, bottom: -14,
            child: Container(width: 55, height: 55,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withAlpha(12)))),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.bookOpen, color: Colors.white, size: 20),
                ),
                const Spacer(),
                const Text('Self Reflect',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  selfReflectConvo?.lastMessage ?? 'Private journal chat',
                  style: TextStyle(color: Colors.white.withAlpha(170), fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Peer Support Card ────────────────────────────────────

class _PeerSupportCard extends ConsumerWidget {
  final int unreadCount;
  const _PeerSupportCard({required this.unreadCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showNewChatSheet(context, ref),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00BEB4), Color(0xFF0891B2)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(90),
              blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(children: [
          Positioned(right: -24, top: -24,
            child: Container(width: 90, height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withAlpha(18)))),
          Positioned(right: 14, bottom: -14,
            child: Container(width: 55, height: 55,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withAlpha(12)))),
          if (unreadCount > 0)
            Positioned(top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withAlpha(100), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text('$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              )),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.users, color: Colors.white, size: 20),
                ),
                const Spacer(),
                const Text('Peer Support',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Text('Talk to someone who cares',
                  style: TextStyle(color: Colors.white.withAlpha(170), fontSize: 11)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showNewChatSheet(BuildContext context, WidgetRef ref) {
    final topicCtrl = TextEditingController();
    bool isAnonymous = true;
    String? selectedTopic;

    const quickTopics = [
      'Anxiety & Stress', 'Academic Pressure', 'Relationships',
      'Loneliness', 'Sleep Issues', 'General Support',
    ];

    const topicEmoji = {
      'Anxiety & Stress': '😰',
      'Academic Pressure': '📚',
      'Relationships': '💛',
      'Loneliness': '💙',
      'Sleep Issues': '😴',
      'General Support': '💬',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.78,
          maxChildSize: 0.93,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),

              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BEB4), Color(0xFF0891B2)]),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(LucideIcons.users, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Peer Chat',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                      Text('Connect with someone who understands',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.x, size: 15, color: Color(0xFF64748B)),
                    ),
                  ),
                ]),
              ),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('What would you like to talk about?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    const SizedBox(height: 14),

                    // Topic grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.8,
                      children: quickTopics.map((t) {
                        final selected = selectedTopic == t;
                        final emoji = topicEmoji[t] ?? '💬';
                        return GestureDetector(
                          onTap: () => setModalState(() {
                            selectedTopic = t;
                            topicCtrl.text = t;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary.withAlpha(20) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(children: [
                              Text(emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(t,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? AppColors.primary : const Color(0xFF475569),
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: topicCtrl,
                      onChanged: (v) => setModalState(() => selectedTopic = null),
                      decoration: InputDecoration(
                        hintText: 'Or type a custom topic…',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                        prefixIcon: const Icon(LucideIcons.pencil, size: 16, color: Color(0xFF94A3B8)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Anonymous toggle
                    GestureDetector(
                      onTap: () => setModalState(() => isAnonymous = !isAnonymous),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isAnonymous ? const Color(0xFF6366F1).withAlpha(12) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isAnonymous ? const Color(0xFF6366F1).withAlpha(80) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: isAnonymous
                                  ? const Color(0xFF6366F1).withAlpha(22)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(LucideIcons.eyeOff, size: 18,
                              color: isAnonymous ? const Color(0xFF6366F1) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Stay anonymous',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14,
                                    color: isAnonymous ? const Color(0xFF6366F1) : const Color(0xFF1E293B))),
                                const Text('Your real name won\'t be shown',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          Switch(
                            value: isAnonymous,
                            onChanged: (v) => setModalState(() => isAnonymous = v),
                            activeColor: const Color(0xFF6366F1),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: () async {
                          final topic = topicCtrl.text.trim();
                          if (topic.isEmpty) return;
                          Navigator.pop(ctx);
                          final entry = await ref
                              .read(peerChatProvider.notifier)
                              .postOpenRequest(topic: topic, isAnonymous: isAnonymous);
                          if (entry == null || !context.mounted) return;
                          final conv = ref
                              .read(peerChatProvider)
                              .value
                              ?.peerConversations
                              .where((c) => c.id == entry.conversationId)
                              .firstOrNull
                            ?? PeerConversation(
                                id: entry.conversationId,
                                user1Id: '',
                                topic: topic,
                                isAnonymous: isAnonymous,
                                createdAt: DateTime.now());
                          if (!context.mounted) return;
                          Navigator.of(context).push(_slideRoute(PeerChatPage(conversation: conv)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Start Conversation',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────

class _ConversationTile extends ConsumerWidget {
  final PeerConversation conv;
  final bool isFirst;
  final bool isLast;
  final bool dimmed;
  const _ConversationTile({
    required this.conv, this.isFirst = false,
    this.isLast = false, this.dimmed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelf = conv.isSelfReflect;
    final myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final color = isSelf
        ? const Color(0xFF7C3AED)
        : _tagColor(const {
            'Anxiety & Stress': 'Anxiety',
            'Academic Pressure': 'Academic',
            'Relationships': 'Relationships',
            'Loneliness': 'Depression',
            'Sleep Issues': 'Sleep',
            'General Support': 'General',
          }[conv.topic] ?? 'General');

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? 18 : 6),
      topRight: Radius.circular(isFirst ? 18 : 6),
      bottomLeft: Radius.circular(isLast ? 18 : 6),
      bottomRight: Radius.circular(isLast ? 18 : 6),
    );

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Container(
        margin: EdgeInsets.only(bottom: isLast ? 0 : 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          boxShadow: isFirst ? [
            BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
          ] : null,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () {
            if (isSelf) {
              Navigator.of(context).push(_slideRoute(SelfReflectPage(conversationId: conv.id)));
            } else {
              Navigator.of(context).push(_slideRoute(PeerChatPage(conversation: conv)));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withAlpha(180)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: color.withAlpha(55), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Icon(
                      isSelf ? LucideIcons.bookOpen : LucideIcons.messageCircle,
                      color: Colors.white, size: 22),
                  ),
                  if (!isSelf && conv.isConnected && !conv.isEnded)
                    Positioned(
                      right: -1, bottom: -1,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          isSelf ? 'Self Reflect'
                              : !isSelf ? conv.peerHandle(myUid) : conv.topic,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14,
                            color: Color(0xFF1E293B)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(conv.timeAgo,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (!isSelf) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withAlpha(18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(conv.topic,
                            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          conv.lastMessage ?? (isSelf
                              ? 'Start journaling your thoughts…'
                              : 'Tap to begin the conversation'),
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                            fontStyle: conv.lastMessage == null ? FontStyle.italic : FontStyle.normal),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv.isEnded)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Ended',
                            style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                        ),
                      if (conv.isWaiting)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withAlpha(20),
                            borderRadius: BorderRadius.circular(6)),
                          child: const Text('Waiting',
                            style: TextStyle(fontSize: 9, color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey.shade300),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Queue Entry Card ─────────────────────────────────────

class _QueueEntryCard extends StatelessWidget {
  final PeerQueueEntry entry;
  final VoidCallback onJoin;
  const _QueueEntryCard({required this.entry, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final color = _tagColor(const {
      'Anxiety & Stress': 'Anxiety',
      'Academic Pressure': 'Academic',
      'Relationships': 'Relationships',
      'Loneliness': 'Depression',
      'Sleep Issues': 'Sleep',
      'General Support': 'General',
    }[entry.topic] ?? entry.topic);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40)),
        boxShadow: [
          BoxShadow(color: color.withAlpha(25), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: color.withAlpha(18),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Icon(LucideIcons.user, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(18), borderRadius: BorderRadius.circular(8)),
                  child: Text(entry.topic,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                ),
                if (entry.isAnonymous) ...[
                  const SizedBox(width: 6),
                  Icon(LucideIcons.eyeOff, size: 11, color: Colors.grey.shade400),
                ],
              ]),
              const SizedBox(height: 4),
              Text(entry.displayHandle,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              Text(entry.timeAgo,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onJoin,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            elevation: 0,
          ),
          child: const Text('Join',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ─── My Waiting Card ─────────────────────────────────────

class _MyWaitingCard extends StatefulWidget {
  final PeerQueueEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onCancel;
  const _MyWaitingCard({required this.entry, required this.onOpen, required this.onCancel});
  @override
  State<_MyWaitingCard> createState() => _MyWaitingCardState();
}

class _MyWaitingCardState extends State<_MyWaitingCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFBBF24).withAlpha(70)),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFBBF24).withAlpha(35), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        ScaleTransition(
          scale: _scale,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.clock, color: Color(0xFFD97706), size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Waiting for a peer…',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E))),
              Text(widget.entry.topic,
                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F))),
              Text(widget.entry.timeAgo,
                style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
            ],
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(
            onPressed: widget.onOpen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBBF24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
            child: const Text('View', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(180),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.x, size: 15, color: Color(0xFF94A3B8)),
            ),
          ),
        ]),
      ]),
    );
  }
}
