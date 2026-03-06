import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Semantic design token system for MindBridge.
/// Use these tokens throughout the app instead of raw colors/values —
/// they carry meaning and adapt consistently to theme/context.

// ─── Spacing ──────────────────────────────────────────────
abstract class Spacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: md, vertical: md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets listItemPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: sm + xs);
}

// ─── Border Radius ────────────────────────────────────────
abstract class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 100;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

// ─── Elevation / Shadows ─────────────────────────────────
abstract class AppShadow {
  static List<BoxShadow> none = [];

  // Neutral gray shadows — no color tint
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: AppColors.shadowSm,
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: AppColors.shadowSm,
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: AppColors.shadowMd,
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: AppColors.shadowSm,
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: AppColors.shadowLg,
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: AppColors.shadowMd,
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> coloredSm(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> coloredMd(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

// ─── Wellness Score Tokens ────────────────────────────────
enum WellnessBand {
  thriving,
  growing,
  steady,
  struggling,
  critical,
}

abstract class WellnessTokens {
  static WellnessBand bandFor(double score) {
    if (score >= 80) return WellnessBand.thriving;
    if (score >= 60) return WellnessBand.growing;
    if (score >= 40) return WellnessBand.steady;
    if (score >= 20) return WellnessBand.struggling;
    return WellnessBand.critical;
  }

  static Color colorFor(WellnessBand band) => switch (band) {
        WellnessBand.thriving => const Color(0xFF06D6A0),
        WellnessBand.growing => const Color(0xFF4ECDC4),
        WellnessBand.steady => const Color(0xFFFFD166),
        WellnessBand.struggling => const Color(0xFFFF8C42),
        WellnessBand.critical => const Color(0xFFFF4757),
      };

  static Color colorForScore(double score) => colorFor(bandFor(score));

  static LinearGradient gradientFor(WellnessBand band) => switch (band) {
        WellnessBand.thriving => const LinearGradient(
            colors: [Color(0xFF06D6A0), Color(0xFF4ECDC4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        WellnessBand.growing => const LinearGradient(
            colors: [Color(0xFF00BEB4), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        WellnessBand.steady => const LinearGradient(
            colors: [Color(0xFFFFD166), Color(0xFFA8E063)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        WellnessBand.struggling => const LinearGradient(
            colors: [Color(0xFFFF8C42), Color(0xFFFFD166)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        WellnessBand.critical => const LinearGradient(
            colors: [Color(0xFFFF4757), Color(0xFFFF8C42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      };

  static String labelFor(WellnessBand band) => switch (band) {
        WellnessBand.thriving => 'Thriving',
        WellnessBand.growing => 'Growing',
        WellnessBand.steady => 'Steady',
        WellnessBand.struggling => 'Struggling',
        WellnessBand.critical => 'Needs Support',
      };

  static String emojiFor(WellnessBand band) => switch (band) {
        WellnessBand.thriving => '🌟',
        WellnessBand.growing => '🌱',
        WellnessBand.steady => '🌤',
        WellnessBand.struggling => '🌧',
        WellnessBand.critical => '🆘',
      };

  static String encouragementFor(WellnessBand band) => switch (band) {
        WellnessBand.thriving =>
          'You\'re doing amazing — keep this momentum going!',
        WellnessBand.growing =>
          'Great progress! You\'re building healthy habits.',
        WellnessBand.steady => 'You\'re holding steady. Keep checking in.',
        WellnessBand.struggling =>
          'It\'s okay to have hard days. Let\'s support you.',
        WellnessBand.critical =>
          'You matter. Please reach out — help is available.',
      };
}

// ─── Mood Tokens ──────────────────────────────────────────
abstract class MoodTokens {
  static Color colorFor(int score) {
    if (score <= 0 || score > 10) return AppColors.textMuted;
    return AppColors.moodColors[score - 1];
  }

  static LinearGradient gradientFor(int score) {
    final color = colorFor(score);
    return LinearGradient(
      colors: [color, color.withOpacity(0.7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static String emojiFor(int score) => switch (score) {
        1 => '😣',
        2 => '😢',
        3 => '😔',
        4 => '😕',
        5 => '😐',
        6 => '🙂',
        7 => '😊',
        8 => '😄',
        9 => '🤩',
        10 => '🥰',
        _ => '😐',
      };

  static String labelFor(int score) => switch (score) {
        1 => 'Terrible',
        2 => 'Very Bad',
        3 => 'Bad',
        4 => 'Poor',
        5 => 'Neutral',
        6 => 'Okay',
        7 => 'Good',
        8 => 'Great',
        9 => 'Excellent',
        10 => 'Amazing',
        _ => 'Unknown',
      };
}

// ─── Animation Durations ─────────────────────────────────
abstract class AppDuration {
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slower = Duration(milliseconds: 800);
  static const Duration page = Duration(milliseconds: 350);
}

// ─── Animation Curves ────────────────────────────────────
abstract class AppCurve {
  static const Curve standard = Curves.easeInOut;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;
  static const Curve decelerate = Curves.decelerate;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}

// ─── Theme-adaptive Token Resolver ───────────────────────
extension ThemeTokens on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get tokenSurface =>
      isDark ? AppColors.surfaceDark : AppColors.surface;
  Color get tokenBackground =>
      isDark ? AppColors.backgroundDark : AppColors.background;
  Color get tokenSurfaceVariant =>
      isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant;
  Color get tokenBorder =>
      isDark ? AppColors.borderDark : AppColors.border;
  Color get tokenTextPrimary =>
      isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get tokenTextSecondary =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get tokenTextMuted =>
      isDark ? AppColors.textMutedDark : AppColors.textMuted;
}
