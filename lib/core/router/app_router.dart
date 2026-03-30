import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/mood/screens/mood_tracker_screen.dart';
import '../../features/mood/screens/mood_analytics_screen.dart';
import '../../features/journal/screens/journal_screen.dart';
import '../../features/journal/screens/journal_entry_screen.dart';
import '../../features/mindfulness/screens/mindfulness_screen.dart';
import '../../features/mindfulness/screens/breathing_screen.dart';
import '../../features/resources/screens/resources_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/wellness/screens/wellness_screen.dart';
import '../../features/wellness/screens/wellness_plan_screen.dart';
import '../../features/crisis/screens/crisis_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../shared/widgets/main_shell.dart';

// ─── Route Names ──────────────────────────────────────────
abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String moodTracker = '/mood/tracker';
  static const String moodAnalytics = '/mood/analytics';
  static const String journal = '/journal';
  static const String journalEntry = '/journal/entry';
  static const String mindfulness = '/mindfulness';
  static const String breathing = '/mindfulness/breathing';
  static const String resources = '/resources';
  static const String community = '/community';
  static const String wellness = '/wellness';
  static const String wellnessPlan = '/wellness/plan';
  static const String crisis = '/crisis';
  static const String profile = '/profile';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
}

// ─── Auth Listenable ──────────────────────────────────────
// Wraps AuthState in a ChangeNotifier so GoRouter can refresh
// without recreating the entire router on every state change.

class _AuthListenable extends ChangeNotifier {
  AuthState _state;
  _AuthListenable(this._state);

  AuthState get state => _state;

  void update(AuthState newState) {
    _state = newState;
    notifyListeners();
  }
}

// ─── Router Provider ──────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref.read(authProvider));

  // Listen for auth changes and notify GoRouter — does NOT recreate the router
  ref.listen<AuthState>(authProvider, (_, next) => listenable.update(next));
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = listenable.state;
      final status = authState.status;
      final isLoading =
          status == AuthStatus.loading || status == AuthStatus.initial;
      final isAuthenticated = authState.isAuthenticated;
      final isPendingVerification = authState.isPendingVerification;
      final location = state.matchedLocation;

      final isPendingReset = status == AuthStatus.pendingReset;
      final isResetVerified = status == AuthStatus.resetVerified;
      final isInResetFlow = isPendingReset || isResetVerified;

      final isOnSplash = location == AppRoutes.splash;
      final isOnVerify = location == AppRoutes.verifyEmail;
      final isOnForgot = location == AppRoutes.forgotPassword;
      final isOnOnboarding = location == AppRoutes.onboarding;
      final isOnAuthPage = location == AppRoutes.login ||
          location == AppRoutes.register;

      // Let splash handle initial routing
      if (isOnSplash) return null;

      // Still loading — stay on splash
      if (isLoading) return AppRoutes.splash;

      // Password reset flow — keep them on the forgot-password screen
      if (isInResetFlow && !isOnForgot) return AppRoutes.forgotPassword;
      if (isInResetFlow && isOnForgot) return null;

      // Pending email verification — force to verify screen
      if (isPendingVerification && !isOnVerify) return AppRoutes.verifyEmail;

      // Verified user on verify screen — move along
      if (isAuthenticated && isOnVerify) return AppRoutes.home;

      // Not authenticated — allow forgot-password and auth pages through
      if (!isAuthenticated && !isPendingVerification && !isInResetFlow &&
          !isOnAuthPage && !isOnForgot) {
        return AppRoutes.login;
      }

      // Authenticated but somehow on forgot-password → go home
      if (isAuthenticated && isOnForgot) return AppRoutes.home;

      // Authenticated but on a login/register page — go home
      if (isAuthenticated && isOnAuthPage) return AppRoutes.home;

      // Authenticated + onboarding done but still on onboarding → home
      if (isAuthenticated &&
          authState.user?.onboardingCompleted == true &&
          isOnOnboarding) {
        return AppRoutes.home;
      }

      // Authenticated + onboarding not done + on home → onboarding
      if (isAuthenticated &&
          authState.user?.onboardingCompleted == false &&
          location == AppRoutes.home) {
        return AppRoutes.onboarding;
      }

      return null;
    },
    routes: [
      // ─── Splash ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      // ─── Auth Routes ─────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ─── Main Shell (Bottom Nav) ─────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.chat,
            builder: (_, __) => const ChatScreen(),
          ),
          GoRoute(
            path: AppRoutes.moodTracker,
            builder: (_, __) => const MoodTrackerScreen(),
          ),
          GoRoute(
            path: AppRoutes.moodAnalytics,
            builder: (_, __) => const MoodAnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.journal,
            builder: (_, __) => const JournalScreen(),
          ),
          GoRoute(
            path: AppRoutes.mindfulness,
            builder: (_, __) => const MindfulnessScreen(),
          ),
          GoRoute(
            path: AppRoutes.resources,
            builder: (_, __) => const ResourcesScreen(),
          ),
          GoRoute(
            path: AppRoutes.community,
            builder: (_, __) => const CommunityScreen(),
          ),
          GoRoute(
            path: AppRoutes.wellness,
            builder: (_, __) => const WellnessScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // ─── Standalone Routes (Full Screen) ────────────
      GoRoute(
        path: AppRoutes.journalEntry,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return JournalEntryScreen(existingEntry: extra?['entry']);
        },
      ),
      GoRoute(
        path: AppRoutes.breathing,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BreathingScreen(exerciseId: extra?['exerciseId'] as String?);
        },
      ),
      GoRoute(
        path: AppRoutes.wellnessPlan,
        builder: (_, __) => const WellnessPlanScreen(),
      ),
      GoRoute(
        path: AppRoutes.crisis,
        builder: (_, __) => const CrisisScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
