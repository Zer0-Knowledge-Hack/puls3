import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/brand/brand_kit.dart';
import 'package:puls3_flutter/src/screens/brand_screen.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';

import '../helpers.dart';

Future<List<String>> pumpBrand(
  WidgetTester tester, {
  Size size = const Size(1440, 1000),
}) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: Puls3Theme.dark(),
      home: BrandScreen(onOpenFile: opened.add),
    ),
  );
  await tester.pump();
  return opened;
}

void main() {
  testWidgets('/brand route renders the brand page', (tester) async {
    await pumpApp(tester, location: '/brand');
    expect(find.text('puls3 brand kit'), findsOneWidget);
  });

  testWidgets('renders every section', (tester) async {
    await pumpBrand(tester);
    for (final title in [
      'Logo',
      'Mark',
      'Color',
      'Typography',
      'Size and clear space',
      'Usage',
      'Co-branding',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('Download all'), findsOneWidget);
  });

  testWidgets('every variant offers an SVG and its PNG sizes', (tester) async {
    await pumpBrand(tester);
    for (final v in BrandKit.variants) {
      expect(find.text(v.label), findsOneWidget, reason: v.id);
      expect(find.byKey(ValueKey('download:${v.svg}')), findsOneWidget);
      for (final png in v.png) {
        expect(find.byKey(ValueKey('download:${png.path}')), findsOneWidget);
      }
    }
  });

  testWidgets('download actions open the kit files', (tester) async {
    final opened = await pumpBrand(tester);

    await tester.tap(find.text('Download all'));
    final svg = find.byKey(ValueKey('download:${BrandKit.variants.first.svg}'));
    await tester.ensureVisible(svg);
    await tester.tap(svg);
    final png = BrandKit.variants.first.png.last.path;
    await tester.tap(find.byKey(ValueKey('download:$png')));

    expect(opened, [BrandKit.zip, BrandKit.variants.first.svg, png]);
  });

  testWidgets('shows HEX and RGB for each color', (tester) async {
    await pumpBrand(tester);
    expect(find.text('#FFB547'), findsWidgets);
    expect(find.text('RGB 255 181 71'), findsOneWidget);
    expect(find.text('#A05F00'), findsWidgets);
  });

  testWidgets('lays out on a phone without overflow', (tester) async {
    await pumpBrand(tester, size: const Size(390, 844));
    expect(find.text('puls3 brand kit'), findsOneWidget);
  });
}
