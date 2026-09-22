import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/ui/atoms/puls3_logo.dart';

void main() {
  group('Puls3LogoRules.variantFor (lockup)', () {
    test('uses the solid 3 below a 72 px mark', () {
      expect(Puls3LogoRules.variantFor(24), Puls3LogoVariant.solid);
      expect(Puls3LogoRules.variantFor(28), Puls3LogoVariant.solid);
      expect(Puls3LogoRules.variantFor(71.9), Puls3LogoVariant.solid);
    });

    test('uses the halftone 3 from a 72 px mark', () {
      expect(Puls3LogoRules.variantFor(72), Puls3LogoVariant.halftone);
      expect(Puls3LogoRules.variantFor(120), Puls3LogoVariant.halftone);
    });

    test('maps variants to the official files', () {
      expect(
        Puls3LogoRules.lockupAssetFor(28),
        'assets/brand/logo/puls3-logo-dark-small.svg',
      );
      expect(
        Puls3LogoRules.lockupAssetFor(80),
        'assets/brand/logo/puls3-logo-dark.svg',
      );
    });

    test('keeps the lockup aspect ratio of the view box', () {
      final size = Puls3LogoRules.lockupSize(128);
      expect(size.width, closeTo(508.4, 0.01));
      expect(size.height, closeTo(140, 0.01));
    });
  });

  group('Puls3LogoRules.markAssetFor', () {
    test('uses C01 full from 48 px', () {
      expect(
        Puls3LogoRules.markAssetFor(48),
        'assets/brand/mark/puls3-mark-c01-dark.svg',
      );
      expect(
        Puls3LogoRules.markAssetFor(96),
        'assets/brand/mark/puls3-mark-c01-dark.svg',
      );
    });

    test('uses the largest C01-small level that fits below 48 px', () {
      expect(
        Puls3LogoRules.markAssetFor(47),
        'assets/brand/mark/puls3-mark-c01-small-32-dark.svg',
      );
      expect(
        Puls3LogoRules.markAssetFor(28),
        'assets/brand/mark/puls3-mark-c01-small-24-dark.svg',
      );
      expect(
        Puls3LogoRules.markAssetFor(16),
        'assets/brand/mark/puls3-mark-c01-small-16-dark.svg',
      );
      expect(
        Puls3LogoRules.markAssetFor(12),
        'assets/brand/mark/puls3-mark-c01-small-16-dark.svg',
      );
    });
  });

  testWidgets('Puls3Logo renders the variant for its size', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Puls3Logo(key: Key('small'), markHeight: 28),
            Puls3Logo(key: Key('large'), markHeight: 80),
          ],
        ),
      ),
    );

    final small = tester.widget<Puls3Logo>(find.byKey(const Key('small')));
    final large = tester.widget<Puls3Logo>(find.byKey(const Key('large')));
    expect(small.variant, Puls3LogoVariant.solid);
    expect(large.variant, Puls3LogoVariant.halftone);

    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(
      tester.getSize(find.byKey(const Key('large'))).height,
      closeTo(80 * 140 / 128, 0.01),
    );
  });
}
