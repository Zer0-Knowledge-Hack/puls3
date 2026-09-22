import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for every puls3 design token.
///
/// Visual universe v0: Stellar-native in spirit (dark canvas, halftone
/// textures, serif + sans pairing) but deliberately distinct from the
/// official SDF palette. The accent is amber, never Stellar yellow.
abstract final class Puls3Colors {
  static const Color background = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF16161A);
  static const Color surface2 = Color(0xFF1F1F25);
  static const Color border = Color(0xFF2C2C34);
  static const Color text = Color(0xFFF6F7F8);
  static const Color textMuted = Color(0xFFA3A3AD);
  static const Color accent = Color(0xFFFFB547);
  static const Color onAccent = Color(0xFF0B0B0D);
  static const Color secondary = Color(0xFFA99CF2);
  static const Color success = Color(0xFF2BD4A0);
  static const Color error = Color(0xFFFF6B6B);
  static const Color transparent = Color(0x00000000);
  static const Color scrim = Color(0xCC0B0B0D);
}

abstract final class Puls3Spacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 72;

  /// Maximum content width on wide screens.
  static const double maxContentWidth = 1180;
}

abstract final class Puls3Radius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

abstract final class Puls3Durations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration pulse = Duration(milliseconds: 3600);
}

/// Font switch. Tests turn Google Fonts off so they never hit the network.
abstract final class Puls3Fonts {
  static bool useGoogleFonts = true;

  static TextStyle display(TextStyle base) =>
      useGoogleFonts ? GoogleFonts.instrumentSerif(textStyle: base) : base;

  static TextStyle sans(TextStyle base) =>
      useGoogleFonts ? GoogleFonts.manrope(textStyle: base) : base;

  static TextStyle mono(TextStyle base) =>
      useGoogleFonts ? GoogleFonts.jetBrainsMono(textStyle: base) : base;
}

abstract final class Puls3Text {
  static TextStyle get displayXl => Puls3Fonts.display(
    const TextStyle(
      fontSize: 76,
      height: 1.0,
      letterSpacing: -1.5,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get displayLg => Puls3Fonts.display(
    const TextStyle(
      fontSize: 52,
      height: 1.05,
      letterSpacing: -1,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get displayMd => Puls3Fonts.display(
    const TextStyle(
      fontSize: 36,
      height: 1.1,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get wordmark => Puls3Fonts.display(
    const TextStyle(
      fontSize: 28,
      height: 1,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get titleLg => Puls3Fonts.sans(
    const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get titleMd => Puls3Fonts.sans(
    const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get body => Puls3Fonts.sans(
    const TextStyle(
      fontSize: 15,
      height: 1.5,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get bodyMuted => Puls3Fonts.sans(
    const TextStyle(
      fontSize: 15,
      height: 1.5,
      color: Puls3Colors.textMuted,
    ),
  );

  static TextStyle get lead => Puls3Fonts.sans(
    const TextStyle(
      fontSize: 19,
      height: 1.45,
      color: Puls3Colors.textMuted,
    ),
  );

  static TextStyle get label => Puls3Fonts.sans(
    const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get overline => Puls3Fonts.sans(
    const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: Puls3Colors.textMuted,
    ),
  );

  static TextStyle get button => Puls3Fonts.sans(
    const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );

  static TextStyle get mono => Puls3Fonts.mono(
    const TextStyle(
      fontSize: 13,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get monoLg => Puls3Fonts.mono(
    const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Puls3Colors.text,
    ),
  );
}

abstract final class Puls3Theme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Puls3Colors.accent,
      onPrimary: Puls3Colors.onAccent,
      secondary: Puls3Colors.secondary,
      onSecondary: Puls3Colors.onAccent,
      surface: Puls3Colors.surface,
      onSurface: Puls3Colors.text,
      error: Puls3Colors.error,
      onError: Puls3Colors.onAccent,
    );

    final baseText = ThemeData.dark().textTheme.apply(
      bodyColor: Puls3Colors.text,
      displayColor: Puls3Colors.text,
    );
    final textTheme = Puls3Fonts.useGoogleFonts
        ? GoogleFonts.manropeTextTheme(baseText)
        : baseText;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: Puls3Radius.mdAll,
      borderSide: BorderSide(color: color),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Puls3Colors.background,
      canvasColor: Puls3Colors.background,
      textTheme: textTheme,
      dividerColor: Puls3Colors.border,
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Puls3Colors.surface2,
        labelStyle: Puls3Text.bodyMuted,
        hintStyle: Puls3Text.bodyMuted,
        floatingLabelStyle: Puls3Text.label.copyWith(color: Puls3Colors.accent),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Puls3Spacing.md,
          vertical: Puls3Spacing.md,
        ),
        border: border(Puls3Colors.border),
        enabledBorder: border(Puls3Colors.border),
        focusedBorder: border(Puls3Colors.accent),
        errorBorder: border(Puls3Colors.error),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Puls3Colors.surface2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Puls3Colors.surface,
        surfaceTintColor: Puls3Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Puls3Colors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Puls3Radius.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Puls3Colors.surface2,
        contentTextStyle: Puls3Text.body,
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Puls3Colors.accent,
      ),
    );
  }
}
