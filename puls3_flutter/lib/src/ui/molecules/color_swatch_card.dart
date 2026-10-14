import 'package:flutter/material.dart';

import '../../brand/brand_kit.dart';
import '../../theme/puls3_theme.dart';

/// A brand color: the swatch, its token name, HEX, RGB and role.
class ColorSwatchCard extends StatelessWidget {
  const ColorSwatchCard({super.key, required this.swatch});

  final BrandSwatch swatch;

  @override
  Widget build(BuildContext context) {
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
            height: 72,
            decoration: BoxDecoration(
              color: swatch.color,
              border: const Border(
                bottom: BorderSide(color: Puls3Colors.hairline),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Puls3Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(swatch.token, style: Puls3Text.title),
                const SizedBox(height: Puls3Spacing.xxs),
                SelectableText(swatch.hex, style: Puls3Text.data),
                Text(
                  swatch.rgb,
                  style: Puls3Text.data.copyWith(color: Puls3Colors.muted),
                ),
                const SizedBox(height: Puls3Spacing.xxs),
                Text(
                  swatch.role,
                  style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
