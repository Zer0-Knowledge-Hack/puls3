import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for every puls3 design token.
///
/// Values and names come from `docs/brand/tokens.json` (puls3 Brand
/// Guidelines 2026). The shell is dark-only, so only the dark color set is
/// used. This is the only file in `lib/` that may declare colors or fonts.
abstract final class Puls3Colors {
  // Dark palette, exactly as in tokens.json `color.dark`.
  static const Color background = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF16161A);
  static const Color text = Color(0xFFF6F7F8);
  static const Color muted = Color(0xFFA3A3AD);
  static const Color accent = Color(0xFFFFB547);
  static const Color lavender = Color(0xFFA99CF2);
  static const Color success = Color(0xFF2BD4A0);
  static const Color hairline = Color(0xFF2A2A31);

  // Role aliases. These add no new values.
  /// Text on `accent` (the guide's "ink on accent", 11.19:1).
  static const Color onAccent = background;

  /// Fully transparent, for layers that must not paint.
  static const Color transparent = Colors.transparent;
}

/// Spacing scale from tokens.json `spacing`.
abstract final class Puls3Spacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  static const double huge = 96;

  /// Maximum content width on wide screens (layout, not a brand token).
  static const double maxContentWidth = 1180;

  /// Height of the app top bar (guide page 14).
  static const double topBarHeight = 56;
}

/// Radius scale from tokens.json `radius`.
abstract final class Puls3Radius {
  static const double sm = 8;
  static const double md = 12;
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

  /// A calm pulse (guide page 12: never faster than a calm pulse).
  static const Duration pulse = Duration(milliseconds: 4200);
}

/// Logo size thresholds from tokens.json `logo`.
abstract final class Puls3LogoTokens {
  /// The halftone "3" needs the rendered 3 to be at least this tall.
  static const double threeHalftoneMinPx = 40;

  /// Lockup: halftone 3 only when the mark is at least this tall.
  static const double lockupHalftoneMinMarkPx = 72;

  /// Wordmark alone: halftone 3 only when it is at least this tall.
  static const double wordmarkHalftoneMinHeightPx = 51;

  /// C01 full at or above this size; C01-small below.
  static const double markFullMinPx = 48;

  /// Pixel-fitted C01-small levels, largest first.
  static const List<int> markSmallLevels = [32, 24, 16];

  /// Digital minimum mark height in the lockup.
  static const double minLockupMarkPx = 24;
}

/// Font families. Tests turn Google Fonts off so they never hit the network.
abstract final class Puls3Fonts {
  static bool useGoogleFonts = true;

  /// Self-hosted accent face (`assets/fonts/Doto-ROND-wght.ttf`).
  static const String dotoFamily = 'Doto';

  /// Unbounded: display and headlines.
  static TextStyle display(TextStyle base) =>
      useGoogleFonts ? GoogleFonts.unbounded(textStyle: base) : base;

  /// Manrope: UI and body.
  static TextStyle ui(TextStyle base) =>
      useGoogleFonts ? GoogleFonts.manrope(textStyle: base) : base;

  /// JetBrains Mono: addresses, hashes, prices.
  static TextStyle data(TextStyle base) =>
      useGoogleFonts ? GoogleFonts.jetBrainsMono(textStyle: base) : base;

  /// Doto 900 with ROND 100: accents only (stats, status, big numbers).
  /// Never the logo, never body text, never small UI labels.
  static TextStyle accent(TextStyle base) => base.copyWith(
    fontFamily: dotoFamily,
    fontWeight: FontWeight.w900,
    fontVariations: const [
      FontVariation('ROND', 100),
      FontVariation('wght', 900),
    ],
  );
}

/// Type scale from tokens.json `typography.scale` (px): display 72, h1 56,
/// h2 36, h3 24, body 16, caption 13, data 13. The guide pairs h1 and h2 with
/// compact sizes of 44 and 28.
abstract final class Puls3Text {
  // Display: Unbounded.
  static TextStyle get display => Puls3Fonts.display(
    const TextStyle(
      fontSize: 72,
      height: 1.02,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get h1 => Puls3Fonts.display(
    const TextStyle(
      fontSize: 56,
      height: 1.05,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get h1Compact => h1.copyWith(fontSize: 44);

  static TextStyle get h2 => Puls3Fonts.display(
    const TextStyle(
      fontSize: 36,
      height: 1.1,
      fontWeight: FontWeight.w500,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get h2Compact => h2.copyWith(fontSize: 28);

  static TextStyle get h3 => Puls3Fonts.display(
    const TextStyle(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: Puls3Colors.text,
    ),
  );

  // UI: Manrope.
  static TextStyle get title => Puls3Fonts.ui(
    const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get lead => Puls3Fonts.ui(
    const TextStyle(
      fontSize: 18,
      height: 1.5,
      color: Puls3Colors.muted,
    ),
  );

  static TextStyle get body => Puls3Fonts.ui(
    const TextStyle(
      fontSize: 16,
      height: 1.5,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get bodyMuted => body.copyWith(color: Puls3Colors.muted);

  static TextStyle get caption => Puls3Fonts.ui(
    const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get button => Puls3Fonts.ui(
    const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );

  // Data: JetBrains Mono.
  static TextStyle get data => Puls3Fonts.data(
    const TextStyle(
      fontSize: 13,
      color: Puls3Colors.text,
    ),
  );

  static TextStyle get dataLg => Puls3Fonts.data(
    const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: Puls3Colors.text,
    ),
  );

  /// Section eyebrow, e.g. "03 · PRIMARY LOGO" in the guide.
  static TextStyle get eyebrow => Puls3Fonts.data(
    const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.4,
      color: Puls3Colors.muted,
    ),
  );

  // Accent: Doto. Big numbers, stats and status labels only.
  static TextStyle get accentXl => Puls3Fonts.accent(
    const TextStyle(
      fontSize: 64,
      height: 1,
      color: Puls3Colors.accent,
    ),
  );

  static TextStyle get accentLg => Puls3Fonts.accent(
    const TextStyle(
      fontSize: 40,
      height: 1,
      color: Puls3Colors.accent,
    ),
  );

  static TextStyle get accentMd => Puls3Fonts.accent(
    const TextStyle(
      fontSize: 24,
      height: 1.1,
      letterSpacing: 1,
      color: Puls3Colors.accent,
    ),
  );
}

abstract final class Puls3Theme {
  static ThemeData dark() {
    // tokens.json has no error color, so validation messages use the accent
    // (amber reads as a warning and keeps AA contrast on surface).
    const scheme = ColorScheme.dark(
      primary: Puls3Colors.accent,
      onPrimary: Puls3Colors.onAccent,
      secondary: Puls3Colors.lavender,
      onSecondary: Puls3Colors.onAccent,
      surface: Puls3Colors.surface,
      onSurface: Puls3Colors.text,
      error: Puls3Colors.accent,
      onError: Puls3Colors.onAccent,
      outline: Puls3Colors.hairline,
      outlineVariant: Puls3Colors.hairline,
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
      dividerColor: Puls3Colors.hairline,
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Puls3Colors.surface,
        labelStyle: Puls3Text.bodyMuted,
        hintStyle: Puls3Text.bodyMuted,
        floatingLabelStyle: Puls3Text.caption.copyWith(
          color: Puls3Colors.accent,
        ),
        errorStyle: Puls3Text.caption.copyWith(color: Puls3Colors.accent),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Puls3Spacing.md,
          vertical: Puls3Spacing.md,
        ),
        border: border(Puls3Colors.hairline),
        enabledBorder: border(Puls3Colors.hairline),
        focusedBorder: border(Puls3Colors.accent),
        errorBorder: border(Puls3Colors.accent),
        focusedErrorBorder: border(Puls3Colors.accent),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Puls3Colors.surface,
        surfaceTintColor: Puls3Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Puls3Colors.hairline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Puls3Radius.lg),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: Puls3Colors.surface,
          borderRadius: Puls3Radius.smAll,
        ),
        textStyle: Puls3Text.data,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Puls3Colors.accent,
      ),
    );
  }
}
