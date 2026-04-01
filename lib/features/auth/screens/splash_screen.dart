import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _minDelayDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    // Minimum splash display time
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _minDelayDone = true;
      _tryNavigate();
    });
  }

  void _tryNavigate() {
    if (_navigated || !mounted) return;
    final auth = ref.read(authProvider);

    // Still loading — wait for the listener to fire
    if (auth.status == AuthStatus.initial || auth.status == AuthStatus.loading) return;

    _navigated = true;
    if (auth.isPendingVerification) {
      context.go(AppRoutes.verifyEmail);
    } else if (auth.isAuthenticated) {
      final user = auth.user;
      if (user?.onboardingCompleted == false) {
        context.go(AppRoutes.onboarding);
      } else if (user?.isAdmin == true) {
        context.go(AppRoutes.adminDashboard);
      } else {
        context.go(AppRoutes.home);
      }
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes — navigate as soon as auth resolves AND min delay is done
    ref.listen<AuthState>(authProvider, (_, next) {
      if (!_minDelayDone) return; // still showing splash animation
      if (next.status == AuthStatus.initial || next.status == AuthStatus.loading) return;
      _tryNavigate();
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ─── Logo Mark ─────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: Colors.white,
                  size: 48,
                ),
              )
                  .animate()
                  .scale(
                    duration: 700.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0.5, 0.5),
                  )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ─── App Name ──────────────────────────────
              const Text(
                'MindBridge',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

              const SizedBox(height: 8),

              // ─── Tagline ───────────────────────────────
              Text(
                'Your Bridge to Better Mental Health',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.85),
                ),
              )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

              const SizedBox(height: 60),

              // ─── Loading Indicator ─────────────────────
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withOpacity(0.7),
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
