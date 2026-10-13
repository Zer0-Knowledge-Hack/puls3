import 'dart:ui' show Rect, Size;

import '../theme/puls3_theme.dart';

/// Logo geometry and the size and clear-space rules from
/// docs/brand/README.md (sections 06 and 07), checked against
/// design/logo-lab/src/brand/logo.tsx and the outlined SVGs.
abstract final class BrandGeometry {
  /// The lockup SVGs use a `-6 -6 508.4 140` view box; the mark fills 128
  /// units of its height.
  static const Rect lockupViewBox = Rect.fromLTWH(-6, -6, 508.4, 140);
  static const double markUnits = 128;

  /// The wordmark box inside the lockup view box: the glyphs are placed at
  /// `translate(168 90) scale(0.0910683)` and logo.tsx measures the
  /// wordmark from ascender to descender (font units -800 to 195, with its
  /// 30-unit pad), from x = -30 to the end of the "3" plus the pad.
  static const Rect wordmarkInLockup = Rect.fromLTRB(
    165.27,
    17.15,
    485.1,
    107.76,
  );

  /// c = the diameter of the C01 center dot (r 4.6 of 128 in the SVG).
  static const double centerDotRatio = 0.072;

  /// Clear space on every side, in multiples of c.
  static const int clearSpaceC = 4;

  /// Digital minimums (README 07).
  static const double minLockupMarkPx = Puls3LogoTokens.minLockupMarkPx;
  static const double minMarkPx = 16;
  static const double minWordmarkPx = 14;

  /// The halftone 3 needs a lockup mark of at least this height (README 06;
  /// logo.tsx derives the same 72 from the 40 px "3").
  static const double halftoneMinMarkPx =
      Puls3LogoTokens.lockupHalftoneMinMarkPx;

  static double c(double markHeight) => centerDotRatio * markHeight;

  /// Rendered size of the whole lockup SVG for a mark of [markHeight].
  static Size lockupSize(double markHeight) {
    final scale = markHeight / markUnits;
    return Size(lockupViewBox.width * scale, lockupViewBox.height * scale);
  }

  /// The mark's offset from the top of the rendered lockup.
  static double markTop(double markHeight) =>
      -lockupViewBox.top * markHeight / markUnits;
}
