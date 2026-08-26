import 'package:flutter/material.dart';
import 'swift_colors.dart';

/// The signature "Slipstream" gradient — rust → amber, the axis of motion.
/// Use for hero surfaces, primary buttons, the splash background, etc.
class SwiftGradients {
  SwiftGradients._();

  /// Diagonal slipstream: lower-left (rust) to upper-right (amber).
  static const LinearGradient slipstream = LinearGradient(
    begin: Alignment(-0.76, 1.0),
    end: Alignment(0.80, -0.92),
    colors: [
      SwiftColors.rust,
      SwiftColors.signal,
      SwiftColors.flame,
      SwiftColors.amber,
    ],
    stops: [0.0, 0.40, 0.72, 1.0],
  );

  /// Horizontal version (rust → sand), good for thin bars / dividers.
  static const LinearGradient slipstreamBar = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      SwiftColors.rust,
      SwiftColors.signal,
      SwiftColors.flame,
      SwiftColors.amber,
      SwiftColors.sand,
    ],
    stops: [0.0, 0.38, 0.68, 0.88, 1.0],
  );

  /// Deep brand wash for full-bleed hero panels (splash, onboarding, empty
  /// states). Darker at the foot so white body copy stays readable over it.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SwiftColors.flame, SwiftColors.signal, SwiftColors.ember],
    stops: [0.0, 0.52, 1.0],
  );

  /// Subtle dark page gradient for ink backgrounds.
  static const LinearGradient pageDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C1712), SwiftColors.ink],
  );
}
