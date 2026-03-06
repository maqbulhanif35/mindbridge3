import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../../../lib/database/database.dart';
import '../../../lib/middleware/auth_middleware.dart';

/// GET /api/mood    — List mood entries
/// POST /api/mood   — Create mood entry
Future<Response> onRequest(RequestContext context) async {
  final userId = context.read<String?>(); // Set by auth middleware
  if (userId == null) {
    return Response.json(
      statusCode: HttpStatus.unauthorized,
      body: {'error': 'Unauthorized'},
    );
  }

  final db = await Database.getInstance();

  if (context.request.method == HttpMethod.get) {
    final params = context.request.uri.queryParameters;
    final days = int.tryParse(params['days'] ?? '90') ?? 90;

    final entries = await db.query(
      '''SELECT * FROM mood_entries
         WHERE user_id = @user_id
           AND created_at > NOW() - INTERVAL '@days days'
         ORDER BY created_at DESC''',
      substitutionValues: {'user_id': userId, 'days': days},
    );

    return Response.json(body: entries);
  }

  if (context.request.method == HttpMethod.post) {
    final body = await context.request.json() as Map<String, dynamic>;

    final moodScore = body['mood_score'] as int?;
    if (moodScore == null || moodScore < 1 || moodScore > 10) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'error': 'mood_score must be between 1 and 10'},
      );
    }

    final entry = await db.queryOne(
      '''INSERT INTO mood_entries (user_id, mood_score, emotions, activities, note, sleep_hours)
         VALUES (@user_id, @mood_score, @emotions, @activities, @note, @sleep_hours)
         RETURNING *''',
      substitutionValues: {
        'user_id': userId,
        'mood_score': moodScore,
        'emotions': body['emotions'] ?? [],
        'activities': body['activities'] ?? [],
        'note': body['note'],
        'sleep_hours': body['sleep_hours'],
      },
    );

    return Response.json(statusCode: HttpStatus.created, body: entry);
  }

  return Response(statusCode: HttpStatus.methodNotAllowed);
}
