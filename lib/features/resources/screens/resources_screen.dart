import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/mood_provider.dart';

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  final Set<int> _bookmarked = {};
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  static const List<String> _categories = [
    'All',
    'Anxiety',
    'Stress',
    'Depression',
    'Sleep',
    'Relationships',
    'Self-Esteem',
    'Finance',
    'Campus Life',
    'Crisis',
  ];

  static const List<Map<String, dynamic>> _resources = [
    {
      'title': 'Surviving CAT Season Without Burning Out',
      'description': 'Proven strategies for managing the intense pressure of Continuous Assessment Tests while protecting your mental health.',
      'category': 'Stress',
      'type': 'article',
      'emoji': '📝',
      'readTime': '7 min',
      'isHot': true,
      'color': 0xFF00BEB4,
    },
    {
      'title': 'HELB Stress is Real — Here\'s How to Cope',
      'description': 'When your loan delays and fees are due, the anxiety is real. Practical steps for managing financial stress as a Kenyan student.',
      'category': 'Finance',
      'type': 'article',
      'emoji': '💸',
      'readTime': '6 min',
      'isHot': true,
      'color': 0xFFF59E0B,
    },
    {
      'title': 'Understanding Anxiety in Campus Life',
      'description': 'A guide to recognizing and managing anxiety that builds during lectures, group work, and hostel life.',
      'category': 'Anxiety',
      'type': 'article',
      'emoji': '😰',
      'readTime': '8 min',
      'isHot': false,
      'color': 0xFF0EA5E9,
    },
    {
      'title': 'The Depression Toolkit',
      'description': '10 evidence-based strategies for lifting your mood — adapted for the Kenyan campus environment.',
      'category': 'Depression',
      'type': 'article',
      'emoji': '💙',
      'readTime': '12 min',
      'isHot': false,
      'color': 0xFF00BEB4,
    },
    {
      'title': 'Sleep When You Have Assignments Due',
      'description': 'Build a sleep routine that works when you\'re juggling CATs, assignments, and part-time work.',
      'category': 'Sleep',
      'type': 'article',
      'emoji': '😴',
      'readTime': '6 min',
      'isHot': false,
      'color': 0xFF0EA5E9,
    },
    {
      'title': 'Imposter Syndrome: You Belong Here',
      'description': 'Overcoming the feeling that you don\'t deserve your spot — especially when coming from a humble background.',
      'category': 'Self-Esteem',
      'type': 'article',
      'emoji': '💪',
      'readTime': '10 min',
      'isHot': true,
      'color': 0xFFF59E0B,
    },
    {
      'title': 'Navigating Attachment & Internship Pressure',
      'description': 'Industrial attachment can be overwhelming — unpaid work, new environments, and professional expectations all at once.',
      'category': 'Campus Life',
      'type': 'guide',
      'emoji': '🏢',
      'readTime': '8 min',
      'isHot': false,
      'color': 0xFF10B981,
    },
    {
      'title': 'Navigating Difficult Relationships',
      'description': 'Setting boundaries and communicating effectively — with friends, partners, lecturers, and family back home.',
      'category': 'Relationships',
      'type': 'article',
      'emoji': '❤️',
      'readTime': '11 min',
      'isHot': false,
      'color': 0xFFFF6B6B,
    },
    {
      'title': 'Finding Your Campus Counselor',
      'description': 'Every Kenyan university has a free, confidential Student Counseling Unit. Here\'s how to access it without stigma.',
      'category': 'Campus Life',
      'type': 'guide',
      'emoji': '🏥',
      'readTime': '4 min',
      'isHot': false,
      'color': 0xFF00BEB4,
    },
    {
      'title': 'Crisis: What to Do Right Now',
      'description': 'Step-by-step guidance for a mental health crisis — Kenyan crisis lines, campus resources, and immediate coping steps.',
      'category': 'Crisis',
      'type': 'guide',
      'emoji': '🆘',
      'readTime': '5 min',
      'isHot': false,
      'color': 0xFFFF6B6B,
    },
    {
      'title': 'CBT Thought Record Exercise',
      'description': 'An interactive exercise to identify and reframe negative thought patterns — great for exam anxiety and self-doubt.',
      'category': 'Anxiety',
      'type': 'exercise',
      'emoji': '🧠',
      'readTime': '15 min',
      'isHot': false,
      'color': 0xFF10B981,
    },
    {
      'title': 'The Kenyan Student Burnout Guide',
      'description': 'Burnout hits differently when you\'re also supporting family and managing fees. Recognize it and recover.',
      'category': 'Stress',
      'type': 'article',
      'emoji': '🔥',
      'readTime': '9 min',
      'isHot': false,
      'color': 0xFFFF6B6B,
    },
  ];

  List<Map<String, dynamic>> get _filteredResources {
    if (_selectedCategory == 'All') return _resources;
    return _resources
        .where((r) => r['category'] == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredResources;
    final moodState = ref.watch(moodProvider);
    final authState = ref.watch(authProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'Resources',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.search, size: 20, color: AppColors.textSecondary),
              onPressed: () {},
            ),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [Tab(text: '✨ For You'), Tab(text: '📚 Library')],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // ─── For You Tab ──────────────────────────────
            _ForYouTab(
              resources: _resources,
              bookmarked: _bookmarked,
              moodState: moodState,
              goals: authState.user?.goals ?? [],
              onBookmark: (idx) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (_bookmarked.contains(idx)) {
                    _bookmarked.remove(idx);
                  } else {
                    _bookmarked.add(idx);
                  }
                });
              },
            ),
            // ─── Library Tab (existing) ───────────────────
            Column(
          children: [
            // ─── Category Filter ──────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ─── Resources List ───────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: filtered.length + 1,
                itemBuilder: (_, i) {
                  // First item: crisis hotline card (always at top for All category)
                  if (i == 0 && _selectedCategory == 'All') {
                    return const _CrisisHotlineCard()
                        .animate()
                        .fadeIn(duration: 400.ms);
                  }
                  final resIdx = _selectedCategory == 'All' ? i - 1 : i;
                  if (resIdx >= filtered.length) return const SizedBox();
                  final r = filtered[resIdx];
                  final globalIdx = _resources.indexOf(r);
                  return _ResourceCard(
                    resource: r,
                    isBookmarked: _bookmarked.contains(globalIdx),
                    onBookmark: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_bookmarked.contains(globalIdx)) {
                          _bookmarked.remove(globalIdx);
                        } else {
                          _bookmarked.add(globalIdx);
                        }
                      });
                    },
                  )
                      .animate()
                      .fadeIn(delay: (resIdx * 50).ms)
                      .slideY(begin: 0.1);
                },
              ),
            ),
          ],
        ), // end Library Column
          ], // end TabBarView children
        ), // end TabBarView
      ),
    );
  }
}

// ─── For You Tab ──────────────────────────────────────────

class _ForYouTab extends StatelessWidget {
  final List<Map<String, dynamic>> resources;
  final Set<int> bookmarked;
  final MoodState moodState;
  final List<String> goals;
  final ValueChanged<int> onBookmark;

  const _ForYouTab({
    required this.resources,
    required this.bookmarked,
    required this.moodState,
    required this.goals,
    required this.onBookmark,
  });

  // Smart recommendation: pick resources that match the user's current state
  List<Map<String, dynamic>> _recommended() {
    final todayMood = moodState.todayEntry?.moodScore ?? 5;
    final todayEmotions = moodState.todayEntry?.emotions ?? [];
    final goalCategories = goals.map((g) {
      if (g.contains('anxiety')) return 'Anxiety';
      if (g.contains('depression') || g.contains('motivation')) return 'Depression';
      if (g.contains('stress') || g.contains('academic')) return 'Stress';
      if (g.contains('sleep')) return 'Sleep';
      if (g.contains('social') || g.contains('relationship')) return 'Relationships';
      if (g.contains('selfesteem') || g.contains('self')) return 'Self-Esteem';
      return null;
    }).whereType<String>().toSet();

    return resources.where((r) {
      final cat = r['category'] as String;
      if (cat == 'Crisis' && todayMood <= 2) return true;
      if (todayMood <= 4 && ['Anxiety', 'Depression', 'Stress'].contains(cat)) return true;
      if (todayEmotions.any((e) => ['anxious', 'stressed', 'overwhelmed']
          .contains(e.toLowerCase())) && cat == 'Anxiety') return true;
      if (todayEmotions.any((e) => ['tired', 'low energy', 'sluggish']
          .contains(e.toLowerCase())) && cat == 'Sleep') return true;
      if (goalCategories.contains(cat)) return true;
      if (r['isHot'] == true) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recs = _recommended();
    final allRecs = recs.isEmpty ? resources.where((r) => r['isHot'] == true).toList() : recs;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ─── Campus Resource Card ─────────────────────
        _CampusResourceCard().animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 16),

        // ─── Personalized picks header ────────────────
        Row(children: [
          const Text('✨', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Picked for you',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (moodState.todayEntry != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Based on today',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),

        ...allRecs.asMap().entries.map((e) {
          final r = e.value;
          final idx = resources.indexOf(r);
          return _ResourceCard(
            resource: r,
            isBookmarked: bookmarked.contains(idx),
            onBookmark: () => onBookmark(idx),
          ).animate().fadeIn(delay: (e.key * 60).ms).slideY(begin: 0.1);
        }),
      ],
    );
  }
}

// ─── Campus Resource Card ─────────────────────────────────

class _CampusResourceCard extends StatelessWidget {
  const _CampusResourceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006B64), Color(0xFF00BEB4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🏫', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campus Mental Health Center',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Free counseling, crisis walk-ins, and peer support — available to all students',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Text(
              'Find',
              style: TextStyle(
                fontSize: 13,
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

// ─── Crisis Hotline Card ──────────────────────────────────

class _CrisisHotlineCard extends StatelessWidget {
  const _CrisisHotlineCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8C42)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🆘', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'In Crisis? Get Help Now',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Befrienders Kenya: 0800 723 253 — Free, 24/7',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Call Now',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF6B6B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resource Card ────────────────────────────────────────

class _ResourceCard extends StatelessWidget {
  final Map<String, dynamic> resource;
  final bool isBookmarked;
  final VoidCallback onBookmark;

  const _ResourceCard({
    required this.resource,
    required this.isBookmarked,
    required this.onBookmark,
  });

  static IconData _typeIcon(String type) => switch (type) {
        'exercise' => LucideIcons.dumbbell,
        'guide' => LucideIcons.map,
        _ => LucideIcons.fileText,
      };

  @override
  Widget build(BuildContext context) {
    final color = Color(resource['color'] as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      resource['emoji'] as String,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_typeIcon(resource['type'] as String),
                                    size: 10, color: color),
                                const SizedBox(width: 3),
                                Text(
                                  (resource['type'] as String).toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (resource['isHot'] == true) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warningContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '🔥 HOT',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        resource['title'] as String,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        resource['description'] as String,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(LucideIcons.clock, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            resource['readTime'] as String,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            resource['category'] as String,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onBookmark,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isBookmarked ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                      key: ValueKey(isBookmarked),
                      color: isBookmarked ? AppColors.primary : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
