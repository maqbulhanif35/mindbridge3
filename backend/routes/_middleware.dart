import 'package:dart_frog/dart_frog.dart';
import '../lib/middleware/auth_middleware.dart';

/// Global middleware — applies to all routes
Handler middleware(Handler handler) {
  return handler
      .use(requestLogger())       // Log all requests
      .use(authMiddleware());      // Inject userId into context
}
