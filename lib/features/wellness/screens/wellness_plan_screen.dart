import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/goal_technique_engine.dart';
import '../../../core/theme/design_tokens.dart';

// ─── Wellness Plan Screen ──────────────────────────────────────────────────────

class WellnessPlanScreen extends ConsumerStatefulWidget {
  const WellnessPlanScreen({super.key});

  @override
  ConsumerState<WellnessPlanScreen> createState() => _WellnessPlanScreenState();
}

class _WellnessPlanScreenState extends ConsumerState<WellnessPlanScreen> {
  final Set<String> _expandedGoals = {};
  int _currentWeek = 1;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final goalPlans = GoalTechniqueEngine.getUserGoalPlans(user);
    final stressorPlans = GoalTechniqueEngine.getUserStressorPlans(user);
    final hasContent = goalPlans.isNotEmpty || stressorPlans.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.tokenBackground,
        body: CustomScrollView(
          slivers: [
            // ─── Header ─────────────────────────────────────
            SliverToBoxAdapter(
              child: _PlanHeader(user: user, goalPlans: goalPlans),
            ),

            if (!hasContent)
              SliverFillRemaining(
                child: _EmptyPlanState(
                  onTap: () => context.go(AppRoutes.profile),
                ),
              )
            else ...[
              // ─── Week Selector ───────────────────────────
              if (goalPlans.isNotEmpty)
                SliverToBoxAdapter(
                  child: _WeekSelector(
                    currentWeek: _currentWeek,
                    onWeekChanged: (w) => setState(() => _currentWeek = w),
                  ).animate().fadeIn(delay: 100.ms),
                ),

              // ─── This Week's Focus ───────────────────────
              if (goalPlans.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ThisWeekCard(
                      goalPlans: goalPlans,
                      currentWeek: _currentWeek,
                    ).animate().fadeIn(delay: 150.ms),
                  ),
                ),

              // ─── Goal Plans ──────────────────────────────
              if (goalPlans.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _SectionLabel(
                      icon: LucideIcons.target,
                      title: 'Your Wellness Goals',
                      subtitle: '${goalPlans.length} personalised plan${goalPlans.length == 1 ? '' : 's'}',
                    ).animate().fadeIn(delay: 180.ms),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _GoalPlanCard(
                        plan: goalPlans[i],
                        isExpanded: _expandedGoals.contains(goalPlans[i].id),
                        onToggle: () {
                          setState(() {
                            if (_expandedGoals.contains(goalPlans[i].id)) {
                              _expandedGoals.remove(goalPlans[i].id);
                            } else {
                              _expandedGoals.add(goalPlans[i].id);
                            }
                          });
                        },
                      ).animate().fadeIn(delay: Duration(milliseconds: 200 + i * 60)),
                      childCount: goalPlans.length,
                    ),
                  ),
                ),
              ],

              // ─── Stressor Toolkits ───────────────────────
              if (stressorPlans.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _SectionLabel(
                      icon: LucideIcons.zap,
                      title: 'Coping Toolkits',
                      subtitle: 'Strategies for your current stressors',
                    ).animate().fadeIn(delay: 300.ms),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _StressorToolkitCard(
                        plan: stressorPlans[i],
                      ).animate().fadeIn(delay: Duration(milliseconds: 350 + i * 60)),
                      childCount: stressorPlans.length,
                    ),
                  ),
                ),
              ],

              // ─── Talk to Maya CTA ────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                sliver: SliverToBoxAdapter(
                  child: _TalkToMayaCTA(user: user)
                      .animate()
                      .fadeIn(delay: 400.ms),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Plan Header ──────────────────────────────────────────────────────────────

class _PlanHeader extends StatelessWidget {
  final UserModel? user;
  final List<GoalPlan> goalPlans;
  const _PlanHeader({required this.user, required this.goalPlans});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF4ECDC4)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.arrowLeft,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'My Wellness Plan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goalPlans.isEmpty
                        ? 'Personalise your plan by setting goals'
                        : 'Evidence-based support for ${user?.displayName ?? 'you'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  if (goalPlans.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: goalPlans.map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: p.color.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.emoji,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 5),
                            Text(p.title,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: context.tokenBackground,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Week Selector ────────────────────────────────────────────────────────────

class _WeekSelector extends StatelessWidget {
  final int currentWeek;
  final ValueChanged<int> onWeekChanged;
  const _WeekSelector({required this.currentWeek, required this.onWeekChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: context.tokenBackground,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: 4,
        itemBuilder: (context, i) {
          final week = i + 1;
          final isActive = currentWeek == week;
          return GestureDetector(
            onTap: () => onWeekChanged(week),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : context.tokenSurface,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary
                      : context.tokenBorder,
                ),
              ),
              child: Text(
                'Week $week',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : context.tokenTextSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── This Week's Focus Card ───────────────────────────────────────────────────

class _ThisWeekCard extends StatelessWidget {
  final List<GoalPlan> goalPlans;
  final int currentWeek;
  const _ThisWeekCard({required this.goalPlans, required this.currentWeek});

  @override
  Widget build(BuildContext context) {
    final primary = goalPlans.first;
    final weekFocus = primary.weeklyPlan.length >= currentWeek
        ? primary.weeklyPlan[currentWeek - 1]
        : primary.weeklyPlan.last;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.color.withOpacity(0.15),
            primary.color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: primary.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(children: [
                  Icon(LucideIcons.calendarDays,
                      size: 11, color: primary.color),
                  const SizedBox(width: 4),
                  Text(
                    'WEEK $currentWeek FOCUS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: primary.color,
                      letterSpacing: 0.8,
                    ),
                  ),
                ]),
              ),
              const Spacer(),
              Text(primary.emoji, style: const TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            weekFocus.theme,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: primary.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            weekFocus.focus,
            style: TextStyle(
              fontSize: 13,
              color: context.tokenTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...weekFocus.actions.map((action) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: primary.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.tokenTextPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Goal Plan Card ───────────────────────────────────────────────────────────

class _GoalPlanCard extends StatelessWidget {
  final GoalPlan plan;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _GoalPlanCard({
    required this.plan,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(
          color: isExpanded
              ? plan.color.withOpacity(0.4)
              : context.tokenBorder,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        children: [
          // ── Header (always visible) ──────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.xlAll,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: plan.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(plan.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.tokenTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: plan.color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            plan.clinicalApproach,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: plan.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 18,
                      color: context.tokenTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded Content ─────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _GoalPlanDetail(plan: plan),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Goal Plan Detail (Expanded) ─────────────────────────────────────────────

class _GoalPlanDetail extends StatefulWidget {
  final GoalPlan plan;
  const _GoalPlanDetail({required this.plan});

  @override
  State<_GoalPlanDetail> createState() => _GoalPlanDetailState();
}

class _GoalPlanDetailState extends State<_GoalPlanDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Column(
      children: [
        Divider(height: 1, color: context.tokenBorder),
        // Approach note
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: plan.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 14, color: plan.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.approachNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokenTextSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, 0),
          child: TabBar(
            controller: _tabs,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
            labelColor: plan.color,
            unselectedLabelColor: AppColors.textMuted,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(color: plan.color, width: 2),
              borderRadius: BorderRadius.circular(2),
            ),
            tabs: const [
              Tab(text: 'Techniques'),
              Tab(text: '4-Week Plan'),
            ],
          ),
        ),
        SizedBox(
          height: _estimateHeight(plan),
          child: TabBarView(
            controller: _tabs,
            children: [
              // Techniques tab
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plan.techniques.length,
                itemBuilder: (context, i) =>
                    _TechniqueCard(technique: plan.techniques[i], planColor: plan.color),
              ),
              // 4-Week plan tab
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plan.weeklyPlan.length,
                itemBuilder: (context, i) =>
                    _WeekCard(weekFocus: plan.weeklyPlan[i], planColor: plan.color),
              ),
            ],
          ),
        ),
        // Talk to Maya
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.md),
          child: Consumer(builder: (context, ref, _) {
            return GestureDetector(
              onTap: () => context.go(AppRoutes.chat),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      plan.color.withOpacity(0.15),
                      plan.color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: plan.color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text(plan.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Talk to Maya about ${plan.title}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: plan.color,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.arrowRight, size: 16, color: plan.color),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  double _estimateHeight(GoalPlan plan) {
    // Approximate height for the TabBarView
    final techHeight = plan.techniques.length * 138.0;
    final weekHeight = plan.weeklyPlan.length * 130.0;
    return techHeight > weekHeight ? techHeight : weekHeight;
  }
}

// ─── Technique Card ───────────────────────────────────────────────────────────

class _TechniqueCard extends StatefulWidget {
  final WellnessTechnique technique;
  final Color planColor;
  const _TechniqueCard({required this.technique, required this.planColor});

  @override
  State<_TechniqueCard> createState() => _TechniqueCardState();
}

class _TechniqueCardState extends State<_TechniqueCard> {
  bool _showEvidence = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.technique;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokenBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.category.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.tokenTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: t.category.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  t.category.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: t.category.color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  t.duration,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.description,
            style: TextStyle(
              fontSize: 12,
              color: context.tokenTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(LucideIcons.clock, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  t.whenToUse,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _showEvidence = !_showEvidence),
            child: Row(
              children: [
                Icon(
                  _showEvidence ? LucideIcons.chevronsUp : LucideIcons.flaskConical,
                  size: 11,
                  color: widget.planColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _showEvidence ? 'Hide evidence' : 'Why it works',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.planColor,
                  ),
                ),
              ],
            ),
          ),
          if (_showEvidence) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.planColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.flaskConical,
                      size: 12, color: widget.planColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.evidenceNote,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.planColor,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Week Card ────────────────────────────────────────────────────────────────

class _WeekCard extends StatelessWidget {
  final WeeklyFocus weekFocus;
  final Color planColor;
  const _WeekCard({required this.weekFocus, required this.planColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokenBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.tokenBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: planColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'WEEK ${weekFocus.week}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: planColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  weekFocus.theme,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.tokenTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            weekFocus.focus,
            style: TextStyle(
              fontSize: 12,
              color: context.tokenTextSecondary,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          ...weekFocus.actions.map((action) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: planColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.tokenTextPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Stressor Toolkit Card ────────────────────────────────────────────────────

class _StressorToolkitCard extends StatefulWidget {
  final StressorPlan plan;
  const _StressorToolkitCard({required this.plan});

  @override
  State<_StressorToolkitCard> createState() => _StressorToolkitCardState();
}

class _StressorToolkitCardState extends State<_StressorToolkitCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.tokenSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(
          color: _expanded
              ? plan.color.withOpacity(0.4)
              : context.tokenBorder,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: AppRadius.xlAll,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: plan.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(plan.emoji,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.tokenTextPrimary,
                          ),
                        ),
                        Text(
                          '${plan.copingTools.length} coping strategies',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.tokenTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 18,
                      color: context.tokenTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: context.tokenBorder),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                children: plan.copingTools.map((tool) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokenBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: plan.color.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(tool.emoji,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          tool.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.tokenTextPrimary,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        tool.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.tokenTextSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.clock,
                              size: 11, color: plan.color),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              tool.whenToUse,
                              style: TextStyle(
                                fontSize: 11,
                                color: plan.color,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Talk to Maya CTA ─────────────────────────────────────────────────────────

class _TalkToMayaCTA extends StatelessWidget {
  final UserModel? user;
  const _TalkToMayaCTA({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.chat),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.xlAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Talk to Maya',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Maya knows your goals and uses evidence-based techniques in every conversation.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.arrowRight, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyPlanState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyPlanState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Your plan awaits',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.tokenTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select wellness goals in your profile to get a personalised, evidence-based plan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.tokenTextMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Set My Goals',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ).animate().fadeIn().slideY(begin: 0.1),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionLabel({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.tokenTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: context.tokenTextMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
