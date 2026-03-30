import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/resource_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/resources_provider.dart';

// ─── Main Screen ──────────────────────────────────────────

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(resourcesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildAppBar(asyncState.value)],
        body: asyncState.when(
          loading: () => const _LoadingState(),
          error: (e, _) => _ErrorState(onRetry: () => ref.refresh(resourcesProvider)),
          data: (state) => Column(children: [
            if (_showSearch) _SearchBar(ctrl: _searchCtrl),
            Expanded(child: TabBarView(
              controller: _tabs,
              children: [
                _ForYouTab(state: state),
                _LibraryTab(state: state),
                _SavedTab(state: state),
                _ToolsTab(state: state),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(ResourcesState? state) {
    final completed = state?.completedIds.length ?? 0;
    final total = kResources.length;
    final xp = state?.totalXp ?? 0;
    final user = ref.watch(currentUserProvider);
    final firstName = user?.displayName.split(' ').first ?? 'there';

    return SliverAppBar(
      expandedHeight: 152,
      pinned: true,
      backgroundColor: const Color(0xFF006B64),
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(_showSearch ? LucideIcons.x : LucideIcons.search, size: 20, color: Colors.white),
          onPressed: () {
            setState(() => _showSearch = !_showSearch);
            if (!_showSearch) {
              _searchCtrl.clear();
              ref.read(resourcesProvider.notifier).setSearch('');
            }
          },
        ),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw, size: 20, color: Colors.white),
          onPressed: () => ref.refresh(resourcesProvider),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF004D47), Color(0xFF00BEB4), Color(0xFF0EA5E9)],
            ),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20,
            top: MediaQuery.of(context).padding.top + 52,
            bottom: 14,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Hi $firstName 👋', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white70)),
              const Text('Resources & Tools', style: TextStyle(fontFamily: 'Nunito', fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              Row(children: [
                _HeaderPill(icon: LucideIcons.bookOpen, label: '$completed/$total read'),
                const SizedBox(width: 8),
                _HeaderPill(icon: LucideIcons.zap, label: '$xp XP'),
                if (completed > 0) ...[
                  const SizedBox(width: 8),
                  _HeaderPill(icon: LucideIcons.flame, label: '${(completed / total * 100).round()}% done'),
                ],
              ]),
            ])),
            if (completed > 0)
              _MiniProgressRing(value: total == 0 ? 0 : completed / total),
          ]),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 12),
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [Tab(text: '✨ For You'), Tab(text: '📚 Library'), Tab(text: '🔖 Saved'), Tab(text: '🛠 Tools')],
          ),
        ),
      ),
    );
  }
}

// ─── Header Widgets ───────────────────────────────────────

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white70),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _MiniProgressRing extends StatelessWidget {
  final double value;
  const _MiniProgressRing({required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52, height: 52,
    child: Stack(alignment: Alignment.center, children: [
      CircularProgressIndicator(value: value, strokeWidth: 4,
        backgroundColor: Colors.white.withOpacity(0.2),
        valueColor: const AlwaysStoppedAnimation(Colors.white)),
      Text('${(value * 100).round()}%', style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
    ]),
  );
}

// ─── Search Bar ───────────────────────────────────────────

class _SearchBar extends ConsumerWidget {
  final TextEditingController ctrl;
  const _SearchBar({required this.ctrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: TextField(
      controller: ctrl, autofocus: true,
      cursorColor: AppColors.primary,
      style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search articles, exercises, topics...',
        hintStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.textMuted),
        prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
        filled: true, fillColor: const Color(0xFFF0F4F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: (q) => ref.read(resourcesProvider.notifier).setSearch(q),
    ),
  );
}

// ─────────────────────────────────────────────────────────
// FOR YOU TAB
// ─────────────────────────────────────────────────────────

class _ForYouTab extends ConsumerWidget {
  final ResourcesState state;
  const _ForYouTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodState = ref.watch(moodProvider);
    final personalized = ref.watch(personalizedResourcesProvider);
    final todayMood = moodState.todayEntry?.moodScore;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.refresh(resourcesProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          // Crisis strip
          _CrisisStrip(state: state),
          const SizedBox(height: 14),

          // Mood context card
          if (todayMood != null) _MoodContextCard(mood: todayMood, emotions: moodState.todayEntry?.emotions ?? []),
          if (todayMood == null) _LogMoodNudge(),
          const SizedBox(height: 16),

          // Daily challenge
          _DailyChallenge(state: state),
          const SizedBox(height: 18),

          // Quick tools row
          _QuickToolsRow(state: state),
          const SizedBox(height: 18),

          // Featured carousel
          const _SectionHeader(title: 'Featured', subtitle: 'Editor\'s picks'),
          const SizedBox(height: 10),
          _FeaturedCarousel(state: state),
          const SizedBox(height: 20),

          // Personalized picks
          _SectionHeader(
            title: 'Recommended for You',
            subtitle: todayMood != null ? 'Based on your mood & goals today' : 'Popular with your peers',
          ),
          const SizedBox(height: 10),
          ...personalized.take(6).map((r) => ResourceCard(resource: r, state: state, siblings: personalized)),
        ],
      ),
    );
  }
}

class _MoodContextCard extends StatelessWidget {
  final int mood;
  final List<String> emotions;
  const _MoodContextCard({required this.mood, required this.emotions});

  Color get _moodColor {
    if (mood >= 8) return const Color(0xFF10B981);
    if (mood >= 6) return AppColors.primary;
    if (mood >= 4) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _moodLabel {
    if (mood >= 8) return 'Thriving';
    if (mood >= 6) return 'Good';
    if (mood >= 4) return 'Okay';
    if (mood >= 2) return 'Struggling';
    return 'Difficult';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _moodColor.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _moodColor.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _moodColor.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(LucideIcons.heartPulse, size: 16, color: _moodColor),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mood today: $_moodLabel ($mood/10)',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: _moodColor)),
        if (emotions.isNotEmpty)
          Text('Feeling: ${emotions.take(3).join(', ')}',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Text('Picks updated ✓', style: TextStyle(fontFamily: 'Nunito', fontSize: 10, color: _moodColor, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _LogMoodNudge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
    ),
    child: const Row(children: [
      Icon(LucideIcons.sunMedium, size: 18, color: AppColors.primary),
      SizedBox(width: 10),
      Expanded(child: Text('Log your mood to get personalised resource picks for today',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.textSecondary))),
    ]),
  );
}

class _DailyChallenge extends ConsumerWidget {
  final ResourcesState state;
  const _DailyChallenge({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Daily challenge: always box breathing (quick, universally useful)
    final challenge = kResources.firstWhere((r) => r.id == 'box_breathing');
    final done = state.completedIds.contains(challenge.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: done
            ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06D6A0)])
            : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: (done ? const Color(0xFF10B981) : const Color(0xFF8B5CF6)).withOpacity(0.3),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(challenge.emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
            child: const Text('TODAY\'S CHALLENGE', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
          ),
          const SizedBox(height: 4),
          Text(done ? '✅ Challenge Complete!' : challenge.title,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(done ? 'Great work today 🎉' : challenge.readTime,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Colors.white70)),
        ])),
        if (!done)
          GestureDetector(
            onTap: () => Navigator.push(context, _slideRoute(ExercisePage(resource: challenge, siblings: [challenge]))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.4))),
              child: const Text('Start', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
      ]),
    );
  }
}

class _QuickToolsRow extends ConsumerWidget {
  final ResourcesState state;
  const _QuickToolsRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = kResources.where((r) => r.type == 'exercise').take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader(title: 'Quick Tools', subtitle: 'Do something good right now'),
      const SizedBox(height: 10),
      SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 4),
          itemCount: exercises.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final r = exercises[i];
            final done = state.completedIds.contains(r.id);
            final color = Color(r.colorValue);
            return GestureDetector(
              onTap: () => Navigator.push(context, _slideRoute(ExercisePage(resource: r, siblings: exercises))),
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: done ? color.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: done ? color.withOpacity(0.3) : const Color(0xFFE2E8F0)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Text(r.emoji, style: const TextStyle(fontSize: 20)),
                    const Spacer(),
                    if (done) Icon(LucideIcons.circleCheckBig, size: 14, color: color),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(r.readTime, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.textMuted)),
                  ]),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
// LIBRARY TAB
// ─────────────────────────────────────────────────────────

class _LibraryTab extends ConsumerStatefulWidget {
  final ResourcesState state;
  const _LibraryTab({required this.state});

  @override
  ConsumerState<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<_LibraryTab> {
  String _typeFilter = 'All'; // All | Articles | Exercises | Guides

  List<ResourceItem> get _filtered {
    var list = widget.state.filteredResources;
    if (_typeFilter == 'Articles') list = list.where((r) => r.type == 'article').toList();
    if (_typeFilter == 'Exercises') list = list.where((r) => r.type == 'exercise').toList();
    if (_typeFilter == 'Guides') list = list.where((r) => r.type == 'guide').toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Column(children: [
      // Category chips
      _CategoryChips(state: widget.state),
      // Type filter row
      Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(children: [
          const Icon(LucideIcons.slidersHorizontal, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          ...['All', 'Articles', 'Exercises', 'Guides'].map((t) => GestureDetector(
            onTap: () => setState(() => _typeFilter = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _typeFilter == t ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _typeFilter == t ? AppColors.primary : const Color(0xFFE2E8F0)),
              ),
              child: Text(t, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: _typeFilter == t ? Colors.white : AppColors.textSecondary)),
            ),
          )),
          const Spacer(),
          Text('${list.length} result${list.length == 1 ? '' : 's'}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.textMuted)),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? _EmptyState(searchActive: widget.state.searchQuery.isNotEmpty)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                itemCount: list.length,
                itemBuilder: (_, i) => ResourceCard(resource: list[i], state: widget.state, siblings: list),
              ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
// SAVED TAB
// ─────────────────────────────────────────────────────────

class _SavedTab extends ConsumerWidget {
  final ResourcesState state;
  const _SavedTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = state.bookmarkedResources;
    if (saved.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.bookmark, size: 52, color: AppColors.textMuted),
      SizedBox(height: 12),
      Text('No saved resources yet', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
      SizedBox(height: 6),
      Text('Tap the bookmark icon on any resource', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted)),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: saved.length,
      itemBuilder: (_, i) => ResourceCard(resource: saved[i], state: state, siblings: saved),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TOOLS TAB
// ─────────────────────────────────────────────────────────

class _ToolsTab extends ConsumerWidget {
  final ResourcesState state;
  const _ToolsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = state.exerciseResources;
    final crisis = state.crisisResource;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        const _SectionHeader(title: 'Interactive Exercises', subtitle: 'Guided tools you can do right now'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95,
          ),
          itemCount: exercises.length,
          itemBuilder: (_, i) => _ExerciseTile(resource: exercises[i], state: state, siblings: exercises),
        ),
        const SizedBox(height: 20),
        if (crisis != null) ...[
          const _SectionHeader(title: 'Crisis Support', subtitle: 'Immediate help when you need it'),
          const SizedBox(height: 10),
          _CrisisTile(resource: crisis),
        ],
      ],
    );
  }
}

// ─── Category Chips ───────────────────────────────────────

class _CategoryChips extends ConsumerWidget {
  final ResourcesState state;
  const _CategoryChips({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    color: Colors.white,
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: kCategories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final cat = kCategories[i];
        final active = state.selectedCategory == cat;
        final meta = kCategoryMeta[cat];
        final color = meta != null ? Color(meta.colorValue) : AppColors.primary;
        return GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); ref.read(resourcesProvider.notifier).setCategory(cat); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: active ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? color : const Color(0xFFE2E8F0)),
            ),
            child: Text('${meta?.emoji ?? ''} $cat',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
          ),
        );
      },
    ),
  );
}

// ─── Section Header ───────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    Text(subtitle, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.textMuted)),
  ]);
}

// ─── Featured Carousel ────────────────────────────────────

class _FeaturedCarousel extends ConsumerWidget {
  final ResourcesState state;
  const _FeaturedCarousel({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = state.featuredResources;
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 4),
        itemCount: featured.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _FeaturedCard(resource: featured[i], state: state, siblings: featured),
      ),
    );
  }
}

class _FeaturedCard extends ConsumerWidget {
  final ResourceItem resource;
  final ResourcesState state;
  final List<ResourceItem> siblings;
  const _FeaturedCard({required this.resource, required this.state, required this.siblings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(resource.colorValue);
    final isCompleted = state.completedIds.contains(resource.id);
    final isBookmarked = state.bookmarkedIds.contains(resource.id);

    return GestureDetector(
      onTap: () => _navigate(context, resource, siblings),
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, color.withOpacity(0.72)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Stack(children: [
          Positioned(right: -15, top: -15, child: Opacity(opacity: 0.12, child: Text(resource.emoji, style: const TextStyle(fontSize: 90)))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _SmallTypeBadge(type: resource.type),
                const Spacer(),
                GestureDetector(
                  onTap: () { HapticFeedback.lightImpact(); ref.read(resourcesProvider.notifier).toggleBookmark(resource.id); },
                  child: Icon(isCompleted ? LucideIcons.circleCheckBig : (isBookmarked ? LucideIcons.bookmarkCheck : LucideIcons.bookmark), size: 17, color: Colors.white.withOpacity(0.85)),
                ),
              ]),
              const Spacer(),
              Text(resource.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              Text(resource.title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3), maxLines: 2),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(LucideIcons.clock, size: 10, color: Colors.white70),
                const SizedBox(width: 4),
                Text(resource.readTime, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: Colors.white70)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(6)),
                  child: Text('+${resource.xp} XP', style: const TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Resource Card (shared across tabs) ──────────────────

class ResourceCard extends ConsumerWidget {
  final ResourceItem resource;
  final ResourcesState state;
  final List<ResourceItem> siblings;
  const ResourceCard({super.key, required this.resource, required this.state, required this.siblings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(resource.colorValue);
    final isCompleted = state.completedIds.contains(resource.id);
    final isBookmarked = state.bookmarkedIds.contains(resource.id);

    return GestureDetector(
      onTap: () => _navigate(context, resource, siblings),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isCompleted ? AppColors.primary.withOpacity(0.22) : const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(resource.emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _TypeBadge(type: resource.type, color: color),
                if (resource.isHot) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(5)),
                    child: const Text('🔥 HOT', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                  ),
                ],
                if (isCompleted) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.check, size: 9, color: AppColors.primary),
                      SizedBox(width: 2),
                      Text('Done', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ]),
                  ),
                ],
              ]),
              const SizedBox(height: 5),
              Text(resource.title, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(resource.description, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 7),
              Row(children: [
                const Icon(LucideIcons.clock, size: 11, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(resource.readTime, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
                  child: Text('+${resource.xp} XP', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: color)),
                ),
                const Spacer(),
                Text(resource.category, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.textMuted)),
              ]),
            ])),
            const SizedBox(width: 8),
            Column(children: [
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); ref.read(resourcesProvider.notifier).toggleBookmark(resource.id); },
                child: Icon(isBookmarked ? LucideIcons.bookmarkCheck : LucideIcons.bookmark, size: 18, color: isBookmarked ? AppColors.primary : AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textMuted),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Exercise Tile ────────────────────────────────────────

class _ExerciseTile extends ConsumerWidget {
  final ResourceItem resource;
  final ResourcesState state;
  final List<ResourceItem> siblings;
  const _ExerciseTile({required this.resource, required this.state, required this.siblings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(resource.colorValue);
    final isCompleted = state.completedIds.contains(resource.id);

    return GestureDetector(
      onTap: () => Navigator.push(context, _slideRoute(ExercisePage(resource: resource, siblings: siblings))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isCompleted ? color.withOpacity(0.3) : const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text(resource.emoji, style: const TextStyle(fontSize: 28)),
              const Spacer(),
              if (isCompleted)
                Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(LucideIcons.check, size: 12, color: color)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(resource.title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 2),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('START →', style: TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                ),
                const Spacer(),
                Text(resource.readTime, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.textMuted)),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CrisisTile extends StatelessWidget {
  final ResourceItem resource;
  const _CrisisTile({required this.resource});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, _slideRoute(ResourceDetailPage(resource: resource, siblings: [resource]))),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        const Text('🆘', style: TextStyle(fontSize: 36)),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Crisis Resources', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          SizedBox(height: 3),
          Text('Kenyan helplines, campus support & immediate steps', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: Colors.white70, height: 1.3)),
        ])),
        const Icon(LucideIcons.chevronRight, color: Colors.white70, size: 20),
      ]),
    ),
  );
}

// ─── Crisis Strip ─────────────────────────────────────────

class _CrisisStrip extends ConsumerWidget {
  final ResourcesState state;
  const _CrisisStrip({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crisis = state.crisisResource;
    return GestureDetector(
      onTap: () {
        if (crisis != null) Navigator.push(context, _slideRoute(ResourceDetailPage(resource: crisis, siblings: [crisis])));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
        ),
        child: const Row(children: [
          Text('🆘', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('In crisis? Get help now', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
            Text('Befrienders Kenya: 0800 723 253 — Free, 24/7', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Color(0xFFEF4444))),
          ])),
          Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFEF4444)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// RESOURCE DETAIL PAGE (full page with navigation)
// ─────────────────────────────────────────────────────────

class ResourceDetailPage extends ConsumerStatefulWidget {
  final ResourceItem resource;
  final List<ResourceItem> siblings;
  const ResourceDetailPage({super.key, required this.resource, required this.siblings});

  @override
  ConsumerState<ResourceDetailPage> createState() => _ResourceDetailPageState();
}

class _ResourceDetailPageState extends ConsumerState<ResourceDetailPage> {
  final ScrollController _scrollCtrl = ScrollController();
  double _readProgress = 0.0;
  bool _autoCompleted = false;
  late ResourceItem _current;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _current = widget.resource;
    _currentIndex = widget.siblings.indexOf(widget.resource);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    final progress = (_scrollCtrl.offset / max).clamp(0.0, 1.0);
    setState(() => _readProgress = progress);

    // Auto-complete at 90% scroll
    if (progress >= 0.9 && !_autoCompleted) {
      final state = ref.read(resourcesProvider).value;
      final alreadyDone = state?.completedIds.contains(_current.id) ?? false;
      if (!alreadyDone) {
        _autoCompleted = true;
        ref.read(resourcesProvider.notifier).markComplete(_current.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Completed! +${_current.xp} XP', style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.siblings.length) return;
    setState(() {
      _current = widget.siblings[index];
      _currentIndex = index;
      _readProgress = 0;
      _autoCompleted = false;
    });
    _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resourcesProvider).value ?? const ResourcesState();
    final color = Color(_current.colorValue);
    final isCompleted = state.completedIds.contains(_current.id);
    final isBookmarked = state.bookmarkedIds.contains(_current.id);
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < widget.siblings.length - 1;

    // If it's an exercise or crisis, delegate
    if (_current.type == 'exercise') {
      return ExercisePage(resource: _current, siblings: widget.siblings);
    }
    if (_current.type == 'crisis') {
      return _CrisisDetailPage(resource: _current);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        // Read progress bar
        LinearProgressIndicator(
          value: _readProgress,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 3,
        ),

        Expanded(child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // App bar
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(_current.category, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(isBookmarked ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                    size: 20, color: isBookmarked ? AppColors.primary : AppColors.textSecondary),
                  onPressed: () { HapticFeedback.lightImpact(); ref.read(resourcesProvider.notifier).toggleBookmark(_current.id); },
                ),
                if (hasPrev || hasNext)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(child: Text('${_currentIndex + 1}/${widget.siblings.length}',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.textMuted))),
                  ),
              ],
            ),

            SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Hero header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _TypeBadge(type: _current.type, color: color),
                    if (_current.isHot) ...[
                      const SizedBox(width: 6),
                      const _HotBadge(),
                    ],
                    if (isCompleted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(LucideIcons.check, size: 10, color: AppColors.primary),
                          SizedBox(width: 3),
                          Text('Completed', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  // Large emoji
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
                    child: Center(child: Text(_current.emoji, style: const TextStyle(fontSize: 32))),
                  ),
                  const SizedBox(height: 12),
                  Text(_current.title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2)),
                  const SizedBox(height: 6),
                  Text(_current.subtitle, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(LucideIcons.clock, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(_current.readTime, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('+${_current.xp} XP', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(8)),
                      child: Text(_current.category, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                  ]),
                  // Read progress pill
                  if (_readProgress > 0.05) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(LucideIcons.bookOpenText, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: _readProgress, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(color), minHeight: 4),
                      )),
                      const SizedBox(width: 6),
                      Text('${(_readProgress * 100).round()}%', style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    ]),
                  ],
                ]),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ..._current.sections.map((s) => _ContentBlock(section: s)),
                ]),
              ),

              // Rating (if completed)
              if (isCompleted) ...[
                const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 0), child: Divider()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Was this helpful?', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _RatingBtn(label: '👍 Yes, helpful', positive: true, resource: _current),
                      const SizedBox(width: 10),
                      _RatingBtn(label: '👎 Not for me', positive: false, resource: _current),
                    ]),
                  ]),
                ),
              ],

              // Related resources
              _RelatedResources(current: _current, state: state),

              const SizedBox(height: 120),
            ])),
          ],
        )),

        // Bottom navigation bar
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
          child: Row(children: [
            // Prev
            if (hasPrev)
              _NavArrow(
                icon: LucideIcons.arrowLeft,
                label: 'Prev',
                onTap: () => _goTo(_currentIndex - 1),
              )
            else
              const SizedBox(width: 72),

            // Complete / completed
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton(
                onPressed: isCompleted ? null : () {
                  ref.read(resourcesProvider.notifier).markComplete(_current.id);
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('✅ +${_current.xp} XP earned!', style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                    backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? AppColors.primary.withOpacity(0.4) : AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isCompleted ? '✅ Completed' : 'Mark Complete (+${_current.xp} XP)',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            )),

            // Next
            if (hasNext)
              _NavArrow(
                icon: LucideIcons.arrowRight,
                label: 'Next',
                onTap: () => _goTo(_currentIndex + 1),
              )
            else
              const SizedBox(width: 72),
          ]),
        ),
      ]),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ]),
    ),
  );
}

class _RelatedResources extends ConsumerWidget {
  final ResourceItem current;
  final ResourcesState state;
  const _RelatedResources({required this.current, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = kResources
        .where((r) => r.id != current.id && r.category == current.category)
        .take(3)
        .toList();
    if (related.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(title: 'Related Resources', subtitle: 'You might find these helpful too'),
        const SizedBox(height: 12),
        ...related.map((r) => ResourceCard(resource: r, state: state, siblings: related)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
// EXERCISE PAGE (full-screen, step-by-step)
// ─────────────────────────────────────────────────────────

class ExercisePage extends ConsumerStatefulWidget {
  final ResourceItem resource;
  final List<ResourceItem> siblings;
  const ExercisePage({super.key, required this.resource, required this.siblings});

  @override
  ConsumerState<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends ConsumerState<ExercisePage> with TickerProviderStateMixin {
  int _step = 0;
  bool _done = false;
  Timer? _timer;
  int _remaining = 0;
  bool _timerRunning = false;

  // Breathing animation
  late AnimationController _breathCtrl;
  late Animation<double> _breathScale;

  List<ExerciseStep> get steps => widget.resource.steps ?? [];
  bool get _isBoxBreathing => widget.resource.id == 'box_breathing';

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _breathScale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathCtrl.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() { _remaining = seconds; _timerRunning = true; });

    // Animate breathing circle for box breathing
    if (_isBoxBreathing) {
      _breathCtrl.duration = Duration(seconds: seconds);
      final title = steps[_step].title.toLowerCase();
      if (title.contains('inhale')) {
        _breathCtrl.forward(from: 0);
      } else if (title.contains('exhale')) {
        _breathCtrl.reverse(from: 1);
      } else {
        _breathCtrl.stop();
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_remaining > 0) { _remaining--; }
        else { t.cancel(); _timerRunning = false; }
      });
    });
  }

  void _next() {
    _timer?.cancel();
    _breathCtrl.stop();
    setState(() => _timerRunning = false);

    if (_step < steps.length - 1) {
      setState(() { _step++; _remaining = 0; });
      final dur = steps[_step].durationSeconds;
      if (dur != null) _startTimer(dur);
    } else {
      setState(() => _done = true);
      ref.read(resourcesProvider.notifier).markComplete(widget.resource.id, helpful: true);
      HapticFeedback.mediumImpact();
    }
  }

  void _prev() {
    _timer?.cancel();
    _breathCtrl.stop();
    setState(() { _timerRunning = false; if (_step > 0) { _step--; _remaining = 0; } });
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.resource.colorValue);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.resource.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(widget.resource.title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _done ? const SizedBox() : LinearProgressIndicator(
            value: (_step + 1) / steps.length,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ),
      body: _done
          ? _CompletionView(resource: widget.resource, color: color)
          : Column(children: [
              // Step dots
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(steps.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _step ? 22 : 7, height: 7,
                  decoration: BoxDecoration(
                    color: i < _step ? color : (i == _step ? color : color.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ))),
              ),

              // Main step content
              Expanded(child: Center(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                child: Column(children: [
                  // Step indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('Step ${_step + 1} of ${steps.length}',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ),
                  const SizedBox(height: 28),

                  // Visual: animated circle for breathing, or large step number
                  if (steps[_step].durationSeconds != null) ...[
                    _isBoxBreathing
                        ? _BreathingCircle(scale: _breathScale, color: color, remaining: _remaining, totalSecs: steps[_step].durationSeconds!, running: _timerRunning, onTap: () { if (!_timerRunning) _startTimer(steps[_step].durationSeconds!); })
                        : _CountdownCircle(remaining: _remaining, total: steps[_step].durationSeconds!, color: color, running: _timerRunning, onTap: () { if (!_timerRunning) _startTimer(steps[_step].durationSeconds!); }),
                    const SizedBox(height: 28),
                  ] else ...[
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                      child: Center(child: Text('${_step + 1}', style: TextStyle(fontFamily: 'Nunito', fontSize: 36, fontWeight: FontWeight.w900, color: color))),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Title
                  Text(steps[_step].title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary), textAlign: TextAlign.center),
                  const SizedBox(height: 14),

                  // Instruction
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Text(steps[_step].instruction, style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.textSecondary, height: 1.7), textAlign: TextAlign.center),
                  ),
                ]),
              ))),

              // Navigation
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
                child: Row(children: [
                  if (_step > 0)
                    Expanded(child: OutlinedButton(
                      onPressed: _prev,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('← Back', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                    ))
                  else
                    const SizedBox(width: 0),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _step > 0 ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: (steps[_step].durationSeconds != null && _timerRunning) ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        disabledBackgroundColor: color.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _step < steps.length - 1 ? 'Continue →' : '✅ Finish',
                        style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
    );
  }
}

// ─── Breathing Circle (animated for box breathing) ────────

class _BreathingCircle extends StatelessWidget {
  final Animation<double> scale;
  final Color color;
  final int remaining;
  final int totalSecs;
  final bool running;
  final VoidCallback onTap;
  const _BreathingCircle({required this.scale, required this.color, required this.remaining, required this.totalSecs, required this.running, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 200, height: 200,
      child: AnimatedBuilder(
        animation: scale,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          // Outer glow ring
          Transform.scale(scale: 0.9 + scale.value * 0.2,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.08)),
            )),
          // Main circle
          Transform.scale(scale: 0.6 + scale.value * 0.4,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [color.withOpacity(0.9), color.withOpacity(0.6)]),
                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 24, spreadRadius: 4)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(running ? '$remaining' : (scale.value > 0.5 ? '●' : '○'),
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                if (running && remaining > 0)
                  const Text('seconds', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: Colors.white70)),
                if (!running)
                  const Text('tap to start', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Colors.white70)),
              ]),
            )),
        ]),
      ),
    ),
  );
}

class _CountdownCircle extends StatelessWidget {
  final int remaining;
  final int total;
  final Color color;
  final bool running;
  final VoidCallback onTap;
  const _CountdownCircle({required this.remaining, required this.total, required this.color, required this.running, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 140, height: 140,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: running ? remaining / total : (remaining == 0 && total > 0 ? 1.0 : 0.0),
          strokeWidth: 6,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation(color),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(running ? '$remaining' : (remaining == 0 ? '✓' : '▶'),
            style: TextStyle(fontFamily: 'Nunito', fontSize: 36, fontWeight: FontWeight.w800, color: color)),
          Text(running ? 'secs' : (remaining == 0 ? 'done' : 'tap'),
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: color.withOpacity(0.7))),
        ]),
      ]),
    ),
  );
}

class _CompletionView extends StatelessWidget {
  final ResourceItem resource;
  final Color color;
  const _CompletionView({required this.resource, required this.color});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🎉', style: TextStyle(fontSize: 72)),
      const SizedBox(height: 16),
      const Text('Exercise Complete!', style: TextStyle(fontFamily: 'Nunito', fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      Text(resource.title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.zap, size: 22, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Text('+${resource.xp} XP earned', style: const TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
      ),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Done', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800)),
      )),
    ]),
  ));
}

// ─────────────────────────────────────────────────────────
// CRISIS DETAIL PAGE
// ─────────────────────────────────────────────────────────

class _CrisisDetailPage extends StatelessWidget {
  final ResourceItem resource;
  const _CrisisDetailPage({required this.resource});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Crisis Support', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🆘', style: TextStyle(fontSize: 36)),
            SizedBox(height: 10),
            Text('You Are Not Alone', style: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            SizedBox(height: 6),
            Text('If you are in crisis right now, please reach out immediately. Crisis is a temporary state, even when it doesn\'t feel like it.',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white70, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 20),
        ...resource.sections.map((s) => _ContentBlock(section: s)),
        const SizedBox(height: 8),
        const Text('Kenyan Helplines', style: TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        if (resource.hotlines != null)
          ...resource.hotlines!.map((h) => _HotlineCard(hotline: h)),
      ],
    ),
  );
}

class _HotlineCard extends StatelessWidget {
  final Hotline hotline;
  const _HotlineCard({required this.hotline});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle),
        child: const Center(child: Icon(LucideIcons.phone, size: 18, color: Color(0xFFEF4444))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hotline.name, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(hotline.number, style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFEF4444))),
        Row(children: [
          const Icon(LucideIcons.clock, size: 10, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(hotline.hours, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.textMuted)),
        ]),
        if (hotline.note != null)
          Text(hotline.note!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.textSecondary)),
      ])),
    ]),
  );
}

// ─────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────

class _ContentBlock extends StatelessWidget {
  final ContentSection section;
  const _ContentBlock({required this.section});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (section.heading != null) ...[
        Text(section.heading!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
      ],
      Text(section.body, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.textSecondary, height: 1.7)),
    ]),
  );
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final Color color;
  const _TypeBadge({required this.type, required this.color});

  IconData get _icon => switch (type) {
    'exercise' => LucideIcons.dumbbell, 'guide' => LucideIcons.map, 'crisis' => LucideIcons.triangleAlert, _ => LucideIcons.fileText,
  };
  String get _label => switch (type) {
    'exercise' => 'EXERCISE', 'guide' => 'GUIDE', 'crisis' => 'CRISIS', _ => 'ARTICLE',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_icon, size: 9, color: color),
      const SizedBox(width: 3),
      Text(_label, style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
    ]),
  );
}

class _SmallTypeBadge extends StatelessWidget {
  final String type;
  const _SmallTypeBadge({required this.type});

  String get _label => switch (type) {
    'exercise' => 'EXERCISE', 'guide' => 'GUIDE', 'crisis' => 'CRISIS', _ => 'ARTICLE',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
    child: Text(_label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
  );
}

class _HotBadge extends StatelessWidget {
  const _HotBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(5)),
    child: const Text('🔥 HOT', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
  );
}

class _RatingBtn extends ConsumerWidget {
  final String label;
  final bool positive;
  final ResourceItem resource;
  const _RatingBtn({required this.label, required this.positive, required this.resource});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resourcesProvider).value;
    final rated = state?.ratings[resource.id];
    final isActive = rated == positive;

    return Expanded(child: GestureDetector(
      onTap: () => ref.read(resourcesProvider.notifier).markComplete(resource.id, helpful: positive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? AppColors.primary.withOpacity(0.4) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? AppColors.primary : AppColors.textSecondary)),
      ),
    ));
  }
}

// ─── Navigation helpers ───────────────────────────────────

void _navigate(BuildContext context, ResourceItem resource, List<ResourceItem> siblings) {
  if (resource.type == 'exercise') {
    Navigator.push(context, _slideRoute(ExercisePage(resource: resource, siblings: siblings)));
  } else {
    Navigator.push(context, _slideRoute(ResourceDetailPage(resource: resource, siblings: siblings)));
  }
}

PageRoute _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 320),
);

// ─── Empty / Loading / Error ──────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool searchActive;
  const _EmptyState({this.searchActive = false});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(searchActive ? LucideIcons.searchX : LucideIcons.bookOpen, size: 52, color: AppColors.textMuted.withOpacity(0.35)),
      const SizedBox(height: 14),
      Text(searchActive ? 'No resources match your search' : 'No resources in this category',
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
      const SizedBox(height: 6),
      Text(searchActive ? 'Try a different keyword' : 'Check back soon for more content',
        textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted)),
    ]),
  ));
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(LucideIcons.wifiOff, size: 48, color: AppColors.textMuted),
    const SizedBox(height: 14),
    const Text('Could not load resources', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 10),
    ElevatedButton.icon(
      onPressed: onRetry,
      icon: const Icon(LucideIcons.refreshCw, size: 16),
      label: const Text('Retry', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ),
  ]));
}
