import 'package:flutter/material.dart';

import '../../brand/brand_kit.dart';
import '../../theme/puls3_theme.dart';

/// A primary brand color shown large: the card is filled with the color and
/// lists its HEX, RGB and approximate CMYK values, each with a copy button.
class PrimarySwatchCard extends StatelessWidget {
  const PrimarySwatchCard({
    super.key,
    required this.swatch,
    required this.onCopy,
  });

  final BrandSwatch swatch;

  /// Copies a value; the label ("HEX", "RGB", "CMYK") names it.
  final void Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final light = swatch.color.computeLuminance() > 0.4;
    final ink = light ? Puls3Colors.background : Puls3Colors.text;
    final values = [
      ('HEX', 'HEX', swatch.hex),
      ('RGB', 'RGB', swatch.rgbValues),
      ('CMYK', 'CMYK (approx.)', swatch.cmykValues),
    ];
    return Container(
      key: ValueKey('swatch:${swatch.token}'),
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: swatch.color,
        borderRadius: Puls3Radius.lgAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(swatch.token, style: Puls3Text.h3.copyWith(color: ink)),
          const SizedBox(height: Puls3Spacing.xxs),
          Text(
            swatch.role,
            style: Puls3Text.caption.copyWith(
              color: ink.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: Puls3Spacing.xxl),
          for (final (key, label, value) in values)
            Padding(
              padding: const EdgeInsets.only(top: Puls3Spacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Puls3Text.eyebrow.copyWith(
                            color: ink.withValues(alpha: 0.7),
                          ),
                        ),
                        Text(value, style: Puls3Text.data.copyWith(color: ink)),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('copy:${swatch.token}:$key'),
                    tooltip: 'Copy $key',
                    onPressed: () => onCopy(key, value),
                    icon: Icon(Icons.copy_rounded, size: 18, color: ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
