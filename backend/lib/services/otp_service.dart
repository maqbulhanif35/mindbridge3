import 'dart:math';

// ─────────────────────────────────────────────────────────
// OtpService — in-memory OTP store with 15-minute TTL.
// Codes are 6-digit numeric strings, consumed on first use.
// ─────────────────────────────────────────────────────────

class _OtpEntry {
  final String code;
  final DateTime expiresAt;
  _OtpEntry(this.code) : expiresAt = DateTime.now().add(const Duration(minutes: 15));
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class OtpService {
  OtpService._();

  static final Map<String, _OtpEntry> _store = {};
  static final Random _rng = Random.secure();

  /// Generate and store a 6-digit OTP for [email].
  /// Any previous code for the same email is overwritten.
  static String generate(String email) {
    _purgeExpired();
    final code = (_rng.nextInt(900000) + 100000).toString(); // 100000–999999
    _store[email.toLowerCase()] = _OtpEntry(code);
    return code;
  }

  /// Verify [code] for [email].
  /// Returns true and removes the entry on success.
  /// Returns false if no entry, wrong code, or expired.
  static bool verify(String email, String code) {
    _purgeExpired();
    final key = email.toLowerCase();
    final entry = _store[key];
    if (entry == null || entry.isExpired) {
      _store.remove(key);
      return false;
    }
    if (entry.code != code.trim()) return false;
    _store.remove(key); // consume — single-use
    return true;
  }

  /// Remove all expired entries to avoid unbounded growth.
  static void _purgeExpired() {
    _store.removeWhere((_, e) => e.isExpired);
  }
}
