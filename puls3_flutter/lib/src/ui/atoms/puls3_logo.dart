import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/puls3_theme.dart';

/// Which lockup file to render.
enum Puls3LogoVariant {
  /// C01 full with the halftone "3" (`puls3-logo-dark.svg`).
  halftone,

  /// C01-small with the solid accent "3" (`puls3-logo-dark-small.svg`).
  solid,
}

/// Size rules from the brand guide (page 06), as pure functions so they are
/// easy to test.
abstract final class Puls3LogoRules {
  static const lockupHalftoneAsset = 'assets/brand/logo/puls3-logo-dark.svg';
  static const lockupSolidAsset = 'assets/brand/logo/puls3-logo-dark-small.svg';
  static const markFullAsset = 'assets/brand/mark/puls3-mark-c01-dark.svg';

  static String markSmallAsset(int level) =>
      'assets/brand/mark/puls3-mark-c01-small-$level-dark.svg';

  /// The lockup files use a `-6 -6 508.4 140` view box and the mark fills
  /// 128 units of that height.
  static const double _viewBoxWidth = 508.4;
  static const double _viewBoxHeight = 140;
  static const double _markUnits = 128;

  /// The halftone 3 is allowed only when the mark is at least 72 px tall
  /// (the rendered "3" is then at least 40 px).
  static Puls3LogoVariant variantFor(double markHeight) =>
      markHeight >= Puls3LogoTokens.lockupHalftoneMinMarkPx
      ? Puls3LogoVariant.halftone
      : Puls3LogoVariant.solid;

  static String lockupAssetFor(double markHeight) =>
      switch (variantFor(markHeight)) {
        Puls3LogoVariant.halftone => lockupHalftoneAsset,
        Puls3LogoVariant.solid => lockupSolidAsset,
      };

  /// Rendered lockup size for a given mark height.
  static Size lockupSize(double markHeight) {
    final scale = markHeight / _markUnits;
    return Size(_viewBoxWidth * scale, _viewBoxHeight * scale);
  }

  /// C01 full at 48 px and above. Below that, the largest C01-small level
  /// (32, 24 or 16) that fits.
  static String markAssetFor(double size) {
    if (size >= Puls3LogoTokens.markFullMinPx) return markFullAsset;
    for (final level in Puls3LogoTokens.markSmallLevels) {
      if (size >= level) return markSmallAsset(level);
    }
    return markSmallAsset(Puls3LogoTokens.markSmallLevels.last);
  }
}

/// The puls3 horizontal lockup (C01 mark + "puls3" in Unbounded 700), from
/// the official outlined SVGs. The variant is picked from [markHeight].
class Puls3Logo extends StatelessWidget {
  const Puls3Logo({super.key, required this.markHeight, this.onTap})
    : assert(markHeight >= Puls3LogoTokens.minLockupMarkPx);

  /// Rendered height of the C01 mark in logical pixels.
  final double markHeight;
  final VoidCallback? onTap;

  Puls3LogoVariant get variant => Puls3LogoRules.variantFor(markHeight);

  @override
  Widget build(BuildContext context) {
    final size = Puls3LogoRules.lockupSize(markHeight);
    final logo = SvgPicture.asset(
      Puls3LogoRules.lockupAssetFor(markHeight),
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      semanticsLabel: 'puls3',
    );
    if (onTap == null) return logo;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: logo),
    );
  }
}

/// The C01 Halftone Pulse mark on its own. C01 full at 48 px and above,
/// C01-small below.
class Puls3Mark extends StatelessWidget {
  const Puls3Mark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      Puls3LogoRules.markAssetFor(size),
      width: size,
      height: size,
      semanticsLabel: 'puls3 mark',
    );
  }
}
