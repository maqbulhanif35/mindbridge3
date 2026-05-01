import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';
import '../services/email_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

String _generateOtp() => (Random.secure().nextInt(900000) + 100000).toString();

// ─── Auth Status ──────────────────────────────────────────

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  pendingVerification, // signed up but email not yet confirmed
  pendingReset, // forgot password — OTP sent, waiting for code entry
  resetVerified, // OTP verified — waiting for new password input
  error,
}

// ─── Auth State ───────────────────────────────────────────

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final String? pendingEmail; // email awaiting verification

  /// Stores registration form data in-memory while waiting for OTP.
  /// Cleared on verification success, logout, or cancel.
  /// NOT persisted across full page-reloads by design — if the user
  /// refreshes before verifying, they must register again (correct behavior).
  final Map<String, dynamic>? pendingRegistrationData;

  /// Stores OTP data for password reset flow (in-memory only).
  final Map<String, dynamic>? pendingResetData;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.pendingEmail,
    this.pendingRegistrationData,
    this.pendingResetData,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    String? pendingEmail,
    Map<String, dynamic>? pendingRegistrationData,
    Map<String, dynamic>? pendingResetData,
    bool clearError = false,
    bool clearPendingData = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        pendingEmail: pendingEmail ?? this.pendingEmail,
        pendingRegistrationData: clearPendingData
            ? null
            : (pendingRegistrationData ?? this.pendingRegistrationData),
        pendingResetData: pendingResetData ?? this.pendingResetData,
      );

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isPendingVerification => status == AuthStatus.pendingVerification;
  bool get isPendingReset => status == AuthStatus.pendingReset;
  bool get isResetVerified => status == AuthStatus.resetVerified;
}

// ─── Auth Notifier ────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  // Suppresses auth stream events while register() or verifyOtp() are
  // in flight — prevents those methods' own state writes from being
  // overridden by a concurrent signedIn / userUpdated stream event.
  bool _suppressAuthStream = false;

  void _init() {
    final session = SupabaseService.currentSession;
    if (session != null) {
      final user = session.user;
      if (user.emailConfirmedAt != null) {
        // Only trust a confirmed session — load the user's profile
        _loadProfile(user.id);
      } else {
        // Unconfirmed session (e.g. Supabase email confirm enabled but user
        // never clicked the Supabase link). Since we now own OTP verification
        // through our backend, treat this as unauthenticated so the user
        // goes back through the proper registration + OTP flow.
        // Sign out the stale session silently.
        SupabaseService.signOut().ignore();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    SupabaseService.authStream.listen((data) {
      if (_suppressAuthStream) return;
      if (state.isPendingReset || state.isResetVerified) return;

      final event = data.event;
      final session = data.session;

      if (event == sb.AuthChangeEvent.signedIn && session != null) {
        // Never let a signedIn event override an ongoing OTP verification flow
        if (state.isPendingVerification) return;
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
        final user = session.user;
        if (user.emailConfirmedAt != null) {
          _loadProfile(user.id);
        }
      } else if (event == sb.AuthChangeEvent.signedOut) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  // ─── Load / Create Profile ────────────────────────────

  Future<void> _loadProfile(String userId) async {
    try {
      final profile = await SupabaseService.getProfile(userId);
      if (profile != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: profile,
          clearError: true,
        );
        // Schedule personalized notifications using their onboarding preferences.
        NotificationService().schedulePersonalizedCheckIn(profile);
        NotificationService().schedulePersonalizedStreakProtection(profile);
      } else {
        // New user (Google OAuth) — create a default profile from auth metadata.
        // For email/password new users this path is only reached after OTP
        // verification; their profile is usually already written by register().
        final sbUser = SupabaseService.currentUser!;
        final meta = sbUser.userMetadata ?? {};
        final rawName = (meta['full_name'] ?? meta['name'] ?? '') as String;
        final newProfile = UserModel(
          id: userId,
          email: sbUser.email ?? '',
          name: rawName.isNotEmpty ? rawName : 'Student',
          createdAt: DateTime.now(),
        );
        await SupabaseService.upsertProfile(newProfile);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: newProfile,
          clearError: true,
        );
        // Welcome email for Google OAuth new users.
        // Email/password users get it from verifyOtp() instead.
        if (!_suppressAuthStream) {
          EmailService.sendWelcomeEmail(
            toEmail: newProfile.email,
            name: newProfile.displayName,
          );
        }
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

      if (user.emailConfirmedAt == null) {
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          pendingEmail: normalizedEmail,
        );
        return true;
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
  //
  // ARCHITECTURE: We do NOT create a Supabase account here.
  // We only send our backend OTP and hold the form data in memory.
  // This prevents the refresh-bypass bug where an unverified Supabase
  // session would let users skip the OTP gate entirely.
  // The Supabase account is created inside verifyRegistrationOtp() AFTER
  // the user proves ownership of their email address.

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
      final otpCode = _generateOtp();
      final otpSentAt = DateTime.now().millisecondsSinceEpoch;

      final otpSent = await EmailService.sendOtp(
        toEmail: normalizedEmail,
        name: name.trim(),
        code: otpCode,
        type: 'verify',
      );

      if (!otpSent) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Could not send verification code. Check your email address and try again.',
        );
        return false;
      }

      // Hold form data + OTP in-memory until the user enters the code
      state = AuthState(
        status: AuthStatus.pendingVerification,
        pendingEmail: normalizedEmail,
        pendingRegistrationData: {
          'name': name.trim(),
          'password': password,
          'university': university,
          'yearOfStudy': yearOfStudy,
          'faculty': faculty,
          'goals': goals ?? <String>[],
          'stressors': stressors ?? <String>[],
          'mayaPersonality': mayaPersonality,
          'checkInTime': checkInTime,
          'therapyExperience': therapyExperience,
          'otpCode': otpCode,
          'otpSentAt': otpSentAt,
        },
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Registration failed. Please try again.',
      );
      return false;
    }
  }

  // ─── Registration OTP Verification ───────────────────
  //
  // Called after the user enters the 6-digit code from their email.
  // Only on a valid code do we create the Supabase account + profile.

  Future<bool> verifyRegistrationOtp(String code) async {
    final email = state.pendingEmail;
    final regData = state.pendingRegistrationData;
    if (email == null || regData == null) return false;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    _suppressAuthStream = true;

    try {
      // Step 1 — Verify code against the in-memory OTP
      final storedCode = regData['otpCode'] as String?;
      final sentAt = regData['otpSentAt'] as int?;
      final expired = sentAt != null &&
          DateTime.now().millisecondsSinceEpoch - sentAt >
              const Duration(minutes: 15).inMilliseconds;

      if (storedCode == null || code.trim() != storedCode || expired) {
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          errorMessage: expired
              ? 'Code expired. Please request a new one.'
              : 'Invalid or expired code. Try resending.',
        );
        return false;
      }

      // Step 2 — Create Supabase account (email is proven by this point)
      final name = regData['name'] as String;
      final password = regData['password'] as String;

      sb.AuthResponse? response;
      try {
        response = await SupabaseService.signUp(
          email: email,
          password: password,
          name: name,
        ).timeout(const Duration(seconds: 15));
      } on sb.AuthException catch (e) {
        // Account may already exist from a previous partial attempt
        if (e.message.toLowerCase().contains('already registered') ||
            e.code == 'user_already_exists') {
          response = null; // fall through to signIn below
        } else {
          rethrow;
        }
      }

      // Get a valid session — either from signUp or by signing in
      String? userId = response?.user?.id;
      if (response?.session == null || userId == null) {
        final signIn = await SupabaseService.signIn(
          email: email,
          password: password,
        );
        if (signIn.user == null) {
          state = state.copyWith(
            status: AuthStatus.pendingVerification,
            errorMessage: 'Account creation failed. Please try again.',
          );
          return false;
        }
        userId = signIn.user!.id;
      }

      // Step 3 — Write full profile row
      try {
        await SupabaseService.upsertProfile(UserModel(
          id: userId,
          email: email,
          name: name,
          university: regData['university'] as String?,
          yearOfStudy: regData['yearOfStudy'] as int?,
          faculty: regData['faculty'] as String?,
          goals: List<String>.from(regData['goals'] as List),
          stressors: List<String>.from(regData['stressors'] as List),
          mayaPersonality: regData['mayaPersonality'] as String? ?? 'warm',
          checkInTime: regData['checkInTime'] as String? ?? 'any',
          therapyExperience: regData['therapyExperience'] as String? ?? 'never',
          createdAt: DateTime.now(),
        )).timeout(const Duration(seconds: 8));
      } catch (_) {}

      // Step 4 — Load profile into state (sets authenticated)
      await _loadProfile(userId);

      // Step 5 — Fire welcome email (non-blocking)
      final profile = state.user;
      if (profile != null) {
        EmailService.sendWelcomeEmail(
          toEmail: profile.email,
          name: profile.displayName,
        );
      }

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
        errorMessage: 'Verification failed. Please try again.',
      );
      return false;
    } finally {
      _suppressAuthStream = false;
    }
  }

  // ─── Email Verification ───────────────────────────────

  /// Resend the signup OTP — generates a fresh code and updates state.
  Future<bool> resendVerificationEmail() async {
    final email = state.pendingEmail;
    if (email == null) return false;
    final regData = state.pendingRegistrationData ?? {};
    final name = (regData['name'] as String?) ?? 'there';

    final otpCode = _generateOtp();
    final otpSentAt = DateTime.now().millisecondsSinceEpoch;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final ok = await EmailService.sendOtp(
        toEmail: email,
        name: name,
        code: otpCode,
        type: 'verify',
      );
      // Update the stored code so the new one is what gets verified
      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        pendingRegistrationData: {
          ...regData,
          'otpCode': otpCode,
          'otpSentAt': otpSentAt,
        },
      );
      return ok;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        errorMessage: 'Failed to resend email. Try again shortly.',
      );
      return false;
    }
  }

  /// Poll Supabase to check if the user clicked the verification link.
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
    state = const AuthState(
        status: AuthStatus.unauthenticated); // clears all pending data
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
    try {
      await SupabaseService.upsertProfile(updated);
      // Re-schedule notifications with the final onboarding preferences
      // (goals, check-in time, stressors are now set).
      NotificationService().schedulePersonalizedCheckIn(updated);
      NotificationService().schedulePersonalizedStreakProtection(updated);
    } catch (_) {}
  }

  // ─── OTP Verification ─────────────────────────────────

  Future<bool> verifyOtp(String code) async {
    final email = state.pendingEmail;
    if (email == null) return false;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    // Suppress stream so the signedIn event fired by verifyOTP doesn't race
    // our own _loadProfile call below.
    _suppressAuthStream = true;
    try {
      final response = await SupabaseService.verifyOtp(
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

      // Send welcome email now that account is fully created and verified
      final profile = state.user;
      if (profile != null) {
        EmailService.sendWelcomeEmail(
          toEmail: profile.email,
          name: profile.displayName,
        );
      }
      return true;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        errorMessage: 'Verification failed. Please try again.',
      );
      return false;
    } finally {
      _suppressAuthStream = false;
    }
  }

  // ─── Forgot Password Flow ─────────────────────────────

  /// Step 1 — Generate a 6-digit OTP, send it via Resend email.
  /// Stores the OTP and user ID in state for later verification.
  Future<bool> forgotPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    _suppressAuthStream = true;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final userId = await SupabaseService.getUserIdByEmail(normalizedEmail);
      if (userId == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearError: true,
        );
        return true;
      }

      final otpCode = _generateOtp();
      final otpSentAt = DateTime.now().millisecondsSinceEpoch;

      final name = await SupabaseService.getUserNameById(userId) ?? 'there';

      final emailSent = await EmailService.sendOtp(
        toEmail: normalizedEmail,
        name: name,
        code: otpCode,
        type: 'reset',
      );

      if (!emailSent) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Could not send reset code. Check your email and try again.',
        );
        return false;
      }

      state = AuthState(
        status: AuthStatus.pendingReset,
        pendingEmail: normalizedEmail,
        pendingResetData: {
          'otpCode': otpCode,
          'otpSentAt': otpSentAt,
          'userId': userId,
        },
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Password reset failed. Please try again.',
      );
      return false;
    } finally {
      _suppressAuthStream = false;
    }
  }

  /// Step 2 — Verify the OTP code against the in-memory stored code.
  Future<bool> verifyResetOtp(String code) async {
    final email = state.pendingEmail;
    final resetData = state.pendingResetData;
    if (email == null || resetData == null) return false;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      // Verify against in-memory OTP
      final storedCode = resetData['otpCode'] as String?;
      final sentAt = resetData['otpSentAt'] as int?;
      final expired = sentAt != null &&
          DateTime.now().millisecondsSinceEpoch - sentAt >
              const Duration(minutes: 15).inMilliseconds;

      if (storedCode == null || code.trim() != storedCode || expired) {
        state = state.copyWith(
          status: AuthStatus.pendingReset,
          errorMessage: expired
              ? 'Code expired. Please request a new one.'
              : 'Invalid or expired code. Try resending.',
        );
        return false;
      }

      // OTP verified — move to password input step
      state = state.copyWith(
        status: AuthStatus.resetVerified,
        clearError: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.pendingReset,
        errorMessage: 'Verification failed. Please try again.',
      );
      return false;
    }
  }

  /// Step 3 — Update the password via Supabase Admin API.
  Future<bool> resetPassword(String newPassword) async {
    final resetData = state.pendingResetData;
    if (resetData == null) return false;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final userId = resetData['userId'] as String?;
      final email = state.pendingEmail;
      if (userId == null || email == null) {
        state = state.copyWith(
          status: AuthStatus.resetVerified,
          errorMessage: 'Reset session expired. Please try again.',
        );
        return false;
      }

      final updated = await SupabaseService.updatePasswordViaAdmin(
          userId, email, newPassword);

      if (!updated) {
        state = state.copyWith(
          status: AuthStatus.resetVerified,
          errorMessage: 'Failed to update password. Please try again.',
        );
        return false;
      }

      // Success — clear state and return to unauthenticated
      state = const AuthState(status: AuthStatus.unauthenticated);
      return true;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.resetVerified,
        errorMessage: 'Failed to update password. Please try again.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Abort the forgot-password flow and return to unauthenticated.
  /// Call this when the user explicitly leaves the forgot-password screen.
  void cancelReset() {
    state = const AuthState(status: AuthStatus.unauthenticated);
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
