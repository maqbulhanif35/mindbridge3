import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../../../lib/services/email_service.dart';
import '../../../../lib/services/otp_service.dart';

// POST /api/email/otp
// Body: { "email": "...", "name": "...", "type": "reset" | "verify" }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final email = (body['email'] as String?)?.trim() ?? '';
  final name  = (body['name']  as String?)?.trim() ?? 'there';
  final type  = (body['type']  as String?)?.trim() ?? 'reset'; // 'reset' | 'verify'

  if (email.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'email is required'});
  }
  if (type != 'reset' && type != 'verify') {
    return Response.json(statusCode: 400, body: {'error': "type must be 'reset' or 'verify'"});
  }

  final code = OtpService.generate(email);
  final ok   = await EmailService.sendOtp(toEmail: email, name: name, code: code, type: type);

  if (ok) {
    return Response.json(body: {'success': true});
  } else {
    return Response.json(statusCode: 500, body: {'error': 'Failed to send OTP email'});
  }
}
