import 'package:flutter/material.dart';

/// Swift (ስዊፍት) brand palette — "Slipstream".
/// Orange & ink: the heat of movement against a warm, grounded dark.
class SwiftColors {
  SwiftColors._();

  // Core
  static const Color ink = Color(0xFF131314); // primary dark, sampled from the artwork
  static const Color graphite = Color(0xFF201F1E); // raised dark surface
  static const Color ember = Color(0xFFA85C08); // deepest gradient base
  static const Color rust = Color(0xFFD97B12); // deep orange / text-safe accent
  static const Color signal = Color(0xFFF1952C); // primary brand orange
  static const Color flame = Color(0xFFFFA94D); // mid
  static const Color amber = Color(0xFFFFC176); // highlight
  static const Color sand = Color(0xFFFFE0B8); // light accent

  // Neutrals
  static const Color haze = Color(0xFFFDF2E4); // light tint surface
  static const Color paper = Color(0xFFFFFAF3); // background (light)
  static const Color muted = Color(0xFF7A6A58); // secondary text on light
  static const Color mutedDark = Color(0xFFA8927B); // secondary text on dark

  /// On-color helpers.
  ///
  /// Orange is a surface, never a text colour: white on [signal] is 2.5:1 and
  /// fails WCAG AA, while [ink] on [signal] clears 7:1. Anything painted on a
  /// brand fill uses [onSignal]; orange-family *text* on a light background
  /// uses [rust] instead.
  static const Color onSignal = ink;
  static const Color onInk = paper;
}
