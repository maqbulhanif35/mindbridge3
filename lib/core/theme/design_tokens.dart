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

  // Flat look for Gruvbox — significantly reduced shadows
  static const List<BoxShadow> xs = [];
  static const List<BoxShadow> sm = [];
  static const List<BoxShadow> md = [];
  static const List<BoxShadow> lg = [];

  static List<BoxShadow> coloredSm(Color color) => [];
  static List<BoxShadow> coloredMd(Color color) => [];
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
        WellnessBand.thriving => AppColors.gruvboxLightGreen,
        WellnessBand.growing => AppColors.gruvboxLightAqua,
        WellnessBand.steady => AppColors.gruvboxLightYellow,
        WellnessBand.struggling => AppColors.gruvboxLightOrange,
        WellnessBand.critical => AppColors.gruvboxLightRed,
      };

  static Color colorForScore(double score) => colorFor(bandFor(score));

  // Gradients removed - returning solid color "gradient" (start/end same)
  static LinearGradient gradientFor(WellnessBand band) {
    final color = colorFor(band);
    return LinearGradient(colors: [color, color]);
  }

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
      colors: [color, color],
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
  static const Duration fast = Duration(milliseconds: 0);
  static const Duration normal = Duration(milliseconds: 0);
  static const Duration slow = Duration(milliseconds: 0);
  static const Duration slower = Duration(milliseconds: 0);
  static const Duration page = Duration(milliseconds: 0);
}

// ─── Animation Curves ────────────────────────────────────
abstract class AppCurve {
  // static const Curve standard = ThresholdCurve(0.5);
  // static const Curve enter = ThresholdCurve(0.5);
  // static const Curve exit = ThresholdCurve(0.5);
  // static const Curve spring = ThresholdCurve(0.5);
  // static const Curve bounce = ThresholdCurve(0.5);
  // static const Curve decelerate = ThresholdCurve(0.5);
  // static const Curve emphasized = ThresholdCurve(0.5);
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
