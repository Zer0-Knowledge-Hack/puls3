import 'package:flutter/material.dart';

import '../../brand/brand_kit.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/section_label.dart';
import '../molecules/brand_section.dart';
import '../molecules/color_swatch_card.dart';
import '../molecules/primary_swatch_card.dart';

/// The four primary colors shown large with copyable values, and the full
/// dark and light palettes in a collapsible panel.
class BrandColorsSection extends StatelessWidget {
  const BrandColorsSection({super.key, required this.onCopy});

  /// Copies a value; the label ("HEX", "RGB", "CMYK") names it.
  final void Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return BrandSection(
      title: 'Colors',
      intro:
          'Dark is the default. The dark-theme amber and lavender fail on '
          'paper, so on light backgrounds always use the on-light variants '
          'from the full palette. CMYK values are converted from RGB and '
          'are approximate.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrandGrid(
            minTileWidth: 240,
            maxColumns: 4,
            children: [
              for (final s in BrandKit.primaryPalette)
                PrimarySwatchCard(swatch: s, onCopy: onCopy),
            ],
          ),
          const SizedBox(height: Puls3Spacing.lg),
          Theme(
            // No divider lines around the expansion tile.
            data: Theme.of(
              context,
            ).copyWith(dividerColor: Puls3Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: Puls3Spacing.md),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              iconColor: Puls3Colors.text,
              collapsedIconColor: Puls3Colors.muted,
              title: Text('Full palette', style: Puls3Text.title),
              children: [
                _Palette('Dark palette (default)', BrandKit.darkPalette),
                const SizedBox(height: Puls3Spacing.xl),
                _Palette('Light palette', BrandKit.lightPalette),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette(this.label, this.swatches);

  final String label;
  final List<BrandSwatch> swatches;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: Puls3Spacing.sm),
        BrandGrid(
          minTileWidth: 160,
          maxColumns: 4,
          children: [for (final s in swatches) ColorSwatchCard(swatch: s)],
        ),
      ],
    );
  }
}
