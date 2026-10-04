import 'package:flutter/material.dart';

import 'gumi_colors.dart';
import 'gumi_spacing_radius.dart';

/// GumiBook dark ThemeData (DESIGN.md §2.2, §3.5).
///
/// Components read tokens from here via `Theme.of(context)`, never
/// hardcode colors per screen.
final class GumiTheme {
  const GumiTheme._();

  static ThemeData dark() {
    final c = GumiColors.dark;
    const radius = GumiRadius.input;

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: c.accentSilver,
        onPrimary: c.bgPrimary,
        secondary: c.textSecondary,
        onSecondary: c.bgPrimary,
        error: c.semanticLoss,
        onError: c.bgPrimary,
        surface: c.surfaceBase,
        onSurface: c.textPrimary,
        surfaceContainerHighest: c.surfaceElevated,
        onSurfaceVariant: c.textSecondary,
        outline: c.borderSubtle,
        outlineVariant: c.borderSubtle,
      ),
      scaffoldBackgroundColor: c.bgPrimary,
    );

    return base.copyWith(
      textTheme: _textTheme(base),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      inputDecorationTheme: _inputDecoration(c),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Compact height (~44) and 87% fill: readable, slightly translucent.
          backgroundColor: c.accentSilver.withValues(alpha: 0.87),
          foregroundColor: c.bgPrimary,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: c.borderFocus),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentSilver,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(GumiRadius.card)),
        ),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: c.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceElevated,
        contentTextStyle: TextStyle(color: c.textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(GumiRadius.control)),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.borderSubtle, thickness: 1, space: 1),
    );
  }

  /// Typography scale (DESIGN.md §3.5). Tabular figures for financial numbers.
  static TextTheme _textTheme(ThemeData base) {
    const tabular = FontFeature.tabularFigures();
    final c = GumiColors.dark;

    return base.textTheme
        .apply(bodyColor: c.textPrimary, displayColor: c.textPrimary)
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            fontFeatures: const [tabular],
          ),
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontFeatures: const [tabular],
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
          bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.4),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 12),
          labelSmall: base.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: c.textMuted,
          ),
        );
  }

  static InputDecorationTheme _inputDecoration(GumiColorsDark c) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
      borderSide: BorderSide(color: c.borderSubtle),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
      borderSide: BorderSide(color: c.borderFocus, width: 1.5),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
      borderSide: BorderSide(color: c.semanticLoss, width: 1),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: c.bgSecondary,
      hintStyle: TextStyle(color: c.textMuted),
      labelStyle: TextStyle(color: c.textSecondary),
      floatingLabelStyle: TextStyle(color: c.accentSilver),
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: true,
    );
  }
}
