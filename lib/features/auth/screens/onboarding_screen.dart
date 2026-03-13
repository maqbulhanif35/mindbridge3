import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _PageData {
  final String badge;
  final String headline;
  final String body;
  final Color glow;
  final Widget visual;
  const _PageData({
    required this.badge,
    required this.headline,
    required this.body,
    required this.glow,
    required this.visual,
  });
}

// ─── Onboarding Screen ────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _ctrl = PageController();
  int _current = 0;
  String? _selectedIntent;
  String? _selectedTime;

  late final AnimationController _ctaPulse;
  static const _kTotal = 5;

  static final _infoPages = [
    _PageData(
      badge: '7 in 10 Kenyan students',
      headline: "You're not\nalone.",
      body:
          'Most Kenyan university students silently struggle — HELB stress, CAT pressure, family expectations. MindBridge is your private space — zero stigma, total support.',
      glow: const Color(0xFF00BEB4),
      visual: const _MoodMockup(),
    ),
    _PageData(
      badge: 'AI trained in CBT & DBT',
      headline: "Meet Maya,\nyour AI ally.",
      body:
          'Available 24/7, Maya listens without judgment and adapts to exactly how you feel — like a friend who always has time.',
      glow: const Color(0xFF0EA5E9),
      visual: const _ChatMockup(),
    ),
    _PageData(
      badge: '100% private & secure',
      headline: "Build habits\nthat stick.",
      body:
          'Track moods, journal thoughts, build streaks. Beautiful insights show just how far you\'ve come.',
      glow: const Color(0xFFF59E0B),
      visual: const _ProgressMockup(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctaPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _ctaPulse.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _next() {
    if (_current < _kTotal - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_current > 0) {
      _ctrl.previousPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    await ref.read(authProvider.notifier).completeOnboarding();
    if (mounted) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
      context.go(AppRoutes.home);
    }
  }

  Color get _glowColor {
    if (_current < _infoPages.length) return _infoPages[_current].glow;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.padding.bottom;

    return PopScope(
      canPop: _current == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF030F0E),
          body: Stack(
            children: [
              // ── Ambient glow ──────────────────────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                top: -120,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOut,
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _glowColor.withValues(alpha: 0.18),
                        _glowColor.withValues(alpha: 0),
                      ],
                      radius: 0.8,
                    ),
                  ),
                ),
              ),

              // ── Pages ─────────────────────────────────────────
              PageView(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _current = i),
                children: [
                  ..._infoPages.asMap().entries.map((e) => _InfoPage(
                        data: e.value,
                        isActive: _current == e.key,
                        bottomReserve: 96 + bottomPad,
                      )),
                  _IntentPage(
                    selected: _selectedIntent,
                    onSelect: (v) => setState(() => _selectedIntent = v),
                    isActive: _current == 3,
                    bottomReserve: 96 + bottomPad,
                  ),
                  _TimePage(
                    selected: _selectedTime,
                    onSelect: (v) => setState(() => _selectedTime = v),
                    isActive: _current == 4,
                    bottomReserve: 96 + bottomPad,
                  ),
                ],
              ),

              // ── Top bar ───────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 24, 0),
                    child: Row(
                      children: [
                        // Back / logo
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: _current == 0
                              ? const _LogoMark(key: ValueKey('logo'))
                              : GestureDetector(
                                  key: const ValueKey('back'),
                                  onTap: _back,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.10)),
                                    ),
                                    child: const Icon(LucideIcons.arrowLeft,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        // Progress
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              child: LinearProgressIndicator(
                                value: (_current + 1) / _kTotal,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.09),
                                valueColor: AlwaysStoppedAnimation(_glowColor),
                                minHeight: 2,
                              ),
                            ),
                          ),
                        ),
                        if (_current < 3) ...[
                          const SizedBox(width: 18),
                          GestureDetector(
                            onTap: _finish,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.32),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── CTA Button ────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: _CTAButton(
                      label: _current == _kTotal - 1
                          ? "Let's begin"
                          : 'Continue',
                      glow: _glowColor,
                      pulseController: _ctaPulse,
                      onTap: _next,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info Page ────────────────────────────────────────────────────────────────

class _InfoPage extends StatelessWidget {
  final _PageData data;
  final bool isActive;
  final double bottomReserve;

  const _InfoPage({
    required this.data,
    required this.isActive,
    required this.bottomReserve,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 56;

    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: bottomReserve),
      child: Column(
        children: [
          // Visual — top 50%
          Flexible(
            flex: 50,
            child: Center(
              child: data.visual
                  .animate(target: isActive ? 1 : 0)
                  .fade(begin: 0, end: 1, duration: 550.ms)
                  .scale(
                    begin: const Offset(0.88, 0.88),
                    end: const Offset(1.0, 1.0),
                    curve: Curves.easeOutBack,
                    duration: 600.ms,
                  ),
            ),
          ),

          // Text — bottom 50%
          Flexible(
            flex: 50,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Badge
                  _BadgePill(label: data.badge, color: data.glow)
                      .animate(target: isActive ? 1 : 0)
                      .fade(
                          begin: 0, end: 1, delay: 80.ms, duration: 350.ms)
                      .slideX(begin: -0.05, end: 0),
                  const SizedBox(height: 14),

                  // Headline
                  Text(
                    data.headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.0,
                      height: 1.06,
                    ),
                  )
                      .animate(target: isActive ? 1 : 0)
                      .fade(
                          begin: 0,
                          end: 1,
                          delay: 140.ms,
                          duration: 400.ms)
                      .slideY(
                          begin: 0.12,
                          end: 0,
                          curve: Curves.easeOutCubic),
                  const SizedBox(height: 12),

                  // Body
                  Text(
                    data.body,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 14,
                      height: 1.65,
                    ),
                  )
                      .animate(target: isActive ? 1 : 0)
                      .fade(
                          begin: 0,
                          end: 1,
                          delay: 220.ms,
                          duration: 400.ms)
                      .slideY(
                          begin: 0.10,
                          end: 0,
                          curve: Curves.easeOutCubic),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Visual Mockup 1 — Wellness Ring ─────────────────────────────────────────

class _MoodMockup extends StatelessWidget {
  const _MoodMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.78,
                  strokeWidth: 9,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '7.8',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'out of 10',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.32),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Wellness Score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _StatDot(label: 'Mood', value: '8', color: AppColors.primary),
              _Divider(),
              _StatDot(
                  label: 'Sleep',
                  value: '7',
                  color: Color(0xFF0EA5E9)),
              _Divider(),
              _StatDot(
                  label: 'Streak',
                  value: '5d',
                  color: Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "You're doing better than last week",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 11,
                    ),
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

class _StatDot extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatDot(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.33),
                  fontSize: 9)),
        ],
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 24, color: Colors.white.withValues(alpha: 0.08));
}

// ─── Visual Mockup 2 — Maya Chat ─────────────────────────────────────────────

class _ChatMockup extends StatelessWidget {
  const _ChatMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.07)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.primary, Color(0xFF0EA5E9)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.bot,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Maya',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text('Online',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 9.5)),
                    ]),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('CBT mode',
                      style: TextStyle(
                          color: Color(0xFF0EA5E9),
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Bubbles
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _Bubble(
                  text:
                      "Hey! I noticed you've been more anxious lately. Want to talk about it? 💙",
                  isMaya: true,
                ),
                const SizedBox(height: 8),
                _Bubble(
                  text: 'Yeah, exams are getting to me',
                  isMaya: false,
                ),
                const SizedBox(height: 8),
                _TypingIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isMaya;
  const _Bubble({required this.text, required this.isMaya});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMaya ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: 210),
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: isMaya
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.primary.withValues(alpha: 0.85),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                Radius.circular(isMaya ? 4 : 16),
            bottomRight:
                Radius.circular(isMaya ? 16 : 4),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(
                alpha: isMaya ? 0.85 : 1.0),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.25 + i * 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Visual Mockup 3 — Progress / Streak ─────────────────────────────────────

class _ProgressMockup extends StatelessWidget {
  const _ProgressMockup();

  static const _bars = [0.50, 0.35, 0.68, 0.48, 0.80, 0.60, 0.88];
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Streak card
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('🔥',
                    style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '14-day streak',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      "You're on fire — keep going!",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 7-day chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mood — last 7 days',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Avg 7.2',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_bars.length, (i) {
                    final isToday = i == _bars.length - 1;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 24,
                          height: 40 * _bars[i],
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.primary
                                : AppColors.primary
                                    .withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _days[i],
                          style: TextStyle(
                            color: isToday
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.26),
                            fontSize: 9,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Intent Page ─────────────────────────────────────────────────────────────

const _kIntents = [
  {'id': 'anxiety', 'emoji': '😰', 'label': 'Managing anxiety'},
  {'id': 'stress', 'emoji': '📝', 'label': 'CAT & exam pressure'},
  {'id': 'sleep', 'emoji': '😴', 'label': 'Sleep & rest'},
  {'id': 'loneliness', 'emoji': '💙', 'label': 'Loneliness'},
  {'id': 'motivation', 'emoji': '🚀', 'label': 'Staying motivated'},
  {'id': 'finance', 'emoji': '💸', 'label': 'Financial stress (HELB)'},
  {'id': 'self', 'emoji': '💪', 'label': 'Self-confidence'},
  {'id': 'grief', 'emoji': '🌹', 'label': 'Grief & loss'},
  {'id': 'attachment', 'emoji': '🏢', 'label': 'Attachment pressure'},
  {'id': 'explore', 'emoji': '✨', 'label': 'Just exploring'},
];

class _IntentPage extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  final bool isActive;
  final double bottomReserve;

  const _IntentPage({
    required this.selected,
    required this.onSelect,
    required this.isActive,
    required this.bottomReserve,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 60;
    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: bottomReserve),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BadgePill(label: 'Personalise Maya', color: AppColors.primary)
                .animate(target: isActive ? 1 : 0)
                .fade(begin: 0, end: 1, delay: 60.ms, duration: 320.ms),
            const SizedBox(height: 12),
            Text(
              'What brings\nyou here?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.8,
                height: 1.06,
              ),
            )
                .animate(target: isActive ? 1 : 0)
                .fade(
                    begin: 0, end: 1, delay: 100.ms, duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 6),
            Text(
              'Maya adapts her approach to what matters most to you.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
                height: 1.5,
              ),
            )
                .animate(target: isActive ? 1 : 0)
                .fade(
                    begin: 0, end: 1, delay: 160.ms, duration: 320.ms),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 2.5,
                physics: const NeverScrollableScrollPhysics(),
                children: _kIntents.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  final id = item['id']!;
                  final isSel = selected == id;
                  return GestureDetector(
                    onTap: () => onSelect(id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primary.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.09),
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(item['emoji']!,
                              style: const TextStyle(fontSize: 17)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['label']!,
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : Colors.white
                                        .withValues(alpha: 0.60),
                                fontSize: 11.5,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(target: isActive ? 1 : 0)
                      .fade(
                          begin: 0,
                          end: 1,
                          delay: (200 + i * 40).ms,
                          duration: 300.ms)
                      .slideY(begin: 0.07, end: 0);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Time Page ────────────────────────────────────────────────────────────────

const _kTimes = [
  {
    'id': '5min',
    'emoji': '⚡',
    'label': '5 minutes',
    'sub': 'Quick daily check-ins'
  },
  {
    'id': '10min',
    'emoji': '🌱',
    'label': '10 minutes',
    'sub': 'Balanced daily practice'
  },
  {
    'id': '20min',
    'emoji': '🧘',
    'label': '20 minutes',
    'sub': 'Deeper exploration'
  },
  {
    'id': 'flexible',
    'emoji': '🌊',
    'label': 'Flexible',
    'sub': 'Whenever I need it'
  },
];

class _TimePage extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  final bool isActive;
  final double bottomReserve;

  const _TimePage({
    required this.selected,
    required this.onSelect,
    required this.isActive,
    required this.bottomReserve,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 60;
    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: bottomReserve),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BadgePill(label: 'Almost there!', color: AppColors.primary)
                .animate(target: isActive ? 1 : 0)
                .fade(begin: 0, end: 1, delay: 60.ms, duration: 320.ms),
            const SizedBox(height: 12),
            Text(
              'How much time\ncan you give?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.8,
                height: 1.06,
              ),
            )
                .animate(target: isActive ? 1 : 0)
                .fade(
                    begin: 0, end: 1, delay: 100.ms, duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 6),
            Text(
              'Even 5 minutes a day makes a real difference.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
                height: 1.5,
              ),
            )
                .animate(target: isActive ? 1 : 0)
                .fade(
                    begin: 0, end: 1, delay: 160.ms, duration: 320.ms),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                children: List.generate(_kTimes.length, (i) {
                  final item = _kTimes[i];
                  final id = item['id']!;
                  final isSel = selected == id;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => onSelect(id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 0),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.primary
                                    .withValues(alpha: 0.14)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSel
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.09),
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(item['emoji']!,
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item['label']!,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                            alpha: isSel ? 1.0 : 0.78),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      item['sub']!,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.36),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 160),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSel
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSel
                                        ? AppColors.primary
                                        : Colors.white
                                            .withValues(alpha: 0.20),
                                    width: 2,
                                  ),
                                ),
                                child: isSel
                                    ? const Icon(Icons.check_rounded,
                                        size: 13, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(target: isActive ? 1 : 0)
                          .fade(
                              begin: 0,
                              end: 1,
                              delay: (200 + i * 60).ms,
                              duration: 300.ms)
                          .slideY(begin: 0.07, end: 0),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
        border:
            Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({super.key});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28)),
            ),
            child: const Icon(LucideIcons.brain,
                color: AppColors.primary, size: 14),
          ),
          const SizedBox(width: 8),
          const Text(
            'MindBridge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      );
}

class _CTAButton extends StatelessWidget {
  final String label;
  final Color glow;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _CTAButton({
    required this.label,
    required this.glow,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (_, child) {
          final pulse = pulseController.value;
          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.22 + pulse * 0.16),
                  blurRadius: 20 + pulse * 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                label,
                key: ValueKey(label),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.arrowRight,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
