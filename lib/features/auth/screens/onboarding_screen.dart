import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';

// ─── Page Data ────────────────────────────────────────────

class _Page {
  final String emoji;
  final String headline;
  final String body;
  final String stat;
  final String statLabel;
  final List<Color> colors;
  final List<Color> orbs;

  const _Page({
    required this.emoji,
    required this.headline,
    required this.body,
    required this.stat,
    required this.statLabel,
    required this.colors,
    required this.orbs,
  });
}

const _pages = [
  _Page(
    emoji: '🤗',
    headline: "You're not\nalone.",
    body: '69% of students face mental health challenges. MindBridge is your private space to breathe, reflect, and grow.',
    stat: '69%',
    statLabel: 'of students struggle\nsilently',
    colors: [Color(0xFF011A19), Color(0xFF023330), Color(0xFF012420)],
    orbs: [Color(0xFF00BEB4), Color(0xFF0EA5E9)],
  ),
  _Page(
    emoji: '🤖',
    headline: "Meet Maya,\nyour AI ally.",
    body: 'Trained in CBT, DBT & mindfulness. Maya listens 24/7 without judgment and guides you through whatever you\'re facing.',
    stat: '24/7',
    statLabel: 'Always available,\nnever judgmental',
    colors: [Color(0xFF011520), Color(0xFF012D2B), Color(0xFF011A19)],
    orbs: [Color(0xFF00BEB4), Color(0xFF0EA5E9)],
  ),
  _Page(
    emoji: '🌱',
    headline: "Track, grow,\nthrive.",
    body: 'Log moods, journal thoughts, practice mindfulness and watch your progress unfold with beautiful insights.',
    stat: '100%',
    statLabel: 'Private & secure,\nalways yours',
    colors: [Color(0xFF011A19), Color(0xFF012920), Color(0xFF011520)],
    orbs: [Color(0xFFF59E0B), Color(0xFF00BEB4)],
  ),
];

// ─── Onboarding Screen ────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _current = 0;

  late AnimationController _orbController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _orbController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_current < _pages.length - 1) {
      await _pageController.animateToPage(
        _current + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(authProvider.notifier).completeOnboarding();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: page.colors,
          ),
        ),
        child: Stack(
          children: [
            // ─── Animated Orbs ──────────────────────────
            ..._buildOrbs(page, size),

            // ─── Page Content ───────────────────────────
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _current = i),
              itemCount: _pages.length,
              itemBuilder: (_, i) => _PageContent(
                page: _pages[i],
                floatController: _floatController,
                isActive: i == _current,
              ),
            ),

            // ─── Top Controls ───────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo mark
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.brain,
                              color: Colors.white, size: 14),
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
                    ),
                    // Skip
                    if (_current < _pages.length - 1)
                      GestureDetector(
                        onTap: _finish,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ─── Bottom Controls ────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _current ? 28 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _current
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),

                      // CTA Button
                      _GlowButton(
                        label: _current == _pages.length - 1
                            ? "Let's begin"
                            : 'Continue',
                        colors: page.orbs,
                        onTap: _next,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOrbs(_Page page, Size size) {
    return [
      // Large orb top-right
      AnimatedBuilder(
        animation: _orbController,
        builder: (_, __) {
          final t = _orbController.value;
          return Positioned(
            top: -80 + math.sin(t * 2 * math.pi) * 30,
            right: -60 + math.cos(t * 2 * math.pi) * 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: size.width * 0.65,
              height: size.width * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    page.orbs[0].withValues(alpha: 0.35),
                    page.orbs[0].withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      // Medium orb bottom-left
      AnimatedBuilder(
        animation: _orbController,
        builder: (_, __) {
          final t = _orbController.value;
          return Positioned(
            bottom: -40 + math.cos(t * 2 * math.pi + 1) * 25,
            left: -40 + math.sin(t * 2 * math.pi + 1) * 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: size.width * 0.55,
              height: size.width * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    page.orbs[1].withValues(alpha: 0.28),
                    page.orbs[1].withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}

// ─── Page Content ─────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _Page page;
  final AnimationController floatController;
  final bool isActive;

  const _PageContent({
    required this.page,
    required this.floatController,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 140),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80),

          // ─── Floating Emoji ──────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: floatController,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -8 + floatController.value * 16),
                child: child,
              ),
              child: Container(
                width: size.width * 0.38,
                height: size.width * 0.38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: page.orbs[0].withValues(alpha: 0.4),
                      blurRadius: 60,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    page.emoji,
                    style: TextStyle(fontSize: size.width * 0.16),
                  ),
                ),
              ),
            )
                .animate(target: isActive ? 1 : 0)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .fade(begin: 0, end: 1, duration: 400.ms),
          ),

          const SizedBox(height: 44),

          // ─── Stat Badge ──────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  page.stat,
                  style: TextStyle(
                    color: page.orbs[0],
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  page.statLabel.replaceAll('\n', ' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
              .animate(target: isActive ? 1 : 0)
              .fade(begin: 0, end: 1, delay: 100.ms, duration: 400.ms)
              .slideX(begin: -0.1, end: 0),

          const SizedBox(height: 20),

          // ─── Headline ────────────────────────────────
          Text(
            page.headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.1,
            ),
          )
              .animate(target: isActive ? 1 : 0)
              .fade(begin: 0, end: 1, delay: 150.ms, duration: 450.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          // ─── Body ────────────────────────────────────
          Text(
            page.body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 16,
              height: 1.65,
              fontWeight: FontWeight.w400,
            ),
          )
              .animate(target: isActive ? 1 : 0)
              .fade(begin: 0, end: 1, delay: 250.ms, duration: 450.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

// ─── Glow Button ──────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _GlowButton({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors[0], colors[1]],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.50),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(LucideIcons.arrowRight,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
