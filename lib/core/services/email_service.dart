/// Handles transactional welcome emails.
///
/// Currently a no-op: Supabase + Gmail SMTP handles OTP delivery and the
/// customised confirmation email template acts as the welcome email.
/// When a verified custom domain is available, re-enable Resend/Brevo here.
class EmailService {
  /// Fire-and-forget welcome email.
  /// Delegated to the Supabase OTP email template — no extra send needed.
  static Future<void> sendWelcomeEmail({
    required String toEmail,
    required String name,
  }) async {
    // No-op until a custom domain is set up.
  }
}
