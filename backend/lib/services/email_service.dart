import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

// ─────────────────────────────────────────────────────────
// EmailService  — sends all transactional emails via Gmail
// SMTP using an App Password (no OAuth dance required).
// ─────────────────────────────────────────────────────────

class EmailService {
  static String get _fromEmail => Platform.environment['SMTP_FROM_EMAIL'] ?? '';
  static String get _fromName  => Platform.environment['SMTP_FROM_NAME']  ?? 'MindBridge';
  static String get _appPass   => Platform.environment['SMTP_APP_PASSWORD'] ?? '';
  static String get _appUrl    =>
      Platform.environment['APP_URL_PROD'] ??
      Platform.environment['APP_URL'] ??
      'https://mindbridge-teal.vercel.app';

  static SmtpServer get _smtp => gmail(_fromEmail, _appPass);

  // ── Send helper ─────────────────────────────────────────

  static Future<bool> _send({
    required String to,
    required String subject,
    required String html,
  }) async {
    if (_fromEmail.isEmpty || _appPass.isEmpty) {
      print('[EmailService] SMTP credentials not set — skipping email to $to');
      return false;
    }
    try {
      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(to)
        ..subject = subject
        ..html = html;

      final report = await send(message, _smtp);
      print('[EmailService] ✓ Sent to $to — $report');
      return true;
    } on MailerException catch (e) {
      print('[EmailService] ✗ Failed to $to: ${e.message}');
      for (final p in e.problems) {
        print('  Problem: ${p.code} — ${p.msg}');
      }
      return false;
    } catch (e) {
      print('[EmailService] ✗ Unexpected error: $e');
      return false;
    }
  }

  // ── Welcome Email ────────────────────────────────────────

  static Future<bool> sendWelcome({
    required String toEmail,
    required String name,
  }) =>
      _send(
        to: toEmail,
        subject: '🌿 Welcome to MindBridge, $name!',
        html: _welcomeHtml(name: name, appUrl: _appUrl),
      );

  // ── Admin → User direct message ──────────────────────────

  static Future<bool> sendAdminMessage({
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
    required String fromAdmin,
  }) =>
      _send(
        to: toEmail,
        subject: subject,
        html: _adminMessageHtml(
          toName: toName,
          subject: subject,
          message: message,
          fromAdmin: fromAdmin,
          appUrl: _appUrl,
        ),
      );

  // ── OTP Email (password reset / re-verification) ────────

  static Future<bool> sendOtp({
    required String toEmail,
    required String name,
    required String code,
    required String type, // 'reset' | 'verify'
  }) =>
      _send(
        to: toEmail,
        subject: type == 'reset'
            ? '🔐 MindBridge password reset code: $code'
            : '✅ MindBridge verification code: $code',
        html: _otpHtml(name: name, code: code, type: type, appUrl: _appUrl),
      );

  // ─────────────────────────────────────────────────────────
  // HTML TEMPLATES
  // ─────────────────────────────────────────────────────────

  static String _welcomeHtml({required String name, required String appUrl}) => '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>Welcome to MindBridge</title>
<style>
  body { margin:0; padding:0; background:#F5F7FA; font-family:'Segoe UI',Arial,sans-serif; }
  .wrap { max-width:580px; margin:40px auto; background:#FFFFFF;
          border-radius:20px; overflow:hidden;
          box-shadow:0 8px 40px rgba(0,0,0,0.10); }
  .hero { background:linear-gradient(135deg,#007A75 0%,#00BEB4 50%,#0EA5E9 100%);
          padding:48px 40px 40px; text-align:center; }
  .hero-icon { font-size:52px; line-height:1; margin-bottom:16px; }
  .hero-title { color:#fff; font-size:28px; font-weight:800; margin:0 0 8px; letter-spacing:-0.3px; }
  .hero-sub { color:rgba(255,255,255,0.82); font-size:15px; margin:0; }
  .body { padding:40px; }
  .greeting { font-size:18px; font-weight:700; color:#1A202C; margin:0 0 12px; }
  .text { font-size:15px; color:#4A5568; line-height:1.7; margin:0 0 24px; }
  .features { background:#F0FAFA; border-radius:14px; padding:24px; margin:0 0 28px; }
  .feature { display:flex; align-items:flex-start; margin-bottom:16px; }
  .feature:last-child { margin-bottom:0; }
  .feat-icon { font-size:22px; margin-right:14px; flex-shrink:0; }
  .feat-text h4 { margin:0 0 3px; font-size:14px; font-weight:700; color:#1A202C; }
  .feat-text p  { margin:0; font-size:13px; color:#718096; line-height:1.5; }
  .btn-wrap { text-align:center; margin:28px 0; }
  .btn { display:inline-block; background:linear-gradient(135deg,#00BEB4,#0EA5E9);
         color:#fff; text-decoration:none; padding:15px 40px;
         border-radius:50px; font-size:15px; font-weight:700;
         letter-spacing:0.3px; }
  .divider { height:1px; background:#E8EDF2; margin:28px 0; }
  .footer { text-align:center; padding:0 40px 36px; }
  .footer p { font-size:12px; color:#A0AEC0; margin:0 0 6px; line-height:1.6; }
  .footer a { color:#00BEB4; text-decoration:none; }
  .affirmation { text-align:center; font-size:14px; color:#718096;
                 font-style:italic; margin:0 0 24px; }
</style>
</head>
<body>
<div class="wrap">
  <div class="hero">
    <div class="hero-icon">🌿</div>
    <h1 class="hero-title">Welcome to MindBridge</h1>
    <p class="hero-sub">Your mental wellness journey starts today</p>
  </div>
  <div class="body">
    <p class="greeting">Hi $name 👋</p>
    <p class="text">
      You've just taken a genuinely important step. MindBridge is your private,
      judgment-free space to track your mood, build healthy habits, and talk to
      Maya — your AI wellness companion — whenever you need.
    </p>

    <div class="features">
      <div class="feature">
        <span class="feat-icon">💬</span>
        <div class="feat-text">
          <h4>Chat with Maya</h4>
          <p>Your AI companion, available 24/7 to listen, support, and guide you.</p>
        </div>
      </div>
      <div class="feature">
        <span class="feat-icon">📊</span>
        <div class="feat-text">
          <h4>Track your mood</h4>
          <p>Daily check-ins reveal patterns and help you understand yourself better.</p>
        </div>
      </div>
      <div class="feature">
        <span class="feat-icon">🧘</span>
        <div class="feat-text">
          <h4>Mindfulness tools</h4>
          <p>Breathing exercises, body scans, and guided sessions in under 10 minutes.</p>
        </div>
      </div>
      <div class="feature">
        <span class="feat-icon">🔥</span>
        <div class="feat-text">
          <h4>Build streaks</h4>
          <p>Small daily actions compound into lasting wellbeing. Your first day starts now.</p>
        </div>
      </div>
    </div>

    <div class="btn-wrap">
      <a href="$appUrl" class="btn">Open MindBridge →</a>
    </div>

    <div class="divider"></div>

    <p class="affirmation">"A journey of a thousand miles begins with a single step." — Lao Tzu</p>

    <p class="text" style="font-size:13px;color:#718096;margin:0;">
      If you ever feel overwhelmed, remember that help is always one tap away.
      The crisis support line is built right into the app.
    </p>
  </div>
  <div class="footer">
    <p>You're receiving this because you created a MindBridge account.</p>
    <p>© 2025 MindBridge · <a href="$appUrl">mindbridge-teal.vercel.app</a></p>
  </div>
</div>
</body>
</html>
''';

  static String _otpHtml({
    required String name,
    required String code,
    required String type,
    required String appUrl,
  }) {
    final isReset = type == 'reset';
    final title = isReset ? 'Password Reset' : 'Verify your email';
    final subtitle = isReset
        ? 'Someone (hopefully you) requested a password reset for your MindBridge account.'
        : 'Enter this code to verify your MindBridge account.';
    final expiryNote = 'This code expires in <strong>15 minutes</strong>.';
    final icon = isReset ? '🔐' : '✅';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>$title — MindBridge</title>
<style>
  body { margin:0; padding:0; background:#F5F7FA; font-family:'Segoe UI',Arial,sans-serif; }
  .wrap { max-width:520px; margin:40px auto; background:#FFFFFF;
          border-radius:20px; overflow:hidden;
          box-shadow:0 8px 40px rgba(0,0,0,0.10); }
  .hero { background:linear-gradient(135deg,#007A75 0%,#00BEB4 60%,#0EA5E9 100%);
          padding:40px; text-align:center; }
  .hero-icon { font-size:46px; line-height:1; margin-bottom:12px; }
  .hero-title { color:#fff; font-size:24px; font-weight:800; margin:0; }
  .body { padding:40px; }
  .greeting { font-size:17px; font-weight:700; color:#1A202C; margin:0 0 12px; }
  .text { font-size:15px; color:#4A5568; line-height:1.7; margin:0 0 28px; }
  .code-wrap { background:linear-gradient(135deg,#F0FAFA,#EBF8FF);
               border:2px solid #00BEB4; border-radius:16px;
               padding:28px; text-align:center; margin:0 0 24px; }
  .code-label { font-size:12px; font-weight:700; color:#00BEB4;
                letter-spacing:1.2px; text-transform:uppercase; margin:0 0 12px; }
  .code { font-size:46px; font-weight:900; color:#1A202C;
          letter-spacing:10px; font-family:'Courier New',monospace;
          margin:0 0 12px; }
  .expiry { font-size:13px; color:#718096; margin:0; }
  .warning { background:#FFFBEB; border:1px solid #FCD34D; border-radius:12px;
             padding:14px 18px; margin:0 0 24px; }
  .warning p { margin:0; font-size:13px; color:#92400E; line-height:1.6; }
  .divider { height:1px; background:#E8EDF2; margin:24px 0; }
  .footer { text-align:center; padding:0 40px 32px; }
  .footer p { font-size:12px; color:#A0AEC0; margin:0 0 6px; line-height:1.6; }
  .footer a { color:#00BEB4; text-decoration:none; }
</style>
</head>
<body>
<div class="wrap">
  <div class="hero">
    <div class="hero-icon">$icon</div>
    <h1 class="hero-title">$title</h1>
  </div>
  <div class="body">
    <p class="greeting">Hi $name,</p>
    <p class="text">$subtitle</p>

    <div class="code-wrap">
      <p class="code-label">Your code</p>
      <p class="code">$code</p>
      <p class="expiry">$expiryNote</p>
    </div>

    <div class="warning">
      <p>🔒 <strong>Never share this code.</strong> MindBridge will never ask for it via phone or chat.
        If you didn't request this, you can safely ignore this email.</p>
    </div>

    <div class="divider"></div>

    <p class="text" style="font-size:13px;color:#718096;margin:0;">
      Having trouble? Open the app and tap "Resend code" to get a new one.
    </p>
  </div>
  <div class="footer">
    <p>© 2025 MindBridge · <a href="$appUrl">mindbridge-teal.vercel.app</a></p>
  </div>
</div>
</body>
</html>
''';
  }

  static String _adminMessageHtml({
    required String toName,
    required String subject,
    required String message,
    required String fromAdmin,
    required String appUrl,
  }) => '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>$subject</title>
<style>
  body { margin:0; padding:0; background:#F5F7FA; font-family:'Segoe UI',Arial,sans-serif; }
  .wrap { max-width:560px; margin:40px auto; background:#FFFFFF; border-radius:20px; overflow:hidden; box-shadow:0 8px 40px rgba(0,0,0,0.10); }
  .hero { background:linear-gradient(135deg,#007A75 0%,#00BEB4 60%,#0EA5E9 100%); padding:36px 40px 32px; text-align:center; }
  .hero-icon { font-size:40px; line-height:1; margin-bottom:10px; }
  .hero-title { color:#fff; font-size:22px; font-weight:800; margin:0; }
  .hero-sub { color:rgba(255,255,255,0.82); font-size:13px; margin:8px 0 0; }
  .body { padding:36px 40px; }
  .greeting { font-size:17px; font-weight:700; color:#1A202C; margin:0 0 16px; }
  .message-box { background:#F8FAFC; border-left:4px solid #00BEB4; border-radius:0 12px 12px 0; padding:20px 24px; margin:0 0 24px; }
  .message-text { font-size:15px; color:#2D3748; line-height:1.75; margin:0; white-space:pre-wrap; }
  .from { font-size:13px; color:#718096; margin:20px 0 0; }
  .from strong { color:#4A5568; }
  .divider { height:1px; background:#E8EDF2; margin:24px 0; }
  .footer { text-align:center; padding:0 40px 32px; }
  .footer p { font-size:12px; color:#A0AEC0; margin:0 0 6px; line-height:1.6; }
  .footer a { color:#00BEB4; text-decoration:none; }
  .btn { display:inline-block; background:linear-gradient(135deg,#00BEB4,#0EA5E9); color:#fff; text-decoration:none; padding:13px 32px; border-radius:50px; font-size:14px; font-weight:700; }
</style>
</head>
<body>
<div class="wrap">
  <div class="hero">
    <div class="hero-icon">📬</div>
    <h1 class="hero-title">Message from MindBridge</h1>
    <p class="hero-sub">$fromAdmin · Admin Team</p>
  </div>
  <div class="body">
    <p class="greeting">Hi $toName,</p>
    <div class="message-box">
      <p class="message-text">$message</p>
    </div>
    <p class="from">Sent by <strong>$fromAdmin</strong> · MindBridge Admin Team</p>
    <div class="divider"></div>
    <div style="text-align:center;margin:20px 0;">
      <a href="$appUrl" class="btn">Open MindBridge →</a>
    </div>
  </div>
  <div class="footer">
    <p>© 2025 MindBridge · <a href="$appUrl">mindbridge-teal.vercel.app</a></p>
  </div>
</div>
</body>
</html>
''';
}
