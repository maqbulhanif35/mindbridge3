import 'dart:convert';
import 'package:http/http.dart' as http;

/// Sends transactional emails via the Resend API.
/// Key is injected at compile time: --dart-define=RESEND_API_KEY=re_xxx
class EmailService {
  static const _apiKey =
      String.fromEnvironment('RESEND_API_KEY', defaultValue: '');

  // Use Resend sandbox (no domain required) until a custom domain is added.
  static const _from = 'MindBridge <onboarding@resend.dev>';

  // ─── Public API ───────────────────────────────────────────

  /// Sends a branded welcome email to a newly verified user.
  /// Silently fails — email issues must never block the auth flow.
  static Future<void> sendWelcomeEmail({
    required String toEmail,
    required String name,
  }) async {
    if (_apiKey.isEmpty) return; // key not set in dev — skip

    try {
      await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _from,
          'to': [toEmail],
          'subject': 'Welcome to MindBridge, $name!',
          'html': _welcomeHtml(name),
        }),
      );
    } catch (_) {
      // Fire-and-forget — never throw
    }
  }

  // ─── Email Templates ──────────────────────────────────────

  static String _welcomeHtml(String name) => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Welcome to MindBridge</title>
</head>
<body style="margin:0;padding:0;background:#F5F7FA;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F5F7FA;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0"
          style="background:#FFFFFF;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);max-width:560px;">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#006B64 0%,#00BEB4 100%);padding:40px 40px 32px;text-align:center;">
              <div style="display:inline-flex;align-items:center;justify-content:center;width:68px;height:68px;background:rgba(255,255,255,0.18);border-radius:18px;font-size:34px;margin-bottom:18px;">🌿</div>
              <h1 style="margin:0;color:#FFFFFF;font-size:26px;font-weight:800;letter-spacing:-0.5px;">Welcome to MindBridge</h1>
              <p style="margin:8px 0 0;color:rgba(255,255,255,0.75);font-size:14px;font-weight:500;">Your mental wellness companion for campus life</p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 40px 28px;">
              <p style="margin:0 0 8px;font-size:17px;color:#1A2332;font-weight:700;">Hey $name 👋</p>
              <p style="margin:0 0 24px;font-size:14px;color:#4A5568;line-height:1.75;">
                You've just taken a powerful step towards your wellbeing. MindBridge is here to support
                you through the highs and lows of campus life — whether it's CAT season, HELB stress,
                or just one of those days.
              </p>

              <!-- Features -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:28px;">
                <tr>
                  <td style="padding:13px 16px;background:#F0FAF9;border-radius:12px;border-left:3px solid #00BEB4;margin-bottom:8px;">
                    <table cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="font-size:22px;padding-right:13px;vertical-align:top;">💬</td>
                        <td>
                          <strong style="color:#1A2332;font-size:13px;">Chat with Maya</strong>
                          <p style="margin:4px 0 0;font-size:12px;color:#718096;line-height:1.5;">Your AI companion — available 24/7, no judgement, no waiting room.</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr><td style="height:8px;"></td></tr>
                <tr>
                  <td style="padding:13px 16px;background:#F0FAF9;border-radius:12px;border-left:3px solid #00BEB4;">
                    <table cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="font-size:22px;padding-right:13px;vertical-align:top;">📊</td>
                        <td>
                          <strong style="color:#1A2332;font-size:13px;">Track Your Mood</strong>
                          <p style="margin:4px 0 0;font-size:12px;color:#718096;line-height:1.5;">Understand your emotional patterns and spot trends early.</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr><td style="height:8px;"></td></tr>
                <tr>
                  <td style="padding:13px 16px;background:#F0FAF9;border-radius:12px;border-left:3px solid #00BEB4;">
                    <table cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="font-size:22px;padding-right:13px;vertical-align:top;">🌿</td>
                        <td>
                          <strong style="color:#1A2332;font-size:13px;">Mindfulness & Journaling</strong>
                          <p style="margin:4px 0 0;font-size:12px;color:#718096;line-height:1.5;">Build small daily habits that protect your mental health.</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Crisis note -->
              <div style="background:#FFF8F0;border-radius:10px;padding:13px 16px;border-left:3px solid #F59E0B;margin-bottom:28px;">
                <p style="margin:0;font-size:12px;color:#718096;line-height:1.65;">
                  If you ever feel overwhelmed, Maya is here — but for immediate human support,
                  reach <strong style="color:#1A2332;">Befrienders Kenya: 0800 723 253</strong> (free, 24/7).
                </p>
              </div>

              <!-- CTA -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="https://mindbridge-teal.vercel.app"
                       style="display:inline-block;background:linear-gradient(135deg,#006B64,#00BEB4);color:#FFFFFF;font-size:14px;font-weight:700;text-decoration:none;padding:15px 40px;border-radius:12px;letter-spacing:0.2px;">
                      Open MindBridge →
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:18px 40px 28px;border-top:1px solid #EDF2F7;text-align:center;">
              <p style="margin:0;font-size:11px;color:#A0AEC0;line-height:1.7;">
                You're receiving this because you just joined MindBridge.<br/>
                MindBridge · Built for Kenyan University Students · 2026
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
}
