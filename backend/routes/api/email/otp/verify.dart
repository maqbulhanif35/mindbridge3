import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../../../lib/services/otp_service.dart';

// POST /api/email/otp/verify
// Body: { "email": "...", "code": "123456" }
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
  final code  = (body['code']  as String?)?.trim() ?? '';

  if (email.isEmpty || code.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'email and code are required'});
  }

  final valid = OtpService.verify(email, code);
  if (valid) {
    return Response.json(body: {'success': true, 'verified': true});
  } else {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'verified': false, 'error': 'Invalid or expired code'},
    );
  }
}
