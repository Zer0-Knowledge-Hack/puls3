import 'dart:ui' show Color;

import 'package:url_launcher/url_launcher.dart';

/// Which surface a file is drawn for.
enum BrandBackground { dark, light }

/// The lockup or the mark on its own.
enum BrandGroup { logo, mark }

/// One PNG export of a variant.
class BrandPng {
  const BrandPng(this.width, this.path);

  final int width;

  /// Relative to `web/brand/`.
  final String path;
}

/// One downloadable logo or mark file, with its PNG exports.
class BrandVariant {
  const BrandVariant({
    required this.id,
    required this.group,
    required this.label,
    required this.background,
    required this.svg,
    required this.png,
  });

  /// Paths follow the layout written by `npm run brand:kit`.
  factory BrandVariant.of(
    BrandGroup group,
    String id,
    String label,
    BrandBackground background,
    List<int> widths,
  ) => BrandVariant(
    id: id,
    group: group,
    label: label,
    background: background,
    svg: 'svg/${group.name}/$id.svg',
    png: [
      for (final w in widths) BrandPng(w, 'png/${group.name}/$id-$w.png'),
    ],
  );

  final String id;
  final BrandGroup group;
  final String label;
  final BrandBackground background;

  /// Relative to `web/brand/`.
  final String svg;
  final List<BrandPng> png;

  /// The PNG used as the on-page preview.
  BrandPng get preview => png.last;
}

/// A color token from `docs/brand/tokens.json`.
class BrandSwatch {
  const BrandSwatch({
    required this.token,
    required this.hex,
    required this.role,
  });

  final String token;

  /// `#RRGGBB`.
  final String hex;
  final String role;

  int get _value => int.parse(hex.substring(1), radix: 16);

  Color get color => Color(0xFF000000 | _value);

  List<int> get _channels => [
    (_value >> 16) & 0xFF,
    (_value >> 8) & 0xFF,
    _value & 0xFF,
  ];

  String get rgb => 'RGB ${_channels.join(' ')}';

  /// `R, G, B`, ready to copy.
  String get rgbValues => _channels.join(', ');

  /// `C, M, Y, K` in percent, converted naively from RGB. Approximate: not
  /// a print profile, so it is labelled as such on the page.
  String get cmykValues {
    final [r, g, b] = [for (final c in _channels) c / 255];
    final k = 1 - [r, g, b].reduce((a, b) => a > b ? a : b);
    if (k >= 1) return '0, 0, 0, 100';
    int pct(double v) => (v * 100).round();
    double ink(double c) => (1 - c - k) / (1 - k);
    return [ink(r), ink(g), ink(b), k].map(pct).join(', ');
  }
}

/// The brand kit served from `web/brand/` (built by `npm run brand:kit` in
/// design/logo-lab). Mirrors `web/brand/manifest.json`; a test keeps them in
/// sync.
abstract final class BrandKit {
  static const zip = 'puls3-brand-kit.zip';
  static const guide = 'puls3-brand-guide.pdf';

  static final List<BrandVariant> variants = [
    for (final (suffix, labelPrefix, sizes) in [
      ('', 'Lockup', [1024, 2048]),
      ('-small', 'Small lockup', [256, 512]),
    ])
      for (final (color, label, bg) in _colorways)
        BrandVariant.of(
          BrandGroup.logo,
          'puls3-logo-$color$suffix',
          '$labelPrefix, $label',
          bg,
          sizes,
        ),
    BrandVariant.of(
      BrandGroup.mark,
      'puls3-mark-c01-dark',
      'Mark, on dark',
      BrandBackground.dark,
      [512, 1024],
    ),
    BrandVariant.of(
      BrandGroup.mark,
      'puls3-mark-c01-light',
      'Mark, on light',
      BrandBackground.light,
      [512, 1024],
    ),
    for (final (color, label, bg) in _colorways.skip(2))
      BrandVariant.of(
        BrandGroup.mark,
        'puls3-mark-c01-$color',
        'Mark, $label',
        bg,
        [512, 1024],
      ),
    for (final level in [32, 24, 16])
      for (final bg in BrandBackground.values)
        BrandVariant.of(
          BrandGroup.mark,
          'puls3-mark-c01-small-$level-${bg.name}',
          'Small mark $level px, on ${bg.name}',
          bg,
          [level, level * 2],
        ),
  ];

  static const _colorways = [
    ('dark', 'on dark', BrandBackground.dark),
    ('light', 'on light', BrandBackground.light),
    ('mono-white', 'mono white', BrandBackground.dark),
    ('mono-ink', 'mono ink', BrandBackground.light),
  ];

  /// The files shown on the page: the full-size lockup and the full mark in
  /// every colorway. Small sizes stay in the ZIP and the manifest.
  static List<BrandVariant> get curated => [
    for (final id in const [
      'puls3-logo-dark',
      'puls3-logo-light',
      'puls3-logo-mono-white',
      'puls3-logo-mono-ink',
      'puls3-mark-c01-dark',
      'puls3-mark-c01-light',
      'puls3-mark-c01-mono-white',
      'puls3-mark-c01-mono-ink',
    ])
      variants.firstWhere((v) => v.id == id),
  ];

  static List<BrandVariant> get logos => [
    for (final v in variants)
      if (v.group == BrandGroup.logo) v,
  ];

  static List<BrandVariant> get marks => [
    for (final v in variants)
      if (v.group == BrandGroup.mark) v,
  ];

  static const darkPalette = [
    BrandSwatch(token: 'background', hex: '#0B0B0D', role: 'Page background'),
    BrandSwatch(token: 'surface', hex: '#16161A', role: 'Cards, bars, panels'),
    BrandSwatch(token: 'text', hex: '#F6F7F8', role: 'Primary text, wordmark'),
    BrandSwatch(token: 'muted', hex: '#A3A3AD', role: 'Secondary text'),
    BrandSwatch(
      token: 'accent',
      hex: '#FFB547',
      role: 'Pulse core, the 3, key actions',
    ),
    BrandSwatch(
      token: 'lavender',
      hex: '#A99CF2',
      role: 'Pulse edge, secondary accents',
    ),
    BrandSwatch(token: 'success', hex: '#2BD4A0', role: 'Positive states'),
    BrandSwatch(
      token: 'hairline',
      hex: '#2A2A31',
      role: 'Dividers and borders (decorative)',
    ),
  ];

  /// The four colors shown large on the page.
  static List<BrandSwatch> get primaryPalette => [
    for (final token in const ['background', 'text', 'accent', 'lavender'])
      darkPalette.firstWhere((s) => s.token == token),
  ];

  static const lightPalette = [
    BrandSwatch(token: 'paper', hex: '#F6F7F8', role: 'Light background'),
    BrandSwatch(token: 'white', hex: '#FFFFFF', role: 'Cards on light'),
    BrandSwatch(token: 'ink', hex: '#0B0B0D', role: 'Primary text, wordmark'),
    BrandSwatch(
      token: 'mutedOnLight',
      hex: '#5E5E6A',
      role: 'Secondary text on light',
    ),
    BrandSwatch(
      token: 'accentOnLight',
      hex: '#A05F00',
      role: 'Solid 3, pulse core, actions on light',
    ),
    BrandSwatch(
      token: 'lavenderOnLight',
      hex: '#6352CC',
      role: 'Pulse edge, secondary accents on light',
    ),
    BrandSwatch(
      token: 'hairlineLight',
      hex: '#D9DAE0',
      role: 'Dividers and borders on light (decorative)',
    ),
  ];
}

/// The web URL of a kit file. Relative, so it resolves against the app's
/// base href wherever the app is hosted.
Uri brandFileUrl(String path) {
  final clean = path.startsWith('/') ? path.substring(1) : path;
  return Uri.parse('brand/$clean');
}

/// The Flutter asset key of a kit file bundled from `web/brand/` (the SVG
/// folders are listed under `assets` in pubspec.yaml).
String brandAssetKey(String path) {
  final clean = path.startsWith('/') ? path.substring(1) : path;
  return 'web/brand/$clean';
}

/// Opens a kit file in a new tab (the browser downloads or previews it).
Future<void> openBrandFile(String path) async {
  await launchUrl(brandFileUrl(path), webOnlyWindowName: '_blank');
}
