import 'package:flutter/material.dart';

class AppColors {
  // ═══════════════════════════════════════════════════════════════
  // EVERBLUSH - https://github.com/Everblush/everblush
  // Background #141b1e, Lighter #232a2d, Foreground #dadada
  // ═══════════════════════════════════════════════════════════════
  // DARK MODE - Backgrounds (true Everblush)
  // ═══════════════════════════════════════════════════════════════
  static const darkBg = Color(0xFF141B1E);
  static const darkSurface = Color(0xFF232A2D);
  static const darkSurfaceAlt = Color(0xFF2E383C);

  // ═══════════════════════════════════════════════════════════════
  // LIGHT MODE - Backgrounds (Modern Cool Tone)
  // ═══════════════════════════════════════════════════════════════
  static const lightBg = Color(0xFFFAFBFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF0F4F8);

  // ═══════════════════════════════════════════════════════════════
  // DARK MODE - Text Colors (Everblush: #dadada + #b3b9b8)
  // ═══════════════════════════════════════════════════════════════
  static const textDark = Color(0xFFDADADA);
  static const textDarkSecondary = Color(0xFFB3B9B8);
  static const textDarkTertiary = Color(0xFF7F8E8D);

  // ═══════════════════════════════════════════════════════════════
  // LIGHT MODE - Text Colors
  // ═══════════════════════════════════════════════════════════════
  static const textLight = Color(0xFF1A1F2E);
  static const textLightSecondary = Color(0xFF5A6B7A);
  static const textLightTertiary = Color(0xFF8A9AAA);

  // ═══════════════════════════════════════════════════════════════
  // ACTION COLORS - Everblush palette (dark)
  // ═══════════════════════════════════════════════════════════════
  static const green = Color(0xFF8CCF7E);
  static const blue = Color(0xFF67B0E8);
  static const cyan = Color(0xFF6CBFBF);

  // ═══════════════════════════════════════════════════════════════
  // ACTION COLORS - Light Mode
  // ═══════════════════════════════════════════════════════════════
  static const greenLight = Color(0xFF10B981);
  static const blueLight = Color(0xFF0EA5E9);
  static const cyanLight = Color(0xFF06B6D4);

  // ═══════════════════════════════════════════════════════════════
  // SEMANTIC COLORS - Everblush
  // ═══════════════════════════════════════════════════════════════
  static const red = Color(0xFFE57474);
  static const yellow = Color(0xFFE5C76B);
  static const yellowLight = Color(0xFFF59E0B);
  static const purple = Color(0xFFC47FD5);

  // ═══════════════════════════════════════════════════════════════
  // UI Elements - Light Mode
  // ═══════════════════════════════════════════════════════════════
  static const lightDivider = Color(0xFFE5E7EB);
  static const lightBorder = Color(0xFFD1D5DB);
  static const lightHoverBg = Color(0xFFF3F7FC);
  static const lightDisabled = Color(0xFFD1D5DB);

  // ═══════════════════════════════════════════════════════════════
  // UI Elements - Dark Mode (Everblush-tinted dividers/borders)
  // ═══════════════════════════════════════════════════════════════
  static const darkDivider = Color(0xFF2F3A3E);
  static const darkBorder = Color(0xFF3A464B);
  static const darkHoverBg = Color(0xFF2E383C);
  static const darkDisabled = Color(0xFF4A5559);
}

/// Accent colors selectable in Settings — all from Everblush palette.
enum AppAccent { red, green, yellow, blue, purple, cyan }

extension AppAccentX on AppAccent {
  Color get color => switch (this) {
        AppAccent.red => const Color(0xFFE57474),
        AppAccent.green => const Color(0xFF8CCF7E),
        AppAccent.yellow => const Color(0xFFE5C76B),
        AppAccent.blue => const Color(0xFF67B0E8),
        AppAccent.purple => const Color(0xFFC47FD5),
        AppAccent.cyan => const Color(0xFF6CBFBF),
      };

  String get label => switch (this) {
        AppAccent.red => 'Red',
        AppAccent.green => 'Green',
        AppAccent.yellow => 'Yellow',
        AppAccent.blue => 'Blue',
        AppAccent.purple => 'Purple',
        AppAccent.cyan => 'Cyan',
      };

  static AppAccent fromString(String? value) {
    switch (value) {
      case 'red':
        return AppAccent.red;
      case 'green':
        return AppAccent.green;
      case 'yellow':
        return AppAccent.yellow;
      case 'purple':
        return AppAccent.purple;
      case 'cyan':
        return AppAccent.cyan;
      case 'blue':
      default:
        return AppAccent.blue;
    }
  }
}
