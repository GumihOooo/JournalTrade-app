import 'package:flutter/material.dart';

/// GumiBook spacing tokens (DESIGN.md §3.3). 4dp grid.
final class GumiSpacings {
  const GumiSpacings._();

  static const standard = GumiSpacings._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

extension GumiSpacingsX on BuildContext {
  GumiSpacings get gumiSpacings => GumiSpacings.standard;
}

/// GumiBook radius tokens (DESIGN.md §3.4).
final class GumiRadius {
  const GumiRadius._();

  static const standard = GumiRadius._();

  static const double control = 10; // small control
  static const double input = 12; // input/button
  static const double card = 16; // card
  static const double glass = 24; // glass panel / bottom nav

  static const BorderRadius inputBorder = BorderRadius.all(Radius.circular(input));
  static const BorderRadius cardBorder = BorderRadius.all(Radius.circular(card));
  static const BorderRadius glassBorder = BorderRadius.all(Radius.circular(glass));
}

extension GumiRadiusX on BuildContext {
  GumiRadius get gumiRadius => GumiRadius.standard;
}
