import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../brand/brand_geometry.dart';
import 'puls3_logo.dart';

/// The lockup drawn with its mark exactly [markHeight] tall, with no size
/// assertion, so the brand page can also show sizes that break the rules.
class LockupSample extends StatelessWidget {
  const LockupSample({
    super.key,
    required this.markHeight,
    this.halftone = false,
    this.asset,
  });

  final double markHeight;

  /// The halftone 3 file instead of the solid 3 one.
  final bool halftone;

  /// Another lockup file (another colorway); defaults to the dark one.
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final size = BrandGeometry.lockupSize(markHeight);
    return SvgPicture.asset(
      asset ??
          (halftone
              ? Puls3LogoRules.lockupHalftoneAsset
              : Puls3LogoRules.lockupSolidAsset),
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}

/// The C01 mark at [size], allowed below the 16 px minimum.
class MarkSample extends StatelessWidget {
  const MarkSample({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      Puls3LogoRules.markAssetFor(size),
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

/// The wordmark alone, [height] tall (ascender to descender), cut out of the
/// small lockup file so it is never retyped.
class WordmarkSample extends StatelessWidget {
  const WordmarkSample({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    const box = BrandGeometry.lockupViewBox;
    const word = BrandGeometry.wordmarkInLockup;
    final scale = height / word.height;
    return SizedBox(
      width: word.width * scale,
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(
              (box.left - word.left) * scale,
              (box.top - word.top) * scale,
            ),
            child: SvgPicture.asset(
              Puls3LogoRules.lockupSolidAsset,
              width: box.width * scale,
              height: box.height * scale,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
