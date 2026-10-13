import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/dashed_line.dart';
import '../atoms/primary_button.dart';
import '../atoms/puls3_logo.dart';
import '../molecules/built_on_stellar.dart';

/// The /brand hero: the mark centered inside dashed construction guides,
/// with the page title below in the accent color.
class BrandHero extends StatelessWidget {
  const BrandHero({
    super.key,
    required this.narrow,
    required this.onHome,
    required this.onOpenGuide,
  });

  final bool narrow;
  final VoidCallback onHome;
  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context) {
    final markSize = narrow ? 112.0 : 160.0;
    // The vertical guides run a bit beyond the mark.
    final overshoot = markSize * 0.35;
    return Column(
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
              Puls3Logo(markHeight: 32, onTap: onHome),
              const BuiltOnStellar(compact: true),
            ],
          ),
        ),
        SizedBox(height: narrow ? Puls3Spacing.xl : Puls3Spacing.xxxl),
        SizedBox(
          width: double.infinity,
          height: markSize + overshoot * 2,
          child: CustomPaint(
            key: const ValueKey('brand-hero-guides'),
            painter: ConstructionGuidesPainter(
              markSize: markSize,
              color: Puls3Colors.muted.withValues(alpha: 0.45),
            ),
            child: Center(child: Puls3Mark(size: markSize)),
          ),
        ),
        const SizedBox(height: Puls3Spacing.xl),
        Text(
          'Brand guidelines',
          textAlign: TextAlign.center,
          style: (narrow ? Puls3Text.h1Compact : Puls3Text.display).copyWith(
            color: Puls3Colors.accent,
          ),
        ),
        const SizedBox(height: Puls3Spacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'Official logos, colors and type for partners, press and '
            'builders. Use the files as they are.',
            textAlign: TextAlign.center,
            style: Puls3Text.lead,
          ),
        ),
        const SizedBox(height: Puls3Spacing.lg),
        PrimaryButton(
          label: 'Brand guide (PDF)',
          variant: PrimaryButtonVariant.outline,
          onPressed: onOpenGuide,
        ),
        SizedBox(height: narrow ? Puls3Spacing.xxl : Puls3Spacing.huge),
      ],
    );
  }
}
