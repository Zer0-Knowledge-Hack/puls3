import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../brand/brand_kit.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/copy_to_clipboard.dart';
import '../ui/atoms/puls3_logo.dart';
import '../ui/atoms/pulse_background.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/brand_section.dart';
import '../ui/molecules/built_on_stellar.dart';
import '../ui/organisms/brand_colors_section.dart';
import '../ui/organisms/brand_guidelines_section.dart';
import '../ui/organisms/brand_hero.dart';
import '../ui/organisms/brand_logos_section.dart';
import '../ui/organisms/brand_policy_section.dart';
import '../ui/organisms/brand_usage_section.dart';
import '../ui/organisms/site_footer.dart';

/// `/brand`: the public brand guidelines, with the curated logo files as
/// SVG and PNG, the palette, typography, size and usage rules, and a ZIP of
/// the whole kit. Content follows docs/brand/README.md.
class BrandScreen extends StatelessWidget {
  const BrandScreen({
    super.key,
    this.onOpenFile = _open,
    this.loadSvg = _loadSvg,
  });

  /// Opens a kit file by its path under `web/brand/`. Injectable for tests.
  final ValueChanged<String> onOpenFile;

  /// Reads the markup of a kit SVG by its path under `web/brand/`.
  final Future<String> Function(String path) loadSvg;

  static void _open(String path) => openBrandFile(path);

  static Future<String> _loadSvg(String path) =>
      rootBundle.loadString(brandAssetKey(path));

  Future<void> _copySvg(BuildContext context, String path) async {
    final markup = await loadSvg(path);
    if (!context.mounted) return;
    await copyToClipboard(context, markup, message: 'SVG copied');
  }

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
              focalPoint: Alignment.topCenter,
              radiusFactor: narrow ? 0.7 : 0.45,
              child: SafeArea(
                bottom: false,
                child: ContentWidth(
                  child: BrandHero(
                    narrow: narrow,
                    onHome: () => context.go('/'),
                    onOpenGuide: () => onOpenFile(BrandKit.guide),
                  ),
                ),
              ),
            ),
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: sectionGap),
                  BrandLogosSection(
                    onOpenFile: onOpenFile,
                    onCopySvg: (path) => _copySvg(context, path),
                  ),
                  SizedBox(height: sectionGap),
                  BrandColorsSection(
                    onCopy: (label, value) => copyToClipboard(
                      context,
                      value,
                      message: '$label copied',
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  const BrandSection(
                    title: 'Typography',
                    intro:
                        'Unbounded for headlines and the wordmark, Manrope '
                        'for interface and body text, JetBrains Mono for '
                        'addresses and code. Doto is an accent only: never '
                        'the logo, never body text.',
                    child: _Typography(),
                  ),
                  SizedBox(height: sectionGap),
                  const BrandGuidelinesSection(),
                  SizedBox(height: sectionGap),
                  const BrandUsageSection(),
                  SizedBox(height: sectionGap),
                  const BrandSection(
                    title: 'Co-branding',
                    intro:
                        'puls3 comes first. Separate the two logos with a '
                        '1.5 px hairline centered in a gap of 0.3 M on each '
                        'side, and set the Stellar logo at 0.5 M under a '
                        'small "Built on" label.',
                    child: _CoBranding(),
                  ),
                  SizedBox(height: sectionGap),
                  const BrandPolicySection(),
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
    return BrandGrid(
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
