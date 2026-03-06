import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';

class JwtService {
  static String get _secret =>
      Platform.environment['JWT_SECRET'] ?? 'mindbridge-secret-key-change-in-production';

  static const _accessTokenExpiry = Duration(hours: 1);
  static const _refreshTokenExpiry = Duration(days: 30);
  static const _uuid = Uuid();

  static Map<String, String> generateTokens(String userId) {
    final accessToken = JWT({'sub': userId, 'type': 'access'}).sign(
      SecretKey(_secret),
      expiresIn: _accessTokenExpiry,
    );

    final refreshToken = JWT({'sub': userId, 'type': 'refresh', 'jti': _uuid.v4()}).sign(
      SecretKey(_secret),
      expiresIn: _refreshTokenExpiry,
    );

    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };
  }

  static String? verifyAndGetUserId(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      return jwt.payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}
