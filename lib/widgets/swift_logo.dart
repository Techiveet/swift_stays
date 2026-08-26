import 'package:flutter/material.dart';
import '../theme/swift_gradients.dart';
import '../theme/swift_colors.dart';

enum SwiftLogoVariant { symbol, horizontal, stacked }

/// Displays the Swift logo from bundled assets.
/// For [horizontal] / [stacked] it auto-picks the light or dark artwork
/// based on the current theme brightness (override with [onDark]).
class SwiftLogo extends StatelessWidget {
  const SwiftLogo({
    super.key,
    this.variant = SwiftLogoVariant.symbol,
    this.height,
    this.onDark,
    this.mono = false,
  });

  final SwiftLogoVariant variant;
  final double? height;
  final bool? onDark;

  /// Use the all-white cut. Required on brand-orange fills, where the normal
  /// orange mark disappears into the background.
  final bool mono;

  String _assetFor(bool dark) {
    switch (variant) {
      case SwiftLogoVariant.symbol:
        return dark || mono
            ? 'assets/branding/swift_symbol_white.png'
            : 'assets/branding/swift_symbol.png';
      case SwiftLogoVariant.horizontal:
        if (mono) return 'assets/branding/swift_logo_horizontal_mono.png';
        return dark
            ? 'assets/branding/swift_logo_horizontal_dark.png'
            : 'assets/branding/swift_logo_horizontal_light.png';
      case SwiftLogoVariant.stacked:
        if (mono) return 'assets/branding/swift_logo_stacked_mono.png';
        return dark
            ? 'assets/branding/swift_logo_stacked_dark.png'
            : 'assets/branding/swift_logo_stacked_light.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = onDark ?? Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      _assetFor(dark),
      height: height ?? (variant == SwiftLogoVariant.symbol ? 56 : 40),
      fit: BoxFit.contain,
    );
  }
}

/// The logo flying in: the mark eases up from below while the slipstream
/// fades in behind it. Used on the splash and on first-run empty states.
class SwiftLogoIntro extends StatefulWidget {
  const SwiftLogoIntro({
    super.key,
    this.variant = SwiftLogoVariant.stacked,
    this.height,
    this.onDark,
    this.mono = false,
  });

  final SwiftLogoVariant variant;
  final double? height;
  final bool? onDark;
  final bool mono;

  @override
  State<SwiftLogoIntro> createState() => _SwiftLogoIntroState();
}

class _SwiftLogoIntroState extends State<SwiftLogoIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: rise,
        child: SwiftLogo(
          variant: widget.variant,
          height: widget.height,
          onDark: widget.onDark,
          mono: widget.mono,
        ),
      ),
    );
  }
}

/// A primary CTA painted with the Slipstream gradient (Material can't
/// gradient-fill ElevatedButton directly, so use this for hero buttons).
class SwiftGradientButton extends StatelessWidget {
  const SwiftGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 54,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: SwiftColors.ember.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: Ink(
              height: height,
              decoration: BoxDecoration(
                gradient: SwiftGradients.slipstream,
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: SwiftColors.onSignal, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: SwiftColors.onSignal,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
