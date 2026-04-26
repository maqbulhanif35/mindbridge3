import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/mood_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/goal_plan_engine.dart';

// ─── Filter type ──────────────────────────────────────────

enum _JFilter { all, today, week, month }

// ─── Mood filter ──────────────────────────────────────────

enum _MoodFilter { all, great, good, okay, low }

extension _MoodFilterExt on _MoodFilter {
  String get label => switch (this) {
        _MoodFilter.all => 'Any mood',
        _MoodFilter.great => '😊 Great',
        _MoodFilter.good => '🙂 Good',
        _MoodFilter.okay => '😐 Okay',
        _MoodFilter.low => '😔 Low',
      };
  bool matches(int? score) {
    if (score == null) return this == _MoodFilter.all;
    return switch (this) {
      _MoodFilter.all => true,
      _MoodFilter.great => score >= 8,
      _MoodFilter.good => score >= 6 && score < 8,
      _MoodFilter.okay => score >= 4 && score < 6,
      _MoodFilter.low => score < 4,
    };
  }
}

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  _JFilter _filter = _JFilter.all;
  _MoodFilter _moodFilter = _MoodFilter.all;
  final Set<String> _bookmarked = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  int _streak(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;
    final days = entries
        .map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayN = DateTime(today.year, today.month, today.day);
    if (todayN.difference(days.first).inDays > 1) return 0;
    int streak = 0;
    DateTime exp = days.first;
    for (final d in days) {
      if (d == exp) {
        streak++;
        exp = exp.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  List<JournalEntry> _apply(List<JournalEntry> all) {
    final now = DateTime.now();
    List<JournalEntry> result = switch (_filter) {
      _JFilter.today => all.where((e) => DateUtils.isSameDay(e.createdAt, now)).toList(),
      _JFilter.week => all.where((e) => now.difference(e.createdAt).inDays <= 7).toList(),
      _JFilter.month => all
          .where((e) => e.createdAt.month == now.month && e.createdAt.year == now.year)
          .toList(),
      _ => all,
    };
    if (_moodFilter != _MoodFilter.all) {
      result = result.where((e) => _moodFilter.matches(e.moodScore)).toList();
    }
    return result;
  }

  List<({String label, List<JournalEntry> entries})> _group(List<JournalEntry> entries) {
    final now = DateTime.now();
    final todayN = DateTime(now.year, now.month, now.day);
    final yestN = todayN.subtract(const Duration(days: 1));
    final order = <String>[];
    final map = <String, List<JournalEntry>>{};

    for (final e in entries) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      final String label;
      if (d == todayN) {
        label = 'Today';
      } else if (d == yestN) {
        label = 'Yesterday';
      } else if (todayN.difference(d).inDays <= 7) {
        label = 'This Week';
      } else {
        label = DateFormat('MMMM yyyy').format(e.createdAt);
      }
      if (!map.containsKey(label)) {
        order.add(label);
        map[label] = [];
      }
      map[label]!.add(e);
    }
    return order.map((l) => (label: l, entries: map[l]!)).toList();
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Entry?',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        content: const Text(
          'This entry will be permanently deleted.',
          style: TextStyle(fontFamily: 'Nunito', color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(moodProvider.notifier).deleteJournalEntry(id);
  }

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodProvider);
    final allEntries = moodState.journalEntries;
    final entries = _apply(allEntries);
    final groups = _group(entries);
    final streak = _streak(allEntries);
    final thisMonth = allEntries
        .where((e) =>
            e.createdAt.month == DateTime.now().month &&
            e.createdAt.year == DateTime.now().year)
        .length;
    final totalWords = allEntries.fold<int>(
      0,
      (sum, e) => sum + e.content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: const Text(
            'Journal',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.search, size: 20, color: AppColors.textSecondary),
              onPressed: () => showSearch(
                context: context,
                delegate: _JournalSearchDelegate(
                  allEntries,
                  onTap: (e) => context.push(AppRoutes.journalEntry, extra: {'entry': e}),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.slidersHorizontal, size: 20, color: AppColors.textSecondary),
              onPressed: () => _showMoodFilter(context),
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
            tabs: const [
              Tab(text: 'Entries'),
              Tab(text: 'Analytics'),
              Tab(text: 'Insights'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Tab 0: Entries ──
            _EntriesTab(
              allEntries: allEntries,
              entries: entries,
              groups: groups,
              streak: streak,
              thisMonth: thisMonth,
              totalWords: totalWords,
              filter: _filter,
              moodFilter: _moodFilter,
              bookmarked: _bookmarked,
              onFilterChanged: (f) => setState(() => _filter = f),
              onDelete: _confirmDelete,
              onBookmark: (id) => setState(() {
                if (_bookmarked.contains(id)) {
                  _bookmarked.remove(id);
                } else {
                  _bookmarked.add(id);
                }
              }),
              onNewEntry: () => context.push(AppRoutes.journalEntry),
              onOpenEntry: (e) => context.push(AppRoutes.journalEntry, extra: {'entry': e}),
            ),
            // ── Tab 1: Analytics ──
            _AnalyticsTab(entries: allEntries),
            // ── Tab 2: Insights ──
            _InsightsTab(entries: allEntries, streak: streak),
          ],
        ),
        floatingActionButton: ListenableBuilder(
          listenable: _tabCtrl,
          builder: (_, __) => _tabCtrl.index == 0
              ? FloatingActionButton.extended(
                  onPressed: () => context.push(AppRoutes.journalEntry),
                  icon: const Icon(LucideIcons.penLine, size: 18),
                  label: const Text(
                    'New Entry',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 3,
                ).animate().scale(curve: Curves.elasticOut)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  void _showMoodFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Mood',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...(_MoodFilter.values.map((m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.label,
                      style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
                  trailing: _moodFilter == m
                      ? const Icon(LucideIcons.check, color: AppColors.primary, size: 18)
                      : null,
                  onTap: () {
                    setState(() => _moodFilter = m);
                    Navigator.pop(context);
                  },
                ))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Entries Tab ──────────────────────────────────────────

class _EntriesTab extends StatelessWidget {
  final List<JournalEntry> allEntries;
  final List<JournalEntry> entries;
  final List<({String label, List<JournalEntry> entries})> groups;
  final int streak;
  final int thisMonth;
  final int totalWords;
  final _JFilter filter;
  final _MoodFilter moodFilter;
  final Set<String> bookmarked;
  final ValueChanged<_JFilter> onFilterChanged;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onBookmark;
  final VoidCallback onNewEntry;
  final ValueChanged<JournalEntry> onOpenEntry;

  const _EntriesTab({
    required this.allEntries,
    required this.entries,
    required this.groups,
    required this.streak,
    required this.thisMonth,
    required this.totalWords,
    required this.filter,
    required this.moodFilter,
    required this.bookmarked,
    required this.onFilterChanged,
    required this.onDelete,
    required this.onBookmark,
    required this.onNewEntry,
    required this.onOpenEntry,
  });

  String _formatWords(int w) =>
      w >= 1000 ? '${(w / 1000).toStringAsFixed(1)}k' : '$w';

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Hero Stats ──
        SliverToBoxAdapter(
          child: _HeroStats(
            total: allEntries.length,
            thisMonth: thisMonth,
            streak: streak,
            totalWords: totalWords,
            formatWords: _formatWords,
          ).animate().fadeIn(delay: 60.ms),
        ),

        // ── Prompt Banner ──
        SliverToBoxAdapter(
          child: _PromptBanner(onTap: onNewEntry).animate().fadeIn(delay: 100.ms),
        ),

        // ── Writing Milestones ──
        if (allEntries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WritingMilestones(entries: allEntries).animate().fadeIn(delay: 120.ms),
            ),
          ),

        // ── Filter Bar ──
        if (allEntries.isNotEmpty)
          SliverToBoxAdapter(
            child: _FilterBar(
              active: filter,
              moodFilter: moodFilter,
              onChanged: onFilterChanged,
            ).animate().fadeIn(delay: 130.ms),
          ),

        // ── Mood filter badge ──
        if (moodFilter != _MoodFilter.all)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.slidersHorizontal, size: 10, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          moodFilter.label,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Entries ──
        if (allEntries.isEmpty)
          SliverFillRemaining(child: _EmptyJournal(onStart: onNewEntry))
        else if (entries.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(LucideIcons.calendarOff,
                        size: 32, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No entries match your filters',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  int remaining = idx;
                  for (final g in groups) {
                    if (remaining == 0) {
                      return _SectionLabel(label: g.label)
                          .animate()
                          .fadeIn(delay: 50.ms);
                    }
                    remaining--;
                    if (remaining < g.entries.length) {
                      final e = g.entries[remaining];
                      return _JournalCard(
                        entry: e,
                        isBookmarked: bookmarked.contains(e.id),
                        onTap: () => onOpenEntry(e),
                        onDelete: () => onDelete(e.id),
                        onBookmark: () => onBookmark(e.id),
                      )
                          .animate()
                          .fadeIn(delay: (remaining * 40).ms)
                          .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
                    }
                    remaining -= g.entries.length;
                  }
                  return null;
                },
                childCount: groups.fold<int>(0, (sum, g) => sum + 1 + g.entries.length),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Analytics Tab ────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  final List<JournalEntry> entries;
  const _AnalyticsTab({required this.entries});

  // Last 7 days: mood average per day
  List<FlSpot> _moodSpots() {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayEntries = entries.where((e) {
        final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
        return d == day;
      }).toList();
      final scored = dayEntries.where((e) => e.moodScore != null).toList();
      if (scored.isNotEmpty) {
        final avg = scored.fold<int>(0, (s, e) => s + e.moodScore!) / scored.length;
        spots.add(FlSpot((6 - i).toDouble(), avg));
      }
    }
    return spots;
  }

  // Last 7 days: word count per day
  List<BarChartGroupData> _wordBars() {
    final now = DateTime.now();
    final groups = <BarChartGroupData>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayEntries = entries.where((e) {
        final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
        return d == day;
      }).toList();
      final words = dayEntries.fold<int>(
          0,
          (s, e) => s +
              e.content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);
      groups.add(BarChartGroupData(
        x: 6 - i,
        barRods: [
          BarChartRodData(
            toY: words.toDouble(),
            color: words > 0 ? AppColors.primary : AppColors.border,
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ));
    }
    return groups;
  }

  // Day of week distribution
  List<int> _dowCounts() {
    final counts = List<int>.filled(7, 0);
    for (final e in entries) {
      counts[e.createdAt.weekday % 7]++;
    }
    return counts;
  }

  // Tag frequency
  Map<String, int> _tagFreq() {
    final freq = <String, int>{};
    for (final e in entries) {
      for (final t in e.tags) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    final sorted = Map.fromEntries(
        freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return Map.fromEntries(sorted.entries.take(8));
  }

  static const _dowLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(LucideIcons.chartBar, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Analytics will appear here',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start journaling to see your patterns',
              style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final moodSpots = _moodSpots();
    final wordBars = _wordBars();
    final dowCounts = _dowCounts();
    final maxDow = dowCounts.isEmpty ? 1 : dowCounts.reduce((a, b) => a > b ? a : b);
    final tagFreq = _tagFreq();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ── Mood Trend ──
        _AnalyticsCard(
          icon: LucideIcons.trendingUp,
          title: 'Mood Trend',
          subtitle: 'Last 7 days',
          child: moodSpots.isEmpty
              ? const _NoDataPlaceholder(label: 'No mood data yet')
              : SizedBox(
                  height: 140,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: moodSpots,
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.primary,
                              strokeColor: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.25),
                                AppColors.primary.withOpacity(0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: 10,
                      titlesData: FlTitlesData(
                        leftTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final now = DateTime.now();
                              final day = now.subtract(Duration(days: 6 - value.toInt()));
                              return Text(
                                _dayLetters[day.weekday % 7],
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 2,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFEEEEEE),
                          strokeWidth: 1,
                        ),
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
        ).animate().fadeIn(delay: 60.ms),

        const SizedBox(height: 14),

        // ── Words Per Day ──
        _AnalyticsCard(
          icon: LucideIcons.type,
          title: 'Words Written',
          subtitle: 'Last 7 days',
          child: SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                barGroups: wordBars,
                titlesData: FlTitlesData(
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final now = DateTime.now();
                        final day =
                            now.subtract(Duration(days: 6 - value.toInt()));
                        return Text(
                          _dayLetters[day.weekday % 7],
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 14),

        // ── Day of Week Pattern ──
        _AnalyticsCard(
          icon: LucideIcons.calendarDays,
          title: 'Writing Pattern',
          subtitle: 'Which day you write most',
          child: Column(
            children: List.generate(7, (i) {
              final count = dowCounts[i];
              final frac = maxDow == 0 ? 0.0 : count / maxDow;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        _dowLabels[i],
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: frac,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: frac > 0.7
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ).animate().fadeIn(delay: 140.ms),

        const SizedBox(height: 14),

        // ── Tag Frequency ──
        if (tagFreq.isNotEmpty)
          _AnalyticsCard(
            icon: LucideIcons.tag,
            title: 'Top Tags',
            subtitle: 'Most used topics',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tagFreq.entries.map((entry) {
                final maxCount = tagFreq.values.first;
                final opacity = 0.4 + 0.6 * (entry.value / maxCount);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(opacity * 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(opacity * 0.4)),
                  ),
                  child: Text(
                    '#${entry.key}  ${entry.value}',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary.withOpacity(opacity),
                    ),
                  ),
                );
              }).toList(),
            ),
          ).animate().fadeIn(delay: 180.ms),
      ],
    );
  }
}

// ─── Insights Tab ─────────────────────────────────────────

class _InsightsTab extends ConsumerStatefulWidget {
  final List<JournalEntry> entries;
  final int streak;
  const _InsightsTab({required this.entries, required this.streak});

  @override
  ConsumerState<_InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends ConsumerState<_InsightsTab> {
  int _expandedPrompt = -1;

  String _bestWritingTime() {
    if (widget.entries.isEmpty) return 'Not enough data';
    final counts = [0, 0, 0, 0]; // morning, afternoon, evening, night
    for (final e in widget.entries) {
      final h = e.createdAt.hour;
      if (h >= 5 && h < 12) counts[0]++;
      else if (h >= 12 && h < 17) counts[1]++;
      else if (h >= 17 && h < 21) counts[2]++;
      else counts[3]++;
    }
    final max = counts.reduce((a, b) => a > b ? a : b);
    final idx = counts.indexOf(max);
    return ['Morning (5am–12pm)', 'Afternoon (12–5pm)', 'Evening (5–9pm)', 'Night (9pm–5am)'][idx];
  }

  double _moodWritingCorrelation() {
    final scored = widget.entries.where((e) => e.moodScore != null).toList();
    if (scored.length < 3) return 0;
    // Simple: do high-word-count entries correlate with higher mood?
    final words = scored.map((e) =>
        e.content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);
    final moods = scored.map((e) => e.moodScore!);
    final avgWords = words.fold<double>(0, (s, w) => s + w) / words.length;
    final avgMood = moods.fold<double>(0, (s, m) => s + m) / moods.length;
    double num = 0, denW = 0, denM = 0;
    for (int i = 0; i < scored.length; i++) {
      final w = words.elementAt(i) - avgWords;
      final m = moods.elementAt(i) - avgMood;
      num += w * m;
      denW += w * w;
      denM += m * m;
    }
    if (denW == 0 || denM == 0) return 0;
    return (num / (denW * denM).abs().clamp(0.001, double.infinity)).clamp(-1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final bestTime = _bestWritingTime();
    final corr = _moodWritingCorrelation();
    final corrLabel = corr > 0.3
        ? 'Longer entries → better mood 📈'
        : corr < -0.3
            ? 'Longer entries → lower mood 📉'
            : 'No clear writing–mood link yet';

    // Goal-aware personalized prompts
    final user = ref.watch(currentUserProvider);
    final prompts = GoalPlanEngine.getJournalPrompts(user, max: 8);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ── AI Summary (mock) ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.20),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Weekly AI Reflection',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Maya AI',
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.entries.isEmpty
                    ? "Start writing to receive your personalized weekly reflection from Maya, your AI wellness companion."
                    : "Your journal shows ${widget.entries.length} entries this period. "
                        "Your writing is most consistent in the $bestTime. "
                        "${corr > 0.2 ? 'Writing more appears to lift your mood — keep it up!' : 'Each entry is a step toward greater self-awareness.'}",
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 60.ms),

        const SizedBox(height: 16),

        // ── Stat Cards ──
        Row(
          children: [
            _StatTile(
              icon: LucideIcons.clock,
              label: 'Best writing time',
              value: bestTime.split(' ').first,
              color: AppColors.tertiary,
            ),
            const SizedBox(width: 12),
            _StatTile(
              icon: LucideIcons.flame,
              label: 'Current streak',
              value: '${widget.streak} days',
              color: widget.streak >= 3 ? const Color(0xFFFF6B35) : AppColors.primary,
            ),
          ],
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 12),

        Row(
          children: [
            _StatTile(
              icon: LucideIcons.brain,
              label: 'Writing × mood',
              value: corrLabel.split(' ').take(3).join(' '),
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            _StatTile(
              icon: LucideIcons.trophy,
              label: 'Total entries',
              value: '${widget.entries.length}',
              color: AppColors.secondary,
            ),
          ],
        ).animate().fadeIn(delay: 140.ms),

        const SizedBox(height: 20),

        // ── 7-day streak dots ──
        _AnalyticsCard(
          icon: LucideIcons.calendarCheck,
          title: 'This Week',
          subtitle: 'Daily writing check-ins',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final now = DateTime.now();
              final day = now.subtract(Duration(days: 6 - i));
              final dayN = DateTime(day.year, day.month, day.day);
              final hasEntry = widget.entries.any((e) {
                final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
                return d == dayN;
              });
              final isToday = DateUtils.isSameDay(day, now);
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasEntry
                          ? AppColors.primary
                          : isToday
                              ? AppColors.primaryContainer
                              : AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                      border: isToday
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: hasEntry
                        ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                        : isToday
                            ? const Icon(LucideIcons.penLine,
                                size: 14, color: AppColors.primary)
                            : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('E').format(day).substring(0, 1),
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasEntry ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              );
            }),
          ),
        ).animate().fadeIn(delay: 180.ms),

        const SizedBox(height: 20),

        // ── Prompts Bank ──
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(LucideIcons.lightbulb, size: 16, color: AppColors.tertiary),
              const SizedBox(width: 6),
              const Text(
                'WRITING PROMPTS',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (user != null && user.goals.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.target, size: 10, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        'matched to your goals',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        ...prompts.asMap().entries.map((entry) {
          final i = entry.key;
          final (q, hint) = entry.value;
          final isExpanded = _expandedPrompt == i;
          return GestureDetector(
            onTap: () => setState(() => _expandedPrompt = isExpanded ? -1 : i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isExpanded ? AppColors.primary.withOpacity(0.3) : AppColors.border,
                ),
                boxShadow: isExpanded
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          q,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isExpanded ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 10),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.penLine, size: 13, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Use this prompt',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: (200 + i * 40).ms),
          );
        }),
      ],
    );
  }
}

// ─── Analytics Card ───────────────────────────────────────

class _AnalyticsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _AnalyticsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDataPlaceholder extends StatelessWidget {
  final String label;
  const _NoDataPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Hero Stats ───────────────────────────────────────────

class _HeroStats extends StatelessWidget {
  final int total;
  final int thisMonth;
  final int streak;
  final int totalWords;
  final String Function(int) formatWords;

  const _HeroStats({
    required this.total,
    required this.thisMonth,
    required this.streak,
    required this.totalWords,
    required this.formatWords,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0D9488).withAlpha(80), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Text('📖', style: TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$total ${total == 1 ? 'entry' : 'entries'}',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
                    const Text('in your journal', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Nunito')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    Text(streak >= 3 ? '🔥' : '⚡', style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text('$streak', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito', height: 1.0)),
                    const Text('day streak', style: TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _GlassStat(icon: LucideIcons.calendarDays, value: '$thisMonth', label: 'this month'),
              const SizedBox(width: 10),
              _GlassStat(icon: LucideIcons.type, value: formatWords(totalWords), label: 'total words'),
              const SizedBox(width: 10),
              _GlassStat(icon: LucideIcons.target, value: total > 0 ? '${((thisMonth / 30) * 100).clamp(0, 100).round()}%' : '0%', label: 'consistency'),
            ],
          ),
          if (thisMonth < 20) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.target, size: 14, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Monthly Goal: 20 entries', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Nunito')),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (thisMonth / 20).clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withAlpha(40),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$thisMonth/20', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Nunito')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _GlassStat({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Nunito', height: 1.0)),
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 9,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Bar ───────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final _JFilter active;
  final _MoodFilter moodFilter;
  final ValueChanged<_JFilter> onChanged;

  const _FilterBar({
    required this.active,
    required this.moodFilter,
    required this.onChanged,
  });

  static const _options = [
    (_JFilter.all, 'All'),
    (_JFilter.today, 'Today'),
    (_JFilter.week, 'This Week'),
    (_JFilter.month, 'This Month'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (filter, label) = _options[i];
            final isActive = active == filter;
            return GestureDetector(
              onTap: () => onChanged(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: isActive ? null : Border.all(color: AppColors.border),
                ),
                child: Text(
                  label,
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
      ),
    );
  }
}

// ─── Prompt Banner ────────────────────────────────────────

class _PromptBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PromptBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final idx = DateTime.now().day % AppStrings.journalPrompts.length;
    final prompt = AppStrings.journalPrompts[idx];
    const gradients = [
      [Color(0xFF667EEA), Color(0xFF764BA2)],
      [Color(0xFFF093FB), Color(0xFFF5576C)],
      [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      [Color(0xFF43E97B), Color(0xFF38F9D7)],
      [Color(0xFFFA709A), Color(0xFFFEE140)],
    ];
    final grad = gradients[idx % gradients.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: grad[0].withAlpha(80), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: Colors.white.withAlpha(35), borderRadius: BorderRadius.circular(16)),
              child: const Center(child: Text('💭', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's Prompt", style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(prompt, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withAlpha(35), borderRadius: BorderRadius.circular(12)),
              child: const Column(children: [
                Icon(LucideIcons.penLine, size: 14, color: Colors.white),
                SizedBox(height: 2),
                Text('Write', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Nunito')),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.8)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: AppColors.border)),
    ]),
  );
}

// ─── Journal Card ─────────────────────────────────────────

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onBookmark;

  const _JournalCard({
    required this.entry,
    required this.isBookmarked,
    required this.onTap,
    required this.onDelete,
    required this.onBookmark,
  });

  Color get _moodColor {
    if (entry.moodScore == null) return AppColors.primary;
    final score = entry.moodScore!.clamp(1, 10);
    return AppColors.moodColors[score - 1];
  }

  int get _wordCount {
    return entry.content
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
  }

  int get _readingSeconds => ((_wordCount / 200) * 60).ceil();

  String get _readingTime {
    if (_readingSeconds < 60) return '${_readingSeconds}s read';
    return '${(_readingSeconds / 60).ceil()}m read';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('h:mm a').format(entry.createdAt);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.trash2, color: AppColors.error, size: 22),
            const SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        onDelete();
        return false; // let provider handle removal
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _moodColor.withAlpha(60)),
            boxShadow: [
              BoxShadow(color: _moodColor.withAlpha(25), blurRadius: 16, offset: const Offset(0, 5)),
              BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [_moodColor, _moodColor.withAlpha(160)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (entry.moodScore != null) ...[
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _moodColor.withAlpha(20),
                                shape: BoxShape.circle,
                                border: Border.all(color: _moodColor.withAlpha(60)),
                              ),
                              child: Center(child: Text(AppStrings.moodEmojis[entry.moodScore!], style: const TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(child: Text(entry.displayTitle,
                            style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () { HapticFeedback.lightImpact(); onBookmark(); },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isBookmarked ? AppColors.primary.withAlpha(18) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(isBookmarked ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                                size: 15, color: isBookmarked ? AppColors.primary : const Color(0xFF94A3B8)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(LucideIcons.clock, size: 10, color: _moodColor.withAlpha(150)),
                          const SizedBox(width: 4),
                          Text(dateStr, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: _moodColor.withAlpha(180), fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          _DepthBadge(wordCount: _wordCount),
                        ]),
                        const SizedBox(height: 10),
                        Text(entry.content,
                          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Color(0xFF475569), height: 1.55),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Row(children: [
                          _Chip(icon: LucideIcons.type, label: '$_wordCount words'),
                          const SizedBox(width: 6),
                          _Chip(icon: LucideIcons.clock, label: _readingTime),
                          if (entry.aiInsight != null) ...[const SizedBox(width: 6), _Chip(icon: LucideIcons.sparkles, label: 'AI', isPrimary: true)],
                          const Spacer(),
                          ...entry.tags.take(2).map((tag) => Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(20)),
                              child: Text('#$tag', style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ),
                          )),
                        ]),
                      ],
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;

  const _Chip({required this.icon, required this.label, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primaryContainer : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 10, color: isPrimary ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              color: isPrimary ? AppColors.primary : AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Depth Badge ──────────────────────────────────────────

class _DepthBadge extends StatelessWidget {
  final int wordCount;
  const _DepthBadge({required this.wordCount});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (wordCount >= 100) {
      label = 'Deep 🌊';
      color = AppColors.primary;
    } else if (wordCount >= 30) {
      label = 'Medium ✨';
      color = const Color(0xFFF59E0B);
    } else {
      label = 'Quick ⚡';
      color = const Color(0xFF94A3B8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Writing Milestones ───────────────────────────────────

class _WritingMilestones extends StatelessWidget {
  final List<JournalEntry> entries;
  const _WritingMilestones({required this.entries});

  int get _totalWords => entries.fold<int>(
        0,
        (s, e) =>
            s + e.content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      );

  int _streak() {
    if (entries.isEmpty) return 0;
    final days = entries
        .map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayN = DateTime(today.year, today.month, today.day);
    if (todayN.difference(days.first).inDays > 1) return 0;
    int streak = 0;
    DateTime exp = days.first;
    for (final d in days) {
      if (d == exp) {
        streak++;
        exp = exp.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final total = entries.length;
    final words = _totalWords;
    final streak = _streak();

    final milestones = [
      (icon: '🌱', label: 'First Entry', earned: total >= 1),
      (icon: '🔥', label: '7-Day Streak', earned: streak >= 7),
      (icon: '📚', label: '50 Entries', earned: total >= 50),
      (icon: '✍️', label: '1k Words', earned: words >= 1000),
      (icon: '🏆', label: '30-Day Streak', earned: streak >= 30),
    ];

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: milestones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final m = milestones[i];
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 350),
            opacity: m.earned ? 1.0 : 0.38,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.earned ? AppColors.primaryContainer : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: m.earned
                      ? AppColors.primary.withAlpha(60)
                      : AppColors.border.withAlpha(80),
                ),
                boxShadow: m.earned
                    ? [BoxShadow(color: AppColors.primary.withAlpha(20), blurRadius: 8)]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: m.earned ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Empty Journal ────────────────────────────────────────

class _EmptyJournal extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyJournal({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: null,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(LucideIcons.bookOpen, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Start your journal',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Writing helps you understand your thoughts,\nprocess emotions and grow as a person.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.6),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: null,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.penLine, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Write your first entry',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

// ─── Search Delegate ──────────────────────────────────────

class _JournalSearchDelegate extends SearchDelegate {
  final List<JournalEntry> entries;
  final ValueChanged<JournalEntry> onTap;

  _JournalSearchDelegate(this.entries, {required this.onTap});

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
        appBarTheme:
            const AppBarTheme(backgroundColor: AppColors.surface, elevation: 0),
      );

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
            icon: const Icon(LucideIcons.x, size: 18), onPressed: () => query = '')
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(LucideIcons.arrowLeft, size: 20),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final q = query.toLowerCase();
    final filtered = entries
        .where((e) =>
            e.content.toLowerCase().contains(q) ||
            (e.title?.toLowerCase().contains(q) ?? false) ||
            e.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.searchX, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              query.isEmpty ? 'Type to search entries' : 'No entries found',
              style: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 16, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final e = filtered[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  e.moodScore != null
                      ? AppStrings.moodEmojis[e.moodScore!]
                      : '📝',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            title: Text(e.displayTitle,
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            subtitle: Text(
              e.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: AppColors.textSecondary),
            ),
            trailing: Text(
              DateFormat('MMM d').format(e.createdAt),
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600),
            ),
            onTap: () => onTap(e),
          ),
        );
      },
    );
  }
}
