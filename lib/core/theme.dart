import 'package:flutter/material.dart';

import '../theme/swift_colors.dart';

/// Thin alias layer over the shared Swift palette so the screens in this app
/// keep reading `AppColors.x` while the brand lives in one place.
class AppColors {
  static const Color primary = SwiftColors.signal;
  static const Color primaryDark = SwiftColors.rust;
  static const Color ink = SwiftColors.ink;
  static const Color scaffold = SwiftColors.paper;
  static const Color card = Colors.white;
  static const Color muted = SwiftColors.muted;
  static const Color border = Color(0xFFEADBC6);
  static const Color info = Color(0xFF2563EB);
  // Gold rather than amber: with an orange brand, an orange "warning" would
  // read as ordinary chrome instead of a state.
  static const Color warning = Color(0xFFCA8A04);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF15803D);
}

class AppTheme {
  static const String fontFamily = 'Outfit';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? SwiftColors.amber : SwiftColors.signal,
          // Ink on both cuts of the brand orange; white would sit at 2.5:1.
          onPrimary: SwiftColors.ink,
          surface: dark ? SwiftColors.graphite : Colors.white,
          onSurface: dark ? SwiftColors.paper : AppColors.ink,
          outline: dark ? const Color(0xFF39322B) : AppColors.border,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 28,
          height: 1.18,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          height: 1.22,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.5,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
      ),
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0C1510)
          : AppColors.scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF101C16) : AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: dark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: .12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: .45),
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: buttonShape,
          elevation: 1,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: .12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: .45),
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.primary, width: 1.5),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // Brand orange as *text* is 2.31:1 on white and fails AA. Ember is
          // the deepest cut of the ramp and clears 5:1.
          foregroundColor: dark ? SwiftColors.amber : SwiftColors.ember,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: .16),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFFF0F7F2) : AppColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: dark ? AppColors.ink : Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        // Icons need 3:1 against the surface; brand orange is 2.31:1.
        iconColor: dark ? SwiftColors.amber : SwiftColors.rust,
      ),
    );
  }
}
