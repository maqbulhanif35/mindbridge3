import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/email_service.dart';

// ─── Auth Status ──────────────────────────────────────────

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  pendingVerification, // signed up but email not yet confirmed
  error,
}

// ─── Auth State ───────────────────────────────────────────

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final String? pendingEmail; // email awaiting verification

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.pendingEmail,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    String? pendingEmail,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        pendingEmail: pendingEmail ?? this.pendingEmail,
      );

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isPendingVerification => status == AuthStatus.pendingVerification;
}

// ─── Auth Notifier ────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() {
    final session = SupabaseService.currentSession;
    if (session != null) {
      final user = session.user;
      // Only restore session if email is confirmed
      if (user.emailConfirmedAt != null) {
        _loadProfile(user.id);
      } else {
        state = AuthState(
          status: AuthStatus.pendingVerification,
          pendingEmail: user.email,
        );
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    SupabaseService.authStream.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == sb.AuthChangeEvent.signedIn && session != null) {
        final user = session.user;
        if (user.emailConfirmedAt != null) {
          _loadProfile(user.id);
        } else {
          state = state.copyWith(
            status: AuthStatus.pendingVerification,
            pendingEmail: user.email,
          );
        }
      } else if (event == sb.AuthChangeEvent.userUpdated && session != null) {
        // Fires when user confirms email
        final user = session.user;
        if (user.emailConfirmedAt != null) {
          _loadProfile(user.id);
        }
      } else if (event == sb.AuthChangeEvent.signedOut) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final profile = await SupabaseService.getProfile(userId);
      if (profile != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: profile,
          clearError: true,
        );
      } else {
        // New user (Google OAuth or email signup) — create a default profile
        final sbUser = SupabaseService.currentUser!;
        final meta = sbUser.userMetadata ?? {};
        final rawName = (meta['full_name'] ?? meta['name'] ?? meta['email'] ?? 'User') as String;
        final name = rawName.trim();
        final newProfile = UserModel(
          id: userId,
          email: sbUser.email ?? '',
          name: name.isNotEmpty ? name : 'Student',
          createdAt: DateTime.now(),
        );
        await SupabaseService.upsertProfile(newProfile);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: newProfile,
          clearError: true,
        );
        // Send welcome email — fire-and-forget, never awaited for UX
        EmailService.sendWelcomeEmail(
          toEmail: newProfile.email,
          name: newProfile.displayName,
        );
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  // ─── Sign In ──────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await SupabaseService.signIn(
        email: normalizedEmail,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Login failed. Please try again.',
        );
        return false;
      }

      // Check email confirmation
      if (user.emailConfirmedAt == null) {
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          pendingEmail: normalizedEmail,
        );
        return true; // Not an error — just needs verification
      }

      await _loadProfile(user.id);
      return true;
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _humanizeAuthError(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Connection error. Check your internet.',
      );
      return false;
    }
  }

  // ─── Sign Up ──────────────────────────────────────────

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? university,
    int? yearOfStudy,
    String? faculty,
    List<String>? goals,
    List<String>? stressors,
    String mayaPersonality = 'warm',
    String checkInTime = 'any',
    String therapyExperience = 'never',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await SupabaseService.signUp(
        email: normalizedEmail,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Sign up failed. Please try again.',
        );
        return false;
      }

      // Create profile row immediately (even before email confirmation)
      final profile = UserModel(
        id: user.id,
        email: normalizedEmail,
        name: name.trim(),
        university: university,
        yearOfStudy: yearOfStudy,
        faculty: faculty,
        goals: goals ?? [],
        stressors: stressors ?? [],
        mayaPersonality: mayaPersonality,
        checkInTime: checkInTime,
        therapyExperience: therapyExperience,
        createdAt: DateTime.now(),
      );
      await SupabaseService.upsertProfile(profile);

      // Email confirmation is disabled in this project → immediate session
      if (response.session != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: profile,
          clearError: true,
        );
      } else {
        // Email confirmation enabled — wait for user to confirm
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          pendingEmail: normalizedEmail,
        );
      }
      return true;
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _humanizeAuthError(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Registration failed. Please try again.',
      );
      return false;
    }
  }

  // ─── Email Verification ───────────────────────────────

  /// Resend OTP email via Supabase auth.
  Future<bool> resendVerificationEmail() async {
    final email = state.pendingEmail;
    if (email == null) return false;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await SupabaseService.sendOtpEmail(email);
      state = state.copyWith(status: AuthStatus.pendingVerification);
      return true;
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        errorMessage: _humanizeAuthError(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        errorMessage: 'Failed to resend email. Try again shortly.',
      );
      return false;
    }
  }

  /// Poll Supabase to check if the user has clicked the verification link.
  Future<bool> checkEmailVerified() async {
    try {
      await SupabaseService.refreshSession();
      final user = SupabaseService.currentUser;
      if (user != null && user.emailConfirmedAt != null) {
        await _loadProfile(user.id);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Google Sign-In ───────────────────────────────────

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await SupabaseService.signInWithGoogle();
      // On web: browser redirects to Google and back — authStateChange handles the rest.
      // On mobile: OAuth popup closes and signedIn event fires automatically.
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _humanizeAuthError(e),
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Google sign-in failed. Please try again.',
      );
    }
  }

  // ─── Sign Out ─────────────────────────────────────────

  Future<void> logout() async {
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ─── Update Profile ───────────────────────────────────

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    try {
      final updated = await SupabaseService.updateProfile(userId, data);
      if (updated != null) {
        state = state.copyWith(user: updated);
      }
    } catch (_) {}
  }

  Future<void> completeOnboarding() async {
    if (state.user == null) return;
    final updated = state.user!.copyWith(onboardingCompleted: true);
    state = state.copyWith(user: updated);
    // Persist so re-login doesn't loop back to onboarding
    try {
      await SupabaseService.upsertProfile(updated);
    } catch (_) {}
  }

  // ─── OTP Verification ─────────────────────────────────

  Future<bool> verifyOtp(String code) async {
    final email = state.pendingEmail;
    if (email == null) return false;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await SupabaseService.verifyEmailOtp(
        email: email,
        token: code,
      );
      final user = response.user;
      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          errorMessage: 'Invalid or expired code. Try resending.',
        );
        return false;
      }
      await _loadProfile(user.id);
      return true;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        errorMessage: 'Verification failed. Please try again.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ─── Error Humanizer ──────────────────────────────────

  String _humanizeAuthError(sb.AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();

    if (code == 'over_email_send_rate_limit' ||
        msg.contains('email rate limit') ||
        msg.contains('rate limit')) {
      return 'Too many emails sent. Please wait a few minutes before trying again.';
    }
    if (code == 'user_already_exists' || msg.contains('already registered')) {
      return 'An account with this email already exists. Try logging in instead.';
    }
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login') ||
        msg.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
      return 'Please verify your email address before logging in.';
    }
    if (code == 'weak_password' || msg.contains('weak password')) {
      return 'Password is too weak. Use at least 8 characters with letters and numbers.';
    }
    if (code == 'signup_disabled') {
      return 'New registrations are temporarily disabled. Please try again later.';
    }
    if (code == 'email_address_invalid' || msg.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Connection error. Check your internet and try again.';
    }
    return e.message;
  }
}

// ─── Providers ────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
