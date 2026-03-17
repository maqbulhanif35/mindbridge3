import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Sends transactional emails via EmailJS (free, no custom domain required).
///
/// Setup (5 min):
///   1. Sign up at https://www.emailjs.com — free plan gives 200 emails/month.
///   2. Dashboard → Email Services → Add New Service → Gmail → connect your
///      Gmail account. Copy the **Service ID**.
///   3. Dashboard → Email Templates → Create New Template.
///      Set "To Email" field to {{to_email}}
///      Use these variables in the body: {{to_name}}  {{app_name}}  {{app_url}}
///      Copy the **Template ID**.
///   4. Dashboard → Account → API Keys — copy your **Public Key**.
///   5. Add to .env (local) and Vercel Environment Variables (production):
///        EMAILJS_SERVICE_ID=service_xxxxxxx
///        EMAILJS_TEMPLATE_ID=template_xxxxxxx
///        EMAILJS_PUBLIC_KEY=xxxxxxxxxxxxxxxxxxxx
///   6. Rebuild: flutter build web --dart-define=EMAILJS_SERVICE_ID=... etc.
class EmailService {
  // Keys injected at build-time via --dart-define (Vercel build command)
  static const _compiledServiceId =
      String.fromEnvironment('EMAILJS_SERVICE_ID');
  static const _compiledTemplateId =
      String.fromEnvironment('EMAILJS_TEMPLATE_ID');
  static const _compiledPublicKey =
      String.fromEnvironment('EMAILJS_PUBLIC_KEY');

  static String get _serviceId => _compiledServiceId.isNotEmpty
      ? _compiledServiceId
      : dotenv.maybeGet('EMAILJS_SERVICE_ID') ?? '';

  static String get _templateId => _compiledTemplateId.isNotEmpty
      ? _compiledTemplateId
      : dotenv.maybeGet('EMAILJS_TEMPLATE_ID') ?? '';

  static String get _publicKey => _compiledPublicKey.isNotEmpty
      ? _compiledPublicKey
      : dotenv.maybeGet('EMAILJS_PUBLIC_KEY') ?? '';

  /// Sends a branded welcome email after the user's account is verified.
  /// Fire-and-forget — never awaited so it cannot block the UI.
  static Future<void> sendWelcomeEmail({
    required String toEmail,
    required String name,
  }) async {
    if (_serviceId.isEmpty || _templateId.isEmpty || _publicKey.isEmpty) {
      // Keys not configured yet — silently skip.
      return;
    }
    try {
      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey, // EmailJS calls the public key "user_id"
          'template_params': {
            'to_name': name,
            'to_email': toEmail,
            'app_name': 'MindBridge',
            'app_url': 'https://mindbridge-teal.vercel.app',
          },
        }),
      );
    } catch (_) {
      // Never let email failure block the auth flow
    }
  }
}
