import 'package:dart_frog/dart_frog.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../lib/middleware/auth_middleware.dart';

/// Global middleware — applies to all routes
Handler middleware(Handler handler) {
  return handler
      .use(requestLogger())
      .use(fromShelfMiddleware(corsHeaders(
        headers: {
          ACCESS_CONTROL_ALLOW_ORIGIN: '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      )))
      .use(authMiddleware());
}
