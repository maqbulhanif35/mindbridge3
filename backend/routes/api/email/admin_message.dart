import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../../lib/services/email_service.dart';

// POST /api/email/admin_message
// Body: { "to_email", "to_name", "subject", "message", "from_admin" }
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

  final toEmail   = (body['to_email']   as String?)?.trim() ?? '';
  final toName    = (body['to_name']    as String?)?.trim() ?? 'Student';
  final subject   = (body['subject']    as String?)?.trim() ?? 'Message from MindBridge Admin';
  final message   = (body['message']    as String?)?.trim() ?? '';
  final fromAdmin = (body['from_admin'] as String?)?.trim() ?? 'MindBridge Admin';

  if (toEmail.isEmpty || message.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'to_email and message are required'});
  }

  final ok = await EmailService.sendAdminMessage(
    toEmail: toEmail,
    toName: toName,
    subject: subject,
    message: message,
    fromAdmin: fromAdmin,
  );

  return ok
      ? Response.json(body: {'success': true})
      : Response.json(statusCode: 500, body: {'error': 'Failed to send email'});
}
