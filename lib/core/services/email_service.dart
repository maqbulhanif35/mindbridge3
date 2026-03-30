import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─────────────────────────────────────────────────────────
// EmailService — calls the MindBridge Dart Frog backend to
// send transactional emails (welcome + OTP) via Gmail SMTP.
// ─────────────────────────────────────────────────────────

class EmailService {
  static String get _backendUrl =>
      dotenv.maybeGet('BACKEND_URL') ?? 'http://localhost:3001';

  static Future<bool> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$_backendUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return res.statusCode == 200;
    } catch (e) {
      // Never let email failure block the auth flow
      return false;
    }
  }

  /// Send a branded welcome email after account verification.
  /// Fire-and-forget — call with unawaited() so it won't block the UI.
  static Future<void> sendWelcomeEmail({
    required String toEmail,
    required String name,
  }) async {
    await _post('/api/email/welcome', {'email': toEmail, 'name': name});
  }

  /// Send a 6-digit OTP to [toEmail].
  /// [type] must be 'reset' (password reset) or 'verify' (email verification).
  /// Returns true if the backend accepted the request.
  static Future<bool> sendOtp({
    required String toEmail,
    required String name,
    required String type, // 'reset' | 'verify'
  }) =>
      _post('/api/email/otp', {'email': toEmail, 'name': name, 'type': type});

  /// Verify an OTP code with the backend.
  /// Returns true if the code is valid and has not expired.
  static Future<bool> verifyOtp({
    required String email,
    required String code,
  }) =>
      _post('/api/email/otp/verify', {'email': email, 'code': code});
}
