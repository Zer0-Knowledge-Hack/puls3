import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/brand/brand_kit.dart';

/// The kit is produced by `npm run brand:kit` (design/logo-lab) into
/// web/brand/. These tests keep the Dart mirror in sync with it.
void main() {
  final webBrand = Directory('web/brand');

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File('${webBrand.path}/$path').readAsStringSync())
          as Map<String, dynamic>;

  test('every file the page links to exists under web/brand', () {
    final paths = [
      BrandKit.zip,
      BrandKit.guide,
      for (final v in BrandKit.variants) ...[
        v.svg,
        for (final png in v.png) png.path,
      ],
    ];
    for (final path in paths) {
      expect(
        File('${webBrand.path}/$path').existsSync(),
        isTrue,
        reason: 'missing web/brand/$path (run npm run brand:kit)',
      );
    }
  });

  test('variants mirror manifest.json', () {
    final manifest = readJson('manifest.json');
    expect(manifest['zip'], BrandKit.zip);
    expect(manifest['guide'], BrandKit.guide);
    final entries = (manifest['variants'] as List).cast<Map<String, dynamic>>();
    expect(
      [for (final v in BrandKit.variants) v.id],
      [for (final e in entries) e['id']],
    );
    for (var i = 0; i < entries.length; i++) {
      final v = BrandKit.variants[i];
      final e = entries[i];
      expect(v.group.name, e['group']);
      expect(v.label, e['label']);
      expect(v.background.name, e['background']);
      expect(v.svg, e['svg']);
      expect(
        [for (final p in v.png) '${p.width}:${p.path}'],
        [for (final p in (e['png'] as List)) '${p['width']}:${p['path']}'],
      );
    }
  });

  test('every variant has an SVG and at least two PNG sizes', () {
    for (final v in BrandKit.variants) {
      expect(v.svg, endsWith('.svg'));
      expect(v.png.length, greaterThanOrEqualTo(2), reason: v.id);
    }
  });

  test('swatches mirror tokens.json', () {
    final colors = readJson('tokens.json')['color'] as Map<String, dynamic>;
    String hexOf(String palette, String token) =>
        (colors[palette] as Map<String, dynamic>)[token]['value'] as String;

    for (final s in BrandKit.darkPalette) {
      expect(s.hex, hexOf('dark', s.token), reason: s.token);
    }
    for (final s in BrandKit.lightPalette) {
      expect(s.hex, hexOf('light', s.token), reason: s.token);
    }
    expect(BrandKit.darkPalette.length, (colors['dark'] as Map).length);
    expect(BrandKit.lightPalette.length, (colors['light'] as Map).length);
  });

  test('the page curates every colorway of the lockup and the mark', () {
    expect(
      [for (final v in BrandKit.curated) v.id],
      [
        'puls3-logo-dark',
        'puls3-logo-light',
        'puls3-logo-mono-white',
        'puls3-logo-mono-ink',
        'puls3-mark-c01-dark',
        'puls3-mark-c01-light',
        'puls3-mark-c01-mono-white',
        'puls3-mark-c01-mono-ink',
      ],
    );
    // Small sizes stay in the ZIP and manifest only.
    expect(BrandKit.curated.where((v) => v.id.contains('small')), isEmpty);
  });

  test('curated SVGs are bundled as Flutter assets for Copy SVG', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- web/brand/svg/logo/'));
    expect(pubspec, contains('- web/brand/svg/mark/'));
    expect(
      brandAssetKey('svg/logo/puls3-logo-dark.svg'),
      'web/brand/svg/logo/puls3-logo-dark.svg',
    );
  });

  test('swatch RGB is derived from the HEX value', () {
    const swatch = BrandSwatch(token: 'accent', hex: '#FFB547', role: '');
    expect(swatch.rgb, 'RGB 255 181 71');
    expect(swatch.color.toARGB32(), 0xFFFFB547);
  });

  test('swatch values are formatted for copying', () {
    const accent = BrandSwatch(token: 'accent', hex: '#FFB547', role: '');
    expect(accent.rgbValues, '255, 181, 71');
    expect(accent.cmykValues, '0, 29, 72, 0');
    expect(
      const BrandSwatch(token: 'w', hex: '#FFFFFF', role: '').cmykValues,
      '0, 0, 0, 0',
    );
    expect(
      const BrandSwatch(token: 'k', hex: '#000000', role: '').cmykValues,
      '0, 0, 0, 100',
    );
  });

  test('the primary palette is background, text, accent and lavender', () {
    expect(
      [for (final s in BrandKit.primaryPalette) s.token],
      [
        'background',
        'text',
        'accent',
        'lavender',
      ],
    );
    for (final s in BrandKit.primaryPalette) {
      expect(BrandKit.darkPalette, contains(s));
    }
  });

  test('brand files resolve to relative web URLs', () {
    expect(brandFileUrl(BrandKit.zip).toString(), 'brand/puls3-brand-kit.zip');
    expect(
      brandFileUrl('svg/logo/puls3-logo-dark.svg').toString(),
      'brand/svg/logo/puls3-logo-dark.svg',
    );
    expect(brandFileUrl('/png/x.png').toString(), 'brand/png/x.png');
  });
}
