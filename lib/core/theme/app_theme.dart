import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

abstract class AppTheme {
  // ─── Light Theme ──────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.gruvboxLightYellow,
          onPrimary: AppColors.gruvboxLightBg,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.gruvboxLightFg,
          secondary: AppColors.gruvboxLightRed,
          onSecondary: AppColors.gruvboxLightBg,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.gruvboxLightFg,
          tertiary: AppColors.gruvboxLightBlue,
          onTertiary: AppColors.gruvboxLightBg,
          error: AppColors.gruvboxLightRed,
          onError: AppColors.gruvboxLightBg,
          surface: AppColors.surface,
          onSurface: AppColors.gruvboxLightFg,
          surfaceContainerHighest: AppColors.surfaceVariant,
          outline: AppColors.border,
          outlineVariant: AppColors.divider,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: _buildTextTheme(AppColors.gruvboxLightFg),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.gruvboxLightFg,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: AppColors.gruvboxLightFg),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppColors.border, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gruvboxLightYellow,
            foregroundColor: AppColors.gruvboxLightBg,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: AppColors.gruvboxLightFg, width: 1.5),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gruvboxLightFg,
            side: const BorderSide(color: AppColors.gruvboxLightFg, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.gruvboxLightFg,
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.gruvboxLightFg, width: 1.5),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.gruvboxLightFg, width: 1.5),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.gruvboxLightYellow, width: 2.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: AppColors.textMuted),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.gruvboxLightYellow,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppColors.gruvboxLightFg, width: 1.5),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.gruvboxLightRed,
          unselectedItemColor: AppColors.textMuted,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.gruvboxLightFg,
          thickness: 1.5,
          space: 1,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoTransitionsBuilder(),
            TargetPlatform.iOS: NoTransitionsBuilder(),
          },
        ),
      );

  // ─── Dark Theme ───────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gruvboxDarkYellow,
          onPrimary: AppColors.gruvboxDarkBg,
          primaryContainer: AppColors.darkPrimaryContainer,
          onPrimaryContainer: AppColors.gruvboxDarkFg,
          secondary: AppColors.gruvboxDarkRed,
          onSecondary: AppColors.gruvboxDarkBg,
          tertiary: AppColors.gruvboxDarkBlue,
          onTertiary: AppColors.gruvboxDarkBg,
          error: AppColors.gruvboxDarkRed,
          onError: AppColors.gruvboxDarkBg,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.gruvboxDarkFg,
          surfaceContainerHighest: AppColors.surfaceVariantDark,
          outline: AppColors.borderDark,
          outlineVariant: AppColors.dividerDark,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        textTheme: _buildTextTheme(AppColors.gruvboxDarkFg),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.gruvboxDarkFg,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: AppColors.gruvboxDarkFg),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceDark,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppColors.borderDark, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gruvboxDarkYellow,
            foregroundColor: AppColors.gruvboxDarkBg,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: AppColors.gruvboxDarkFg, width: 1.5),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gruvboxDarkFg,
            side: const BorderSide(color: AppColors.gruvboxDarkFg, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.gruvboxDarkFg,
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariantDark,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.gruvboxDarkFg, width: 1.5),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.gruvboxDarkFg, width: 1.5),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.gruvboxDarkYellow, width: 2.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: AppColors.textMutedDark),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedColor: AppColors.gruvboxDarkYellow,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppColors.gruvboxDarkFg, width: 1.5),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.gruvboxDarkRed,
          unselectedItemColor: AppColors.textMutedDark,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.gruvboxDarkFg,
          thickness: 1.5,
          space: 1,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoTransitionsBuilder(),
            TargetPlatform.iOS: NoTransitionsBuilder(),
          },
        ),
      );

  static TextTheme _buildTextTheme(Color color) => TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 57,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 45,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      );
}
