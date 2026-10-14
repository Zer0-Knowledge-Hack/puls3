import 'package:flutter/material.dart';

import '../../brand/brand_kit.dart';
import '../../theme/puls3_theme.dart';
import '../molecules/brand_asset_card.dart';
import '../molecules/brand_section.dart';

/// The curated logo grid with "Download all" in the header. Each card
/// reveals PNG, SVG and Copy SVG on hover or tap.
class BrandLogosSection extends StatelessWidget {
  const BrandLogosSection({
    super.key,
    required this.onOpenFile,
    required this.onCopySvg,
  });

  final ValueChanged<String> onOpenFile;
  final ValueChanged<String> onCopySvg;

  @override
  Widget build(BuildContext context) {
    return BrandSection(
      title: 'Logos',
      action: OutlinedButton.icon(
        onPressed: () => onOpenFile(BrandKit.zip),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Download all'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Puls3Colors.text,
          side: const BorderSide(color: Puls3Colors.muted),
          shape: const RoundedRectangleBorder(
            borderRadius: Puls3Radius.pillAll,
          ),
          textStyle: Puls3Text.button,
          minimumSize: const Size(0, 44),
        ),
      ),
      intro:
          'The C01 Halftone Pulse mark with the "puls3" wordmark. Hover or '
          'tap a logo to download it. Never retype the wordmark.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrandGrid(
            children: [
              for (final v in BrandKit.curated)
                BrandAssetCard(
                  variant: v,
                  onOpenFile: onOpenFile,
                  onCopySvg: onCopySvg,
                ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.md),
          Text(
            'Small sizes (16–32 px) are included in the full kit.',
            style: Puls3Text.bodyMuted,
          ),
        ],
      ),
    );
  }
}
