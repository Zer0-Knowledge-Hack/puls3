import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/brand/brand_kit.dart';
import 'package:puls3_flutter/src/brand/brand_policy.dart';
import 'package:puls3_flutter/src/screens/brand_screen.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/molecules/brand_asset_card.dart';
import 'package:puls3_flutter/src/ui/organisms/brand_policy_section.dart';

import '../helpers.dart';

/// What a pumped brand page did: files opened and text copied.
class BrandHarness {
  final opened = <String>[];
  final copied = <String>[];
}

Future<BrandHarness> pumpBrand(
  WidgetTester tester, {
  Size size = const Size(1440, 1000),
}) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = BrandHarness();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        harness.copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: Puls3Theme.dark(),
      home: BrandScreen(
        onOpenFile: harness.opened.add,
        loadSvg: (path) async => '<svg data-path="$path"/>',
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Finder card(BrandVariant v) => find.byKey(ValueKey('brand-card:${v.id}'));

Future<void> reveal(WidgetTester tester, BrandVariant v) async {
  await tester.ensureVisible(card(v));
  await tester.tap(card(v));
  await tester.pump();
}

void main() {
  testWidgets('/brand route renders the brand page', (tester) async {
    await pumpApp(tester, location: '/brand');
    expect(find.text('Brand guidelines'), findsOneWidget);
  });

  group('hero', () {
    testWidgets('centers the mark inside dashed construction guides', (
      tester,
    ) async {
      await pumpBrand(tester);
      expect(find.byKey(const ValueKey('brand-hero-guides')), findsOneWidget);
      expect(find.text('Brand guidelines'), findsOneWidget);
    });
  });

  group('logos', () {
    testWidgets('shows exactly the 8 curated cards, without labels', (
      tester,
    ) async {
      await pumpBrand(tester);
      expect(BrandKit.curated, hasLength(8));
      for (final v in BrandKit.variants) {
        expect(
          card(v),
          BrandKit.curated.contains(v) ? findsOneWidget : findsNothing,
          reason: v.id,
        );
      }
      expect(find.text(BrandKit.curated.first.label), findsNothing);
      // Each card sits on the background its file is drawn for.
      for (final v in BrandKit.curated) {
        final box = tester.widget<Container>(
          find.descendant(of: card(v), matching: find.byType(Container)).first,
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          v.background == BrandBackground.light
              ? BrandAssetCard.paper
              : Puls3Colors.background,
          reason: v.id,
        );
      }
      expect(
        find.text('Small sizes (16–32 px) are included in the full kit.'),
        findsOneWidget,
      );
    });

    testWidgets('Download all sits in the Logos header', (tester) async {
      final h = await pumpBrand(tester);
      expect(find.text('Logos'), findsOneWidget);
      await tester.ensureVisible(find.text('Download all'));
      await tester.tap(find.text('Download all'));
      expect(h.opened, [BrandKit.zip]);
    });

    testWidgets('actions stay hidden until the card is hovered or tapped', (
      tester,
    ) async {
      await pumpBrand(tester);
      final v = BrandKit.curated.first;
      expect(find.byKey(ValueKey('download:${v.svg}')), findsNothing);

      await reveal(tester, v);
      expect(find.byKey(ValueKey('download:${v.svg}')), findsOneWidget);
      expect(
        find.byKey(ValueKey('download:${v.png.last.path}')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('copy:${v.svg}')), findsOneWidget);
    });

    testWidgets('hovering a card reveals its actions', (tester) async {
      await pumpBrand(tester);
      final v = BrandKit.curated[1];
      await tester.ensureVisible(card(v));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(card(v)));
      await tester.pump();
      expect(find.byKey(ValueKey('copy:${v.svg}')), findsOneWidget);
    });

    testWidgets('PNG and SVG open the largest PNG and the SVG', (tester) async {
      final h = await pumpBrand(tester);
      final v = BrandKit.curated.last;
      await reveal(tester, v);
      await tester.tap(find.byKey(ValueKey('download:${v.png.last.path}')));
      await tester.tap(find.byKey(ValueKey('download:${v.svg}')));
      expect(h.opened, [v.png.last.path, v.svg]);
    });

    testWidgets('Copy SVG puts the markup on the clipboard', (tester) async {
      final h = await pumpBrand(tester);
      final v = BrandKit.curated.first;
      await reveal(tester, v);
      await tester.tap(find.byKey(ValueKey('copy:${v.svg}')));
      await tester.pump();
      expect(h.copied, ['<svg data-path="${v.svg}"/>']);
      expect(find.text('SVG copied'), findsOneWidget);
    });
  });

  group('colors', () {
    testWidgets('shows the four primary swatches with HEX, RGB and CMYK', (
      tester,
    ) async {
      await pumpBrand(tester);
      expect(find.text('Colors'), findsOneWidget);
      for (final s in BrandKit.primaryPalette) {
        expect(find.byKey(ValueKey('swatch:${s.token}')), findsOneWidget);
      }
      expect(find.text('CMYK (approx.)'), findsNWidgets(4));
      expect(find.text('#FFB547'), findsOneWidget);
      expect(find.text('255, 181, 71'), findsOneWidget);
      expect(find.text('0, 29, 72, 0'), findsOneWidget);
      expect(find.textContaining('Pantone'), findsNothing);
    });

    testWidgets('copies a value and confirms it', (tester) async {
      final h = await pumpBrand(tester);
      final copy = find.byKey(const ValueKey('copy:accent:HEX'));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      expect(h.copied, ['#FFB547']);
      expect(find.text('HEX copied'), findsOneWidget);
    });

    testWidgets('the rest of the palette is collapsed under Full palette', (
      tester,
    ) async {
      await pumpBrand(tester);
      expect(find.text('#A05F00'), findsNothing);
      await tester.ensureVisible(find.text('Full palette'));
      await tester.tap(find.text('Full palette'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('#A05F00'), findsOneWidget);
      expect(find.text('RGB 22 22 26'), findsOneWidget);
    });
  });

  group('guidelines', () {
    testWidgets('numbers the dimension rules with ok and too-small examples', (
      tester,
    ) async {
      await pumpBrand(tester);
      expect(find.text('Guidelines'), findsOneWidget);
      expect(find.text('Dimensions'), findsOneWidget);
      for (final n in [1, 2, 3, 4]) {
        final row = find.byKey(ValueKey('dimension:$n'));
        expect(row, findsOneWidget, reason: '$n');
        expect(
          find.descendant(of: row, matching: find.text('0$n')),
          findsOneWidget,
        );
      }
      expect(find.text('Minimum size'), findsNWidgets(3));
      for (final label in ['< 24 px', '< 16 px', '< 14 px']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Halftone at 72 px'), findsOneWidget);
      expect(find.text('Halftone below 72 px'), findsOneWidget);
      for (final px in [24, 16, 14, 72]) {
        expect(find.byKey(ValueKey('ruler:$px')), findsOneWidget);
        expect(find.text('$px px'), findsOneWidget, reason: '$px');
      }
    });

    testWidgets('draws the 4c safe-space diagram', (tester) async {
      await pumpBrand(tester);
      expect(find.text('Safe space'), findsWidgets);
      expect(find.byKey(const ValueKey('safe-space-diagram')), findsOneWidget);
      expect(find.text('4c'), findsWidgets);
    });
  });

  group('usage', () {
    testWidgets("renders the do's and don'ts as visual examples", (
      tester,
    ) async {
      await pumpBrand(tester);
      expect(find.text("Usage Do's"), findsOneWidget);
      expect(find.text("Usage Don'ts"), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('usage-do:'),
        ),
        findsNWidgets(4),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('usage-dont:'),
        ),
        findsNWidgets(9),
      );
      expect(
        find.text('Never recolor the logo with Stellar yellow (#FDDA24).'),
        findsOneWidget,
      );
      expect(find.text('Use the official files, unaltered.'), findsOneWidget);
    });
  });

  group('using puls3 in your project', () {
    testWidgets('lists what projects can do, avoid and are expected to do', (
      tester,
    ) async {
      await pumpBrand(tester);
      expect(find.text(BrandPolicy.title), findsOneWidget);
      expect(find.text('What you can do'), findsOneWidget);
      expect(find.text('What to avoid'), findsOneWidget);
      expect(find.text('Expectations'), findsOneWidget);
      for (final rule in [...BrandPolicy.canDo, ...BrandPolicy.avoid]) {
        expect(find.text(rule), findsOneWidget, reason: rule);
      }
      for (final e in BrandPolicy.expectations) {
        expect(find.text(e.title), findsOneWidget, reason: e.title);
      }
    });

    testWidgets('renders no email link while the contact is unset', (
      tester,
    ) async {
      await pumpBrand(tester);
      expect(BrandPolicy.contactEmail, isNull);
      expect(find.byKey(const ValueKey('policy-contact-email')), findsNothing);
    });

    testWidgets('renders the email link once a contact is set', (
      tester,
    ) async {
      Puls3Fonts.useGoogleFonts = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: Puls3Theme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: BrandPolicySection(contactEmail: 'brand@example.com'),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('policy-contact-email')),
        findsOneWidget,
      );
    });
  });

  testWidgets('lays out on a 360 px phone without overflow', (tester) async {
    await pumpBrand(tester, size: const Size(360, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Brand guidelines'), findsOneWidget);
  });

  testWidgets('lays out on a tablet without overflow', (tester) async {
    await pumpBrand(tester, size: const Size(800, 1000));
    expect(tester.takeException(), isNull);
  });
}
