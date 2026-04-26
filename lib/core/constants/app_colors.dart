import 'package:flutter/material.dart';

abstract class AppColors {
  // ─── Gruvbox Light Palette ────────────────────────────────
  static const Color gruvboxLightBg = Color(0xFFF8F1C2);
  static const Color gruvboxLightFg = Color(0xFF3C3C3C);
  static const Color gruvboxLightRed = Color(0xFFCC241D);
  static const Color gruvboxLightGreen = Color(0xFF98971A);
  static const Color gruvboxLightYellow = Color(0xFFD79921);
  static const Color gruvboxLightBlue = Color(0xFF458588);
  static const Color gruvboxLightPurple = Color(0xFFB16286);
  static const Color gruvboxLightAqua = Color(0xFF689D6A);
  static const Color gruvboxLightGray = Color(0xFFA89984);
  static const Color gruvboxLightOrange = Color(0xFFFE8019);

  // ─── Gruvbox Dark Hard Palette ────────────────────────────
  static const Color gruvboxDarkBg = Color(0xFF1D2021);
  static const Color gruvboxDarkFg = Color(0xFFEBDBB2);
  static const Color gruvboxDarkRed = Color(0xFFFB4934);
  static const Color gruvboxDarkGreen = Color(0xFFB8BB26);
  static const Color gruvboxDarkYellow = Color(0xFFFABD2F);
  static const Color gruvboxDarkBlue = Color(0xFF83A598);
  static const Color gruvboxDarkPurple = Color(0xFFD3869B);
  static const Color gruvboxDarkAqua = Color(0xFF8EC07C);
  static const Color gruvboxDarkGray = Color(0xFF928374);
  static const Color gruvboxDarkOrange = Color(0xFFFE8019);

  static const Color primary = gruvboxLightYellow;
  static const Color primaryLight = Color(0xFFF2D12F);
  static const Color primaryDark = gruvboxLightYellow;
  static const Color primaryContainer = Color(0xFFE6D9B8);

  static const Color secondary = gruvboxLightRed;
  static const Color secondaryLight = Color(0xFFDA4A3D);
  static const Color secondaryDark = gruvboxLightRed;
  static const Color secondaryContainer = Color(0xFFF1D8D5);

  static const Color tertiary = gruvboxLightBlue;
  static const Color tertiaryLight = Color(0xFF5A9A94);
  static const Color tertiaryDark = gruvboxLightBlue;
  static const Color tertiaryContainer = Color(0xFFD1E3E1);

  // ─── Dark Theme Aliases ─────────────────────────────────
  static const Color darkPrimary = gruvboxDarkYellow;
  static const Color darkPrimaryLight = gruvboxDarkYellow;
  static const Color darkPrimaryDark = gruvboxDarkYellow;
  static const Color darkPrimaryContainer = Color(0xFF3A3521);

  static const Color darkSecondary = gruvboxDarkRed;
  static const Color darkSecondaryLight = Color(0xFFFC6954);
  static const Color darkSecondaryDark = gruvboxDarkRed;
  static const Color darkSecondaryContainer = Color(0xFF3D2421);

  static const Color darkTertiary = gruvboxDarkBlue;
  static const Color darkTertiaryLight = Color(0xFF9AB9A8);
  static const Color darkTertiaryDark = gruvboxDarkBlue;
  static const Color darkTertiaryContainer = Color(0xFF24302D);

  // ─── Semantic Colors (Light) ──────────────────────────────
  static const Color warning = gruvboxLightOrange;
  static const Color warningContainer = Color(0xFFF5E6D3);
  static const Color success = gruvboxLightGreen;
  static const Color successContainer = Color(0xFFE6EDD4);
  static const Color error = gruvboxLightRed;
  static const Color errorContainer = Color(0xFFF1D8D5);
  static const Color info = gruvboxLightBlue;
  static const Color infoContainer = Color(0xFFD1E3E1);

  // ─── Semantic Colors (Dark) ───────────────────────────────
  static const Color warningDark = gruvboxDarkOrange;
  static const Color warningContainerDark = Color(0xFF3D2E21);
  static const Color successDark = gruvboxDarkGreen;
  static const Color successContainerDark = Color(0xFF2D3521);
  static const Color errorDark = gruvboxDarkRed;
  static const Color errorContainerDark = Color(0xFF3D2421);
  static const Color infoDark = gruvboxDarkBlue;
  static const Color infoContainerDark = Color(0xFF24302D);

  // ─── Backgrounds (Light) ─────────────────────────────────
  static const Color background = gruvboxLightBg;
  static const Color surface = Color(0xFFF9F0DC);
  static const Color surfaceVariant = Color(0xFFE8DFC4);

  // ─── Backgrounds (Dark) ──────────────────────────────────
  static const Color backgroundDark = gruvboxDarkBg;
  static const Color surfaceDark = Color(0xFF282828);
  static const Color surfaceVariantDark = Color(0xFF32302C);

  // ─── Text (Light) ─────────────────────────────────────────
  static const Color textPrimary = gruvboxLightFg;
  static const Color textSecondary = Color(0xFF5A5247);
  static const Color textMuted = Color(0xFF9A8F79);
  static const Color textPrimaryDark = gruvboxDarkFg;
  static const Color textSecondaryDark = Color(0xFFA89984);
  static const Color textMutedDark = Color(0xFF6F6A5A);

  // ─── Borders & Dividers (Light) ───────────────────────────
  static const Color border = Color(0xFFD4C9B3);
  static const Color divider = Color(0xFFDDD4BC);
  static const Color borderDark = Color(0xFF454038);
  static const Color dividerDark = Color(0xFF3A352D);

  // ─── Mood Scale Colors (1-10) ─────────────────────────
  static const List<Color> moodColors = [
    Color(0xFFFB4934), // 1 - Terrible
    Color(0xFFE04B3A), // 2 - Very Bad
    Color(0xFFFE8019), // 3 - Bad
    Color(0xFFD79921), // 4 - Poor
    Color(0xFFB8BB26), // 5 - Neutral
    Color(0xFF98971A), // 6 - Okay
    Color(0xFF8EC07C), // 7 - Good
    Color(0xFF689D6A), // 8 - Great
    Color(0xFF458588), // 9 - Excellent
    Color(0xFF83A598), // 10 - Amazing
  ];

  // ─── Emotion Category Colors ──────────────────────────
  static const Map<String, Color> emotionColors = {
    'happy': gruvboxLightYellow,
    'sad': gruvboxLightBlue,
    'anxious': gruvboxLightOrange,
    'angry': gruvboxLightRed,
    'calm': gruvboxLightAqua,
    'excited': gruvboxLightYellow,
    'tired': gruvboxLightGray,
    'grateful': gruvboxLightGreen,
    'lonely': gruvboxLightBlue,
    'hopeful': gruvboxLightGreen,
    'overwhelmed': gruvboxLightOrange,
    'proud': gruvboxLightAqua,
  };

  // ─── Shadow Colors ────────────────────────────────────
  static const Color shadowSm = Color(0x0F3C3C3C);
  static const Color shadowMd = Color(0x1A3C3C3C);
  static const Color shadowLg = Color(0x263C3C3C);
  static Color shadowPrimary = gruvboxLightYellow.withValues(alpha: 0.15);
  static Color shadowCard = const Color(0xFF3C3C3C).withValues(alpha: 0.06);
  static Color shadowDark = const Color(0xFF1D2021).withValues(alpha: 0.15);
}
