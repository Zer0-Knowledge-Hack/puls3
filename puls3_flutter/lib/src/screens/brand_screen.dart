import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../brand/brand_kit.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/puls3_logo.dart';
import '../ui/atoms/pulse_background.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/brand_asset_card.dart';
import '../ui/molecules/built_on_stellar.dart';
import '../ui/molecules/color_swatch_card.dart';
import '../ui/organisms/site_footer.dart';

/// `/brand`: the public brand guidelines, with every logo and mark file as
/// SVG and PNG, the palette, typography, size and usage rules, and a ZIP of
/// the whole kit. Content follows docs/brand/README.md.
class BrandScreen extends StatelessWidget {
  const BrandScreen({super.key, this.onOpenFile = _open});

  /// Opens a kit file by its path under `web/brand/`. Injectable for tests.
  final ValueChanged<String> onOpenFile;

  static void _open(String path) => openBrandFile(path);

  @override
  Widget build(BuildContext context) {
    final narrow =
        MediaQuery.sizeOf(context).width < Puls3Breakpoints.compactHeadline;
    final sectionGap = narrow ? Puls3Spacing.xxl : Puls3Spacing.xxxl;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            PulseBackground(
              focalPoint: Alignment.topRight,
              radiusFactor: narrow ? 0.7 : 0.45,
              child: SafeArea(
                bottom: false,
                child: ContentWidth(
                  child: _Hero(narrow: narrow, onOpenFile: onOpenFile),
                ),
              ),
            ),
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: sectionGap),
                  _Section(
                    title: 'Logo',
                    intro:
                        'The C01 Halftone Pulse mark with the "puls3" '
                        'wordmark. Use the full lockup when the mark is at '
                        'least 72 px tall; below that, use the small lockup '
                        'with the solid 3. Never retype the wordmark.',
                    child: _AssetGrid(
                      variants: BrandKit.logos,
                      onOpenFile: onOpenFile,
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _Section(
                    title: 'Mark',
                    intro:
                        'C01 full for marks of 48 px and above. Below that, '
                        'use C01-small at its 32, 24 or 16 px level. The '
                        '16 px level is the favicon.',
                    child: _AssetGrid(
                      variants: BrandKit.marks,
                      onOpenFile: onOpenFile,
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  const _Section(
                    title: 'Color',
                    intro:
                        'Dark is the default. The dark-theme amber and '
                        'lavender fail on paper, so on light backgrounds '
                        'always use the on-light variants.',
                    child: _Palettes(),
                  ),
                  SizedBox(height: sectionGap),
                  const _Section(
                    title: 'Typography',
                    intro:
                        'Unbounded for headlines and the wordmark, Manrope '
                        'for interface and body text, JetBrains Mono for '
                        'addresses and code. Doto is an accent only: never '
                        'the logo, never body text.',
                    child: _Typography(),
                  ),
                  SizedBox(height: sectionGap),
                  const _Section(
                    title: 'Size and clear space',
                    intro:
                        'c is the diameter of the C01 center dot '
                        '(0.072 × mark height).',
                    child: _Rules(
                      items: [
                        'Keep a clear space of 4c (about 0.29 × mark height) '
                            'on every side.',
                        'Digital minimums: lockup mark 24 px, mark 16 px, '
                            'wordmark 14 px tall.',
                        'Print minimums: lockup 25 mm wide, mark 6 mm, '
                            'wordmark 18 mm.',
                        'Use the halftone 3 only when the rendered 3 is at '
                            'least 40 px tall (lockup mark ≥ 72 px).',
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  const _Section(title: 'Usage', child: _Usage()),
                  SizedBox(height: sectionGap),
                  const _Section(
                    title: 'Co-branding',
                    intro:
                        'puls3 comes first. Separate the two logos with a '
                        '1.5 px hairline centered in a gap of 0.3 M on each '
                        'side, and set the Stellar logo at 0.5 M under a '
                        'small "Built on" label.',
                    child: _CoBranding(),
                  ),
                  SizedBox(height: sectionGap),
                ],
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.narrow, required this.onOpenFile});

  final bool narrow;
  final ValueChanged<String> onOpenFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Puls3Spacing.lg),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Puls3Spacing.md,
            runSpacing: Puls3Spacing.md,
            children: [
              Puls3Logo(markHeight: 48, onTap: () => context.go('/')),
              const BuiltOnStellar(compact: true),
            ],
          ),
        ),
        SizedBox(height: narrow ? Puls3Spacing.xxl : Puls3Spacing.huge),
        const SectionLabel('Brand guidelines', color: Puls3Colors.accent),
        const SizedBox(height: Puls3Spacing.md),
        Text(
          'puls3 brand kit',
          style: narrow ? Puls3Text.h1Compact : Puls3Text.display,
        ),
        const SizedBox(height: Puls3Spacing.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'Official logos, colors and type for partners, press and '
            'builders. Use the files as they are.',
            style: Puls3Text.lead,
          ),
        ),
        const SizedBox(height: Puls3Spacing.xl),
        Wrap(
          spacing: Puls3Spacing.sm,
          runSpacing: Puls3Spacing.sm,
          children: [
            PrimaryButton(
              label: 'Download all',
              icon: Icons.download_rounded,
              onPressed: () => onOpenFile(BrandKit.zip),
            ),
            PrimaryButton(
              label: 'Brand guide (PDF)',
              variant: PrimaryButtonVariant.outline,
              onPressed: () => onOpenFile(BrandKit.guide),
            ),
          ],
        ),
        SizedBox(height: narrow ? Puls3Spacing.xxl : Puls3Spacing.huge),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.intro, required this.child});

  final String title;
  final String? intro;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Puls3Text.h2Compact),
        if (intro != null) ...[
          const SizedBox(height: Puls3Spacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(intro!, style: Puls3Text.bodyMuted),
          ),
        ],
        const SizedBox(height: Puls3Spacing.lg),
        child,
      ],
    );
  }
}

/// Lays children out in 1 to [maxColumns] equal columns by width.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.children,
    this.minTileWidth = 300,
    this.maxColumns = 3,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = Puls3Spacing.md;
        final columns = ((constraints.maxWidth + gap) / (minTileWidth + gap))
            .floor()
            .clamp(1, maxColumns);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({required this.variants, required this.onOpenFile});

  final List<BrandVariant> variants;
  final ValueChanged<String> onOpenFile;

  @override
  Widget build(BuildContext context) {
    return _Grid(
      children: [
        for (final v in variants)
          BrandAssetCard(variant: v, onOpenFile: onOpenFile),
      ],
    );
  }
}

class _Palettes extends StatelessWidget {
  const _Palettes();

  @override
  Widget build(BuildContext context) {
    Widget palette(String label, List<BrandSwatch> swatches) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: Puls3Spacing.sm),
        _Grid(
          minTileWidth: 160,
          maxColumns: 4,
          children: [for (final s in swatches) ColorSwatchCard(swatch: s)],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        palette('Dark palette (default)', BrandKit.darkPalette),
        const SizedBox(height: Puls3Spacing.xl),
        palette('Light palette', BrandKit.lightPalette),
      ],
    );
  }
}

class _Typography extends StatelessWidget {
  const _Typography();

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Display', 'Unbounded 500, 700', 'Agent hub', Puls3Text.h2Compact),
      ('Accent', 'Doto 900, ROND 100', '402', Puls3Text.accentLg),
      ('UI', 'Manrope 400–800', 'Create agents.', Puls3Text.lead),
      ('Data', 'JetBrains Mono 400, 500', 'GCDSVE…QFXZ', Puls3Text.data),
    ];
    return _Grid(
      minTileWidth: 240,
      maxColumns: 4,
      children: [
        for (final (role, family, sample, style) in rows)
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(role, color: Puls3Colors.accent),
                const SizedBox(height: Puls3Spacing.sm),
                Text(sample, style: style, maxLines: 1),
                const SizedBox(height: Puls3Spacing.sm),
                Text(family, style: Puls3Text.bodyMuted),
              ],
            ),
          ),
      ],
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules({required this.items, this.icon, this.iconColor});

  final List<String> items;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Puls3Spacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon ?? Icons.circle,
                  size: icon == null ? 6 : 18,
                  color: iconColor ?? Puls3Colors.accent,
                ),
                const SizedBox(width: Puls3Spacing.sm),
                Expanded(child: Text(item, style: Puls3Text.body)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Usage extends StatelessWidget {
  const _Usage();

  @override
  Widget build(BuildContext context) {
    return const _Grid(
      minTileWidth: 340,
      maxColumns: 2,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel('Do', color: Puls3Colors.success),
              SizedBox(height: Puls3Spacing.sm),
              _Rules(
                icon: Icons.check_rounded,
                iconColor: Puls3Colors.success,
                items: [
                  'Use the official files, unaltered.',
                  'Use the on-light files on light backgrounds.',
                  'Switch to the small lockup and C01-small at small sizes.',
                  'Place the logo on calm, solid backgrounds.',
                ],
              ),
            ],
          ),
        ),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel("Don't", color: Puls3Colors.accent),
              SizedBox(height: Puls3Spacing.sm),
              _Rules(
                icon: Icons.close_rounded,
                items: [
                  'Stretch, rotate, or add shadows, glows or bevels.',
                  'Recolor the logo with Stellar yellow (#FDDA24).',
                  'Use the dark-theme amber on white or paper.',
                  'Force the halftone 3 at small sizes.',
                  'Place the logo on busy photos or patterns.',
                  'Set the logo in Doto.',
                  'Merge the mark with the Stellar monogram.',
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoBranding extends StatelessWidget {
  const _CoBranding();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Puls3Spacing.md,
            runSpacing: Puls3Spacing.sm,
            children: [Puls3Logo(markHeight: 32), BuiltOnStellar()],
          ),
          const SizedBox(height: Puls3Spacing.md),
          Text(
            'Use only the official Stellar logo from the SDF brand kit, '
            'unaltered. Never redraw or imitate it.',
            style: Puls3Text.bodyMuted,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: child,
    );
  }
}
