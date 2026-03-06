import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  String _selectedCategory = 'All';
  final Set<int> _bookmarked = {};

  static const List<String> _categories = [
    'All',
    'Anxiety',
    'Depression',
    'Stress',
    'Sleep',
    'Relationships',
    'Self-Esteem',
    'Crisis',
  ];

  static const List<Map<String, dynamic>> _resources = [
    {
      'title': 'Understanding Anxiety in Students',
      'description': 'A comprehensive guide to recognizing and managing academic anxiety.',
      'category': 'Anxiety',
      'type': 'article',
      'emoji': '😰',
      'readTime': '8 min',
      'isHot': true,
      'color': 0xFF0EA5E9,
    },
    {
      'title': 'The Depression Toolkit',
      'description': '10 evidence-based strategies for lifting your mood and restoring motivation.',
      'category': 'Depression',
      'type': 'article',
      'emoji': '💙',
      'readTime': '12 min',
      'isHot': false,
      'color': 0xFF6366F1,
    },
    {
      'title': 'Sleep Hygiene for Students',
      'description': 'How to build a sleep routine that actually works around your study schedule.',
      'category': 'Sleep',
      'type': 'article',
      'emoji': '😴',
      'readTime': '6 min',
      'isHot': false,
      'color': 0xFF8B5CF6,
    },
    {
      'title': 'Imposter Syndrome: You Belong Here',
      'description': "Overcoming the feeling that you don't deserve your achievements.",
      'category': 'Self-Esteem',
      'type': 'article',
      'emoji': '💪',
      'readTime': '10 min',
      'isHot': true,
      'color': 0xFFF59E0B,
    },
    {
      'title': 'Stress Before Exams: A Student Guide',
      'description': 'Practical techniques to manage pre-exam anxiety and perform your best.',
      'category': 'Stress',
      'type': 'article',
      'emoji': '📚',
      'readTime': '9 min',
      'isHot': false,
      'color': 0xFF00BEB4,
    },
    {
      'title': 'Navigating Difficult Relationships',
      'description': 'Setting boundaries and communicating effectively with people in your life.',
      'category': 'Relationships',
      'type': 'article',
      'emoji': '❤️',
      'readTime': '11 min',
      'isHot': false,
      'color': 0xFFFF6B6B,
    },
    {
      'title': 'Crisis: What to Do Right Now',
      'description': 'Step-by-step guidance for managing a mental health crisis safely.',
      'category': 'Crisis',
      'type': 'guide',
      'emoji': '🆘',
      'readTime': '5 min',
      'isHot': false,
      'color': 0xFFFF6B6B,
    },
    {
      'title': 'CBT Thought Record Exercise',
      'description': 'An interactive exercise to identify and reframe negative thought patterns.',
      'category': 'Anxiety',
      'type': 'exercise',
      'emoji': '🧠',
      'readTime': '15 min',
      'isHot': false,
      'color': 0xFF10B981,
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'Resource Library',
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
        ),
        body: Column(
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
        ),
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
                  '988 Suicide & Crisis Lifeline — Available 24/7',
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
              'Call 988',
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
