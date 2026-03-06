import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import '../services/jwt_service.dart';

/// JWT Authentication Middleware
/// Reads Bearer token from Authorization header
/// Injects userId (String?) into the request context
Middleware authMiddleware() {
  return (handler) {
    return (context) async {
      final authHeader = context.request.headers['Authorization'];
      String? userId;

      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring(7);
        userId = JwtService.verifyAndGetUserId(token);
      }

      return handler(context.provide<String?>(() => userId));
    };
  };
}

/// Middleware that requires authentication (returns 401 if not authed)
Middleware requireAuth() {
  return (handler) {
    return (context) async {
      final userId = context.read<String?>();
      if (userId == null) {
        return Response.json(
          statusCode: HttpStatus.unauthorized,
          body: {'error': 'Authentication required'},
        );
      }
      return handler(context);
    };
  };
}
