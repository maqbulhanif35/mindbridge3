import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../../lib/database/database.dart';
import '../../../lib/services/jwt_service.dart';

/// POST /api/auth/login
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final email = body['email'] as String?;
    final password = body['password'] as String?;

    if (email == null || password == null) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'error': 'Email and password are required'},
      );
    }

    final db = await Database.getInstance();
    final user = await db.queryOne(
      'SELECT * FROM users WHERE email = @email AND is_active = TRUE',
      substitutionValues: {'email': email.toLowerCase().trim()},
    );

    if (user == null) {
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'error': 'Invalid email or password'},
      );
    }

    final passwordValid = BCrypt.checkpw(
      password,
      user['password_hash'] as String,
    );

    if (!passwordValid) {
      return Response.json(
        statusCode: HttpStatus.unauthorized,
        body: {'error': 'Invalid email or password'},
      );
    }

    // Update last seen
    await db.execute(
      'UPDATE users SET last_seen_at = NOW() WHERE id = @id',
      substitutionValues: {'id': user['id']},
    );

    final tokens = JwtService.generateTokens(user['id'] as String);

    // Store session
    await db.execute(
      '''INSERT INTO sessions (user_id, token, refresh_token, expires_at)
         VALUES (@user_id, @token, @refresh_token, @expires_at)''',
      substitutionValues: {
        'user_id': user['id'],
        'token': tokens['access_token'],
        'refresh_token': tokens['refresh_token'],
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      },
    );

    return Response.json(
      body: {
        'access_token': tokens['access_token'],
        'refresh_token': tokens['refresh_token'],
        'user': _sanitizeUser(user),
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': 'Internal server error'},
    );
  }
}

Map<String, dynamic> _sanitizeUser(Map<String, dynamic> user) => {
      'id': user['id'],
      'email': user['email'],
      'name': user['name'],
      'preferred_name': user['preferred_name'],
      'university': user['university'],
      'year_of_study': user['year_of_study'],
      'profile_image_url': user['profile_image_url'],
      'onboarding_completed': user['onboarding_completed'],
      'goals': user['goals'],
      'created_at': user['created_at'].toString(),
    };
