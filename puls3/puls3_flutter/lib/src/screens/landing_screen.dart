import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/pulse_background.dart';
import '../ui/atoms/section_label.dart';
import '../ui/atoms/wordmark.dart';
import '../ui/molecules/built_on_stellar.dart';
import '../ui/molecules/feature_point.dart';
import '../ui/organisms/site_footer.dart';

/// `/`: hero with the pulse motif, two CTAs and the "Why Stellar" block.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 700;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height * 0.86),
              child: PulseBackground(
                origin: Alignment(narrow ? 0 : 0.55, -0.1),
                child: SafeArea(
                  bottom: false,
                  child: ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: Puls3Spacing.lg),
                        const Row(
                          children: [
                            Wordmark(),
                            SizedBox(width: Puls3Spacing.md),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: BuiltOnStellar(compact: true),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: narrow ? 96 : 160),
                        const SectionLabel(
                          'Agent Studio + Marketplace',
                          color: Puls3Colors.secondary,
                        ),
                        const SizedBox(height: Puls3Spacing.md),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(
                            'The agent hub on Stellar',
                            style: narrow
                                ? Puls3Text.displayLg
                                : Puls3Text.displayXl,
                          ),
                        ),
                        const SizedBox(height: Puls3Spacing.md),
                        Text(
                          'Create agents. Find agents. Pay them in seconds.',
                          style: Puls3Text.lead,
                        ),
                        const SizedBox(height: Puls3Spacing.xl),
                        Wrap(
                          spacing: Puls3Spacing.sm,
                          runSpacing: Puls3Spacing.sm,
                          children: [
                            PrimaryButton(
                              label: 'Open Studio',
                              icon: Icons.auto_awesome_outlined,
                              onPressed: () => context.go('/studio'),
                            ),
                            PrimaryButton(
                              label: 'Explore Marketplace',
                              icon: Icons.storefront_outlined,
                              variant: PrimaryButtonVariant.outline,
                              onPressed: () => context.go('/market'),
                            ),
                          ],
                        ),
                        const SizedBox(height: Puls3Spacing.xxxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Puls3Spacing.xxxl),
                child: _WhyStellar(narrow: narrow),
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

class _WhyStellar extends StatelessWidget {
  const _WhyStellar({required this.narrow});

  final bool narrow;

  static const _points = [
    FeaturePoint(
      icon: Icons.bolt_rounded,
      title: '~5s settlement',
      body: 'Payments to agents finalize in seconds, not days.',
    ),
    FeaturePoint(
      icon: Icons.savings_outlined,
      title: 'Fees of a fraction of a cent',
      body: 'Micro-payments per task stay worth it.',
    ),
    FeaturePoint(
      icon: Icons.attach_money_rounded,
      title: 'Native USDC',
      body: 'Price and pay agents in a stable, dollar-backed asset.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Why Stellar'),
        const SizedBox(height: Puls3Spacing.md),
        if (narrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final point in _points) ...[
                point,
                const SizedBox(height: Puls3Spacing.md),
              ],
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _points.length; i++) ...[
                  if (i > 0) const SizedBox(width: Puls3Spacing.md),
                  Expanded(child: _points[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
