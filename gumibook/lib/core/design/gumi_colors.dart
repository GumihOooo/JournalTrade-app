import 'package:flutter/material.dart';

/// GumiBook color tokens (DESIGN.md §3.1).
///
/// Monochrome/silver is the default palette. Profit/loss/warning are
/// the only semantic colors and must not be used decoratively.
final class GumiColors {
  const GumiColors._();

  static const dark = GumiColorsDark();

  /// Dark-first: the only palette for MVP.
  static GumiColorsDark get darkPalette => dark;
}

extension GumiColorsX on BuildContext {
  /// Convenience: `context.gumiColors.textPrimary`.
  GumiColorsDark get gumiColors => GumiColors.dark;
}

final class GumiColorsDark {
  const GumiColorsDark();

  // Background
  Color get bgPrimary => const Color(0xFF0A0B0E);
  Color get bgSecondary => const Color(0xFF111318);

  // Surface
  Color get surfaceBase => const Color(0xFF16181F);
  Color get surfaceGlass => const Color(0x1AFFFFFF); // 10% white
  Color get surfaceElevated => const Color(0xFF1B1E26);

  // Border
  Color get borderSubtle => const Color(0x14FFFFFF); // 8% white
  Color get borderFocus => const Color(0x33FFFFFF); // 20% white

  // Text
  Color get textPrimary => const Color(0xFFF4F5F7);
  Color get textSecondary => const Color(0xFFA8ADB5);
  Color get textMuted => const Color(0xFF6B7078);

  // Accent
  Color get accentSilver => const Color(0xFFC9CDD3);

  // Semantic (trading only) - refined muted teal/cyan profit, muted coral loss
  Color get semanticProfit => const Color(0xFF00E5BE); // Refined vivid teal
  Color get semanticProfitMuted => const Color(0xFF00BFA0);
  Color get semanticLoss => const Color(0xFFF87171); // Soft coral red
  Color get semanticLossMuted => const Color(0xFFDC5B5B);
  Color get semanticWarning => const Color(0xFFFBBF24);
  Color get semanticInfo => const Color(0xFF38BDF8);

  // Profit/Loss Gradients (E8/fintech style)
  Color get gradientProfitStart => const Color(0xFF00F5C4);
  Color get gradientProfitEnd => const Color(0xFF009B82);

  Color get gradientLossStart => const Color(0xFFF87171);
  Color get gradientLossEnd => const Color(0xFFB91C1C);

  // Card gradient & glow borders
  Color get cardGlowProfit => const Color(0x2600F5C4); // 15% opacity
  Color get cardGlowLoss => const Color(0x26F87171); // 15% opacity
  Color get cardBorderGradientStart => const Color(0x33FFFFFF);
  Color get cardBorderGradientEnd => const Color(0x08FFFFFF);

  LinearGradient get profitGradient => LinearGradient(
        colors: [gradientProfitStart, gradientProfitEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get lossGradient => LinearGradient(
        colors: [gradientLossStart, gradientLossEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
