import 'package:flutter/material.dart';

import '../../brand/brand_kit.dart';
import '../../theme/puls3_theme.dart';

/// A logo or mark variant: a preview on the background it is drawn for,
/// its label, and one download action per file (SVG plus each PNG size).
class BrandAssetCard extends StatelessWidget {
  const BrandAssetCard({
    super.key,
    required this.variant,
    required this.onOpenFile,
  });

  final BrandVariant variant;
  final ValueChanged<String> onOpenFile;

  static const _paper = Color(0xFFF6F7F8);

  @override
  Widget build(BuildContext context) {
    final onLight = variant.background == BrandBackground.light;
    final isSmallMark =
        variant.group == BrandGroup.mark && variant.png.first.width < 48;
    return Container(
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 140,
            color: onLight ? _paper : Puls3Colors.background,
            padding: const EdgeInsets.all(Puls3Spacing.lg),
            alignment: Alignment.center,
            child: Image.network(
              brandFileUrl(variant.preview.path).toString(),
              // Small marks are shown at their own pixel size.
              width: isSmallMark ? variant.png.first.width.toDouble() : null,
              fit: BoxFit.contain,
              semanticLabel: variant.label,
              errorBuilder: (context, error, stack) => Icon(
                Icons.image_outlined,
                color: onLight ? Puls3Colors.background : Puls3Colors.muted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Puls3Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(variant.label, style: Puls3Text.title),
                const SizedBox(height: Puls3Spacing.sm),
                Wrap(
                  spacing: Puls3Spacing.xs,
                  runSpacing: Puls3Spacing.xs,
                  children: [
                    _DownloadChip(
                      label: 'SVG',
                      path: variant.svg,
                      onOpenFile: onOpenFile,
                    ),
                    for (final png in variant.png)
                      _DownloadChip(
                        label: 'PNG ${png.width}',
                        path: png.path,
                        onOpenFile: onOpenFile,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadChip extends StatelessWidget {
  const _DownloadChip({
    required this.label,
    required this.path,
    required this.onOpenFile,
  });

  final String label;
  final String path;
  final ValueChanged<String> onOpenFile;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey('download:$path'),
      onPressed: () => onOpenFile(path),
      icon: const Icon(Icons.download_rounded, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Puls3Colors.text,
        side: const BorderSide(color: Puls3Colors.hairline),
        shape: const RoundedRectangleBorder(
          borderRadius: Puls3Radius.pillAll,
        ),
        textStyle: Puls3Text.caption.copyWith(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: Puls3Spacing.sm),
        minimumSize: const Size(0, 36),
      ),
    );
  }
}
