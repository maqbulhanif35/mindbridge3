import 'dart:io';
import 'package:postgres/postgres.dart';

/// Singleton database connection pool
class Database {
  static Database? _instance;
  late final Connection _connection;

  Database._();

  static Future<Database> getInstance() async {
    _instance ??= Database._();
    await _instance!._connect();
    return _instance!;
  }

  Future<void> _connect() async {
    _connection = await Connection.open(
      Endpoint(
        host: Platform.environment['DB_HOST'] ?? 'localhost',
        port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
        database: Platform.environment['DB_NAME'] ?? 'mindbridge',
        username: Platform.environment['DB_USER'] ?? 'postgres',
        password: Platform.environment['DB_PASS'] ?? 'password',
      ),
      settings: const ConnectionSettings(
        sslMode: SslMode.disable,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    final result = await _connection.execute(
      Sql.named(sql),
      parameters: substitutionValues,
    );
    return result
        .map((row) => row.toColumnMap())
        .toList();
  }

  Future<Map<String, dynamic>?> queryOne(
    String sql, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    final rows = await query(sql, substitutionValues: substitutionValues);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> execute(
    String sql, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    await _connection.execute(
      Sql.named(sql),
      parameters: substitutionValues,
    );
  }
}
