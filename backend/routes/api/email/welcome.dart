import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../../lib/services/email_service.dart';

// POST /api/email/welcome
// Body: { "email": "...", "name": "..." }
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

  if (email.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'email is required'});
  }

  final ok = await EmailService.sendWelcome(toEmail: email, name: name);
  if (ok) {
    return Response.json(body: {'success': true});
  } else {
    return Response.json(statusCode: 500, body: {'error': 'Failed to send welcome email'});
  }
}
