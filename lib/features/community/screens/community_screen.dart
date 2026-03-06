import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';

// ─── Models ───────────────────────────────────────────────

class _Post {
  final int id;
  final String content;
  final String tag;
  final String emoji;
  int likes;
  final int comments;
  final String timeAgo;
  final bool isAnonymous;
  bool isSupported;
  bool isBookmarked;
  final List<String> mockComments;
  final Map<int, int> reactions; // reactionIndex → count

  _Post({
    required this.id,
    required this.content,
    required this.tag,
    required this.emoji,
    required this.likes,
    required this.comments,
    required this.timeAgo,
    required this.isAnonymous,
    this.isSupported = false,
    this.isBookmarked = false,
    this.mockComments = const [],
    Map<int, int>? reactions,
  }) : reactions = reactions ?? {};
}

// ─── Screen ───────────────────────────────────────────────

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _activeTag = 'All';
  _SortMode _sortMode = _SortMode.recent;
  int _newPostsCount = 0;
  bool _showNewBanner = false;
  Timer? _newPostTimer;
  String _searchQuery = '';
  bool _showSearch = false;

  late List<_Post> _posts;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _posts = _buildInitialPosts();

    // Simulate new posts arriving
    _newPostTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _newPostsCount++;
          _showNewBanner = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _newPostTimer?.cancel();
    super.dispose();
  }

  List<_Post> _buildInitialPosts() => [
        _Post(
          id: 1,
          content:
              "Failed my midterm and I feel like such a failure. Everyone else seems to be doing fine and I just can't keep up. Has anyone else felt like they don't belong here?",
          tag: 'Academic',
          emoji: '😞',
          likes: 47,
          comments: 23,
          timeAgo: '2h ago',
          isAnonymous: true,
          reactions: {0: 24, 1: 18, 2: 5},
          mockComments: [
            "You're not alone — imposter syndrome hits so many of us. You belong here.",
            "A failed midterm doesn't define you. Reach out to your professor!",
            "I felt this exact way in my first year. It gets better, I promise.",
          ],
        ),
        _Post(
          id: 2,
          content:
              "Update: After 3 months of therapy and using MindBridge daily, I finally feel like myself again. Don't give up — things DO get better. Sending love to everyone.",
          tag: 'Recovery',
          emoji: '💚',
          likes: 213,
          comments: 67,
          timeAgo: '4h ago',
          isAnonymous: false,
          isSupported: true,
          reactions: {0: 89, 3: 67, 2: 57},
          mockComments: [
            "This made me tear up. Thank you for sharing your journey 💚",
            "So proud of you! You're inspiring so many people.",
          ],
        ),
        _Post(
          id: 3,
          content:
              "Does anyone else feel incredibly lonely even when surrounded by people? I have friends but still feel this deep emptiness. I smile in class but cry at night.",
          tag: 'Loneliness',
          emoji: '💙',
          likes: 89,
          comments: 44,
          timeAgo: '6h ago',
          isAnonymous: true,
          reactions: {1: 61, 3: 28},
          mockComments: [
            "I know exactly what you mean. You described it perfectly.",
            "This is called 'functional depression' — please consider talking to a counselor.",
            "You're not alone in feeling alone. DM me if you want to chat.",
          ],
        ),
        _Post(
          id: 4,
          content:
              "Pulled my 3rd all-nighter this week. I know it's terrible for mental health but finals are in 2 weeks. Any tips for studying smarter, not harder? 😅",
          tag: 'Academic',
          emoji: '😴',
          likes: 34,
          comments: 51,
          timeAgo: '8h ago',
          isAnonymous: false,
          reactions: {0: 15, 2: 19},
          mockComments: [
            "Pomodoro technique saved me! 25 min study, 5 min break.",
            "Sleep is ALWAYS worth it. Your brain consolidates memory during sleep.",
          ],
        ),
        _Post(
          id: 5,
          content:
              "Reminder: you're not just a GPA. Your worth is not measured by your grades or productivity. You are enough. Please be kind to yourself today.",
          tag: 'Inspiration',
          emoji: '🌟',
          likes: 445,
          comments: 89,
          timeAgo: '12h ago',
          isAnonymous: false,
          isSupported: true,
          reactions: {0: 198, 3: 156, 2: 91},
          mockComments: [
            "I needed this today more than you know. Thank you 🌟",
            "Saving this forever.",
          ],
        ),
        _Post(
          id: 6,
          content:
              "Started journaling 30 days ago on a friend's recommendation. I cannot believe how much clarity it's given me. Highly recommend trying it for even just a week.",
          tag: 'Wellness',
          emoji: '📝',
          likes: 156,
          comments: 38,
          timeAgo: '1d ago',
          isAnonymous: false,
          isSupported: true,
          reactions: {0: 72, 2: 84},
          mockComments: [
            "MindBridge journal feature is great for this! 💪",
            "Journaling helped me identify my anxiety triggers. 100% recommend.",
          ],
        ),
      ];

  static const List<String> _tags = [
    'All',
    'Academic',
    'Anxiety',
    'Recovery',
    'Loneliness',
    'Inspiration',
    'Wellness',
    'Relationships',
  ];

  List<_Post> get _filteredPosts {
    List<_Post> result = _activeTag == 'All'
        ? List.of(_posts)
        : _posts.where((p) => p.tag == _activeTag).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.content.toLowerCase().contains(q) ||
              p.tag.toLowerCase().contains(q))
          .toList();
    }

    switch (_sortMode) {
      case _SortMode.popular:
        result.sort((a, b) => b.likes.compareTo(a.likes));
      case _SortMode.unanswered:
        result.sort((a, b) => a.comments.compareTo(b.comments));
      case _SortMode.recent:
        break;
    }
    return result;
  }

  List<_Post> get _bookmarkedPosts => _posts.where((p) => p.isBookmarked).toList();

  bool get _isCrisisTag => _activeTag == 'Loneliness' || _activeTag == 'Anxiety';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _FeedTab(
              posts: _filteredPosts,
              allTags: _tags,
              activeTag: _activeTag,
              sortMode: _sortMode,
              showNewBanner: _showNewBanner,
              newPostsCount: _newPostsCount,
              showSearch: _showSearch,
              searchQuery: _searchQuery,
              isCrisisTag: _isCrisisTag,
              showTrends: true,
              onTagChanged: (t) => setState(() => _activeTag = t),
              onSortChanged: (s) => setState(() => _sortMode = s),
              onBannerDismiss: () => setState(() {
                _showNewBanner = false;
                _newPostsCount = 0;
              }),
              onSearchChanged: (q) => setState(() => _searchQuery = q),
              onReaction: (postId, reactionIdx) {
                setState(() {
                  final post = _posts.firstWhere((p) => p.id == postId);
                  final current = post.reactions[reactionIdx] ?? 0;
                  if (current > 0) {
                    post.reactions[reactionIdx] = current - 1;
                  } else {
                    post.reactions[reactionIdx] = current + 1;
                  }
                });
              },
              onSupport: (postId) {
                HapticFeedback.lightImpact();
                setState(() {
                  final post = _posts.firstWhere((p) => p.id == postId);
                  post.isSupported = !post.isSupported;
                  post.likes += post.isSupported ? 1 : -1;
                });
              },
              onBookmark: (postId) {
                HapticFeedback.lightImpact();
                setState(() {
                  final post = _posts.firstWhere((p) => p.id == postId);
                  post.isBookmarked = !post.isBookmarked;
                });
              },
            ),
            _ExploreTab(posts: _posts),
            _MyPostsTab(
              myPosts: const [],
              bookmarkedPosts: _bookmarkedPosts,
              onBookmark: (postId) {
                setState(() {
                  final post = _posts.firstWhere((p) => p.id == postId);
                  post.isBookmarked = !post.isBookmarked;
                });
              },
              onNewPost: () => _showNewPostSheet(context),
            ),
          ],
        ),
        floatingActionButton: ListenableBuilder(
          listenable: _tabCtrl,
          builder: (_, __) => _tabCtrl.index < 2
              ? FloatingActionButton.extended(
                  onPressed: () => _showNewPostSheet(context),
                  icon: const Icon(LucideIcons.penLine, size: 18),
                  label: const Text(
                    'Share',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 3,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: _showSearch
          ? TextField(
              autofocus: true,
              style: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 16, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search posts...',
                hintStyle:
                    TextStyle(fontFamily: 'Nunito', color: AppColors.textMuted),
                border: InputBorder.none,
              ),
              onChanged: (q) => setState(() => _searchQuery = q),
            )
          : const Text(
              'Community',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
            ),
      actions: [
        if (!_showSearch) ...[
          // Online badge
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.successContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(end: 1.4, duration: 800.ms),
                const SizedBox(width: 5),
                const Text(
                  '1.2k online',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
        IconButton(
          icon: Icon(
            _showSearch ? LucideIcons.x : LucideIcons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) _searchQuery = '';
          }),
        ),
      ],
      bottom: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: [
          const Tab(text: 'Feed'),
          const Tab(text: 'Explore'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('My Posts'),
                if (_bookmarkedPosts.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_bookmarkedPosts.length}',
                      style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNewPostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewPostSheet(
        onSubmit: (content, tag, isAnon) {
          setState(() {
            _posts.insert(
              0,
              _Post(
                id: DateTime.now().millisecondsSinceEpoch,
                content: content,
                tag: tag,
                emoji: '✨',
                likes: 0,
                comments: 0,
                timeAgo: 'just now',
                isAnonymous: isAnon,
              ),
            );
          });
        },
      ),
    );
  }
}

enum _SortMode { recent, popular, unanswered }

// ─── Feed Tab ─────────────────────────────────────────────

class _FeedTab extends StatefulWidget {
  final List<_Post> posts;
  final List<String> allTags;
  final String activeTag;
  final _SortMode sortMode;
  final bool showNewBanner;
  final int newPostsCount;
  final bool showSearch;
  final String searchQuery;
  final bool isCrisisTag;
  final bool showTrends;
  final ValueChanged<String> onTagChanged;
  final ValueChanged<_SortMode> onSortChanged;
  final VoidCallback onBannerDismiss;
  final ValueChanged<String> onSearchChanged;
  final void Function(int postId, int reactionIdx) onReaction;
  final ValueChanged<int> onSupport;
  final ValueChanged<int> onBookmark;

  const _FeedTab({
    required this.posts,
    required this.allTags,
    required this.activeTag,
    required this.sortMode,
    required this.showNewBanner,
    required this.newPostsCount,
    required this.showSearch,
    required this.searchQuery,
    required this.isCrisisTag,
    required this.showTrends,
    required this.onTagChanged,
    required this.onSortChanged,
    required this.onBannerDismiss,
    required this.onSearchChanged,
    required this.onReaction,
    required this.onSupport,
    required this.onBookmark,
  });

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final Set<int> _expandedComments = {};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      children: [
        // ── Safe Banner ──
        const _SafeBanner(),

        // ── New posts banner ──
        if (widget.showNewBanner)
          _NewPostsBanner(
            count: widget.newPostsCount,
            onTap: widget.onBannerDismiss,
          ).animate().slideY(begin: -0.5, curve: Curves.easeOutCubic),

        // ── Tag Filter ──
        _TagFilter(
          tags: widget.allTags,
          active: widget.activeTag,
          onChanged: widget.onTagChanged,
        ),

        // ── Sort + count row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '${widget.posts.length} posts',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              _SortButton(
                current: widget.sortMode,
                onChanged: widget.onSortChanged,
              ),
            ],
          ),
        ),

        // ── Crisis CTA ──
        if (widget.isCrisisTag)
          const _CrisisCTA().animate().fadeIn(delay: 80.ms),

        // ── Trending (Feed only) ──
        if (widget.showTrends && widget.activeTag == 'All')
          const _TrendingTopics(),

        // ── Posts ──
        if (widget.posts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: const [
                Icon(LucideIcons.inbox, size: 48, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text(
                  'No posts in this category yet',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          )
        else
          ...widget.posts.asMap().entries.map((e) {
            final post = e.value;
            return Column(
              children: [
                _PostCard(
                  post: post,
                  isCommentsExpanded: _expandedComments.contains(post.id),
                  onSupport: () => widget.onSupport(post.id),
                  onBookmark: () => widget.onBookmark(post.id),
                  onReaction: (idx) => widget.onReaction(post.id, idx),
                  onToggleComments: () => setState(() {
                    if (_expandedComments.contains(post.id)) {
                      _expandedComments.remove(post.id);
                    } else {
                      _expandedComments.add(post.id);
                    }
                  }),
                ).animate().fadeIn(delay: (e.key * 50).ms).slideY(begin: 0.06),
                if (_expandedComments.contains(post.id))
                  _CommentsPanel(comments: post.mockComments)
                      .animate()
                      .fadeIn()
                      .slideY(begin: -0.1),
              ],
            );
          }),
      ],
    );
  }
}

// ─── Explore Tab ──────────────────────────────────────────

class _ExploreTab extends StatelessWidget {
  final List<_Post> posts;
  const _ExploreTab({required this.posts});

  static const _topics = [
    ('😰', 'Exam Stress', '234', Color(0xFF6366F1)),
    ('💤', 'Sleep Help', '189', Color(0xFF0EA5E9)),
    ('💪', 'Recovery', '156', Color(0xFF10B981)),
    ('🤝', 'Loneliness', '143', Color(0xFFFF6B6B)),
    ('😤', 'Anxiety', '128', Color(0xFFFF8C42)),
    ('✨', 'Inspiration', '112', Color(0xFFF59E0B)),
  ];

  @override
  Widget build(BuildContext context) {
    final top5 = List.of(posts)..sort((a, b) => b.likes.compareTo(a.likes));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ── Topics Grid ──
        const _SectionHeader(icon: LucideIcons.compass, title: 'Explore Topics'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: _topics.map((t) {
            final (emoji, label, count, color) = t;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$count posts',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ).animate().fadeIn(delay: 60.ms),

        const SizedBox(height: 24),

        // ── Most Supported ──
        const _SectionHeader(icon: LucideIcons.trendingUp, title: 'Most Supported'),
        const SizedBox(height: 12),

        ...top5.take(5).asMap().entries.map((e) {
          final post = e.value;
          final tagColor = _PostCard._tagColors[post.tag] ?? AppColors.primary;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(post.emoji,
                          style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    post.content,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Icon(LucideIcons.heartHandshake,
                        size: 16, color: tagColor),
                    const SizedBox(height: 2),
                    Text(
                      '${post.likes}',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tagColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: (100 + e.key * 50).ms);
        }),

        const SizedBox(height: 24),

        // ── Peer Support CTA ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withOpacity(0.15),
                AppColors.secondary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.users,
                        size: 22, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peer Support Network',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Connect 1-on-1 with a trained peer',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.messageCircle, size: 16),
                  label: const Text(
                    'Request a Peer Chat',
                    style:
                        TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }
}

// ─── My Posts Tab ─────────────────────────────────────────

class _MyPostsTab extends StatefulWidget {
  final List<_Post> myPosts;
  final List<_Post> bookmarkedPosts;
  final ValueChanged<int> onBookmark;
  final VoidCallback onNewPost;

  const _MyPostsTab({
    required this.myPosts,
    required this.bookmarkedPosts,
    required this.onBookmark,
    required this.onNewPost,
  });

  @override
  State<_MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends State<_MyPostsTab> {
  bool _showSaved = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ── Toggle: My Posts / Saved ──
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _ToggleBtn(
                label: 'My Posts',
                icon: LucideIcons.user,
                isActive: !_showSaved,
                onTap: () => setState(() => _showSaved = false),
              ),
              _ToggleBtn(
                label: 'Saved',
                icon: LucideIcons.bookmark,
                isActive: _showSaved,
                onTap: () => setState(() => _showSaved = true),
                badge: widget.bookmarkedPosts.length,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (!_showSaved) ...[
          if (widget.myPosts.isEmpty)
            _EmptySection(
              icon: LucideIcons.messageSquare,
              title: "You haven't posted yet",
              subtitle: 'Share your story — you might help\nsomeone who really needs it.',
              buttonLabel: 'Write your first post',
              onTap: widget.onNewPost,
            )
          else
            ...widget.myPosts.map((post) => _MiniPostCard(
                  post: post,
                  onBookmark: () => widget.onBookmark(post.id),
                )),
        ] else ...[
          if (widget.bookmarkedPosts.isEmpty)
            _EmptySection(
              icon: LucideIcons.bookmark,
              title: 'No saved posts yet',
              subtitle:
                  'Bookmark posts you want to revisit\nby tapping the bookmark icon.',
              buttonLabel: 'Browse the feed',
              onTap: () {},
            )
          else ...[
            Text(
              '${widget.bookmarkedPosts.length} saved posts',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.bookmarkedPosts.map((post) => _MiniPostCard(
                  post: post,
                  onBookmark: () => widget.onBookmark(post.id),
                  showBookmarkActive: true,
                )),
          ],
        ],
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────

class _SafeBanner extends StatelessWidget {
  const _SafeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.shieldCheck,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safe & Anonymous Space',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  'All posts are moderated. Be kind and supportive.',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPostsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NewPostsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.arrowUp, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              '$count new ${count == 1 ? 'post' : 'posts'} — tap to refresh',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrisisCTA extends StatelessWidget {
  const _CrisisCTA();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.heartHandshake,
                size: 22, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re not alone',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  'Professional support is available 24/7. Talk to a counselor now.',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Get Help',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFilter extends StatelessWidget {
  final List<String> tags;
  final String active;
  final ValueChanged<String> onChanged;

  const _TagFilter({required this.tags, required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tag = tags[i];
          final isActive = active == tag;
          return GestureDetector(
            onTap: () => onChanged(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final _SortMode current;
  final ValueChanged<_SortMode> onChanged;

  const _SortButton({required this.current, required this.onChanged});

  String get _label => switch (current) {
        _SortMode.recent => 'Recent',
        _SortMode.popular => 'Popular',
        _SortMode.unanswered => 'Unanswered',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort Posts',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ..._SortMode.values.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      switch (m) {
                        _SortMode.recent => 'Most Recent',
                        _SortMode.popular => 'Most Supported',
                        _SortMode.unanswered => 'Needs Response',
                      },
                      style: const TextStyle(
                          fontFamily: 'Nunito', fontWeight: FontWeight.w600),
                    ),
                    trailing: current == m
                        ? const Icon(LucideIcons.check,
                            color: AppColors.primary, size: 18)
                        : null,
                    onTap: () {
                      onChanged(m);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.arrowUpDown,
                size: 12, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              _label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingTopics extends StatelessWidget {
  const _TrendingTopics();

  static const _topics = [
    ('😰', 'Exam Stress', '234'),
    ('💤', 'Sleep Help', '189'),
    ('💪', 'Recovery', '156'),
    ('🤝', 'Loneliness', '143'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.trendingUp, size: 14, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text(
                'TRENDING THIS WEEK',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _topics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final (emoji, label, count) = _topics[i];
                return Container(
                  width: 110,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.shadowCard,
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(label,
                          style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('$count posts',
                          style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Post Card ────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final _Post post;
  final bool isCommentsExpanded;
  final VoidCallback onSupport;
  final VoidCallback onBookmark;
  final ValueChanged<int> onReaction;
  final VoidCallback onToggleComments;

  static const _tagColors = {
    'Academic': Color(0xFF6366F1),
    'Recovery': Color(0xFF10B981),
    'Loneliness': Color(0xFF0EA5E9),
    'Anxiety': Color(0xFFFF8C42),
    'Inspiration': Color(0xFFF59E0B),
    'Wellness': Color(0xFF00BEB4),
    'General': Color(0xFF9CA3AF),
    'Relationships': Color(0xFFFF6B6B),
  };

  static const _reactions = ['❤️', '💙', '💪', '🫂'];
  static const _reactionLabels = ['Love', 'Relate', 'Strong', 'Hug'];

  const _PostCard({
    required this.post,
    required this.isCommentsExpanded,
    required this.onSupport,
    required this.onBookmark,
    required this.onReaction,
    required this.onToggleComments,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = _tagColors[post.tag] ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top accent strip ──
          Container(height: 3, color: tagColor),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          post.isAnonymous ? '🎭' : '👤',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.isAnonymous ? 'Anonymous' : 'Student',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            post.timeAgo,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tag badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: tagColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        post.tag,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tagColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bookmark
                    GestureDetector(
                      onTap: onBookmark,
                      child: Icon(
                        post.isBookmarked
                            ? LucideIcons.bookmarkCheck
                            : LucideIcons.bookmark,
                        size: 18,
                        color: post.isBookmarked
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Content ──
                Text(
                  '${post.emoji}  ${post.content}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.65,
                  ),
                ),

                const SizedBox(height: 14),

                // ── Reactions Row ──
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _reactions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final count = post.reactions[i] ?? 0;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onReaction(i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: count > 0
                                ? tagColor.withOpacity(0.10)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: count > 0
                                  ? tagColor.withOpacity(0.3)
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_reactions[i],
                                  style: const TextStyle(fontSize: 13)),
                              if (count > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: tagColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ── Action Row ──
                Row(
                  children: [
                    // Support
                    GestureDetector(
                      onTap: onSupport,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: post.isSupported
                              ? AppColors.secondaryContainer
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: post.isSupported
                                ? AppColors.secondary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              post.isSupported
                                  ? LucideIcons.heartHandshake
                                  : LucideIcons.heart,
                              color: post.isSupported
                                  ? AppColors.secondary
                                  : AppColors.textMuted,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              post.isSupported
                                  ? 'Supported · ${post.likes}'
                                  : 'Support · ${post.likes}',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: post.isSupported
                                    ? AppColors.secondary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Comments
                    GestureDetector(
                      onTap: onToggleComments,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isCommentsExpanded
                              ? AppColors.primaryContainer
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isCommentsExpanded
                                ? AppColors.primary.withOpacity(0.3)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.messageCircle,
                                color: isCommentsExpanded
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                size: 15),
                            const SizedBox(width: 5),
                            Text(
                              '${post.comments}',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isCommentsExpanded
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.flag,
                            color: AppColors.textMuted, size: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comments Panel ───────────────────────────────────────

class _CommentsPanel extends StatelessWidget {
  final List<String> comments;
  const _CommentsPanel({required this.comments});

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No replies yet. Be the first to respond.',
          style: TextStyle(
              fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...comments.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: e.key < comments.length - 1 ? 12 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                          child: Text('👤', style: TextStyle(fontSize: 13))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 10),
          // Reply input stub
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add a supportive reply...',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: AppColors.textMuted),
                  ),
                ),
                const Icon(LucideIcons.send, size: 16, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini Post Card (My Posts / Saved) ────────────────────

class _MiniPostCard extends StatelessWidget {
  final _Post post;
  final VoidCallback onBookmark;
  final bool showBookmarkActive;

  const _MiniPostCard({
    required this.post,
    required this.onBookmark,
    this.showBookmarkActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = _PostCard._tagColors[post.tag] ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: tagColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        post.tag,
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: tagColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      post.timeAgo,
                      style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(LucideIcons.heart,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text('${post.likes}',
                            style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onBookmark,
            child: Icon(
              showBookmarkActive || post.isBookmarked
                  ? LucideIcons.bookmarkCheck
                  : LucideIcons.bookmark,
              size: 18,
              color: post.isBookmarked ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Section ────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _EmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle Button ────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final int badge;

  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: AppColors.shadowCard,
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isActive ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── New Post Sheet ───────────────────────────────────────

class _NewPostSheet extends StatefulWidget {
  final void Function(String content, String tag, bool isAnon) onSubmit;
  const _NewPostSheet({required this.onSubmit});

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isAnonymous = true;
  String _selectedTag = 'General';

  static const List<String> _tags = [
    'General', 'Academic', 'Loneliness', 'Anxiety',
    'Recovery', 'Inspiration', 'Relationships', 'Wellness',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.users, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share with Community',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Your peers understand. You are safe here.',
                    style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Anonymous toggle
          GestureDetector(
            onTap: () => setState(() => _isAnonymous = !_isAnonymous),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isAnonymous
                    ? AppColors.primaryContainer
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isAnonymous ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Text(_isAnonymous ? '🎭' : '👤',
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAnonymous ? 'Posting anonymously' : 'Posting as Student',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _isAnonymous
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _isAnonymous
                              ? 'Your identity is hidden'
                              : 'Your name will be visible',
                          style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isAnonymous ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18,
                    color: _isAnonymous ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Tag selector
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tags.length,
              itemBuilder: (_, i) {
                final tag = _tags[i];
                final isSelected = _selectedTag == tag;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTag = tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          isSelected ? null : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            maxLength: 500,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText:
                  "Share what's on your mind. Your story might help someone else...",
              hintStyle: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 14, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              counterStyle: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                final content = _ctrl.text.trim();
                if (content.isEmpty) return;
                widget.onSubmit(content, _selectedTag, _isAnonymous);
                Navigator.pop(context);
              },
              icon: const Icon(LucideIcons.send, size: 16),
              label: const Text(
                'Post to Community',
                style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
