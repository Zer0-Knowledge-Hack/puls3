import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/puls3_logo.dart';
import '../ui/atoms/pulse_background.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/agent_mini_card.dart';
import '../ui/molecules/built_on_stellar.dart';
import '../ui/molecules/feature_point.dart';
import '../ui/organisms/site_footer.dart';

/// `/`: hero (brand guide page 14) with the large halftone-3 lockup, an
/// Unbounded headline, two CTAs and a pulse field in the corner, then the
/// "Why Stellar" block.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 700;
    final catalog = AppScope.of(context).catalog;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height * 0.9),
              child: PulseBackground(
                focalPoint: Alignment.bottomRight,
                radiusFactor: narrow ? 0.7 : 0.5,
                child: SafeArea(
                  bottom: false,
                  child: ContentWidth(
                    child: ListenableBuilder(
                      listenable: catalog,
                      builder: (context, _) => _Hero(
                        narrow: narrow,
                        featured: catalog.agents.take(2).toList(),
                        onOpenStudio: () => context.go('/studio'),
                        onExploreMarketplace: () => context.go('/market'),
                        onOpenAgent: (a) => context.go('/agent/${a.id}'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: Puls3Spacing.xxxl,
                ),
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.narrow,
    required this.featured,
    required this.onOpenStudio,
    required this.onExploreMarketplace,
    required this.onOpenAgent,
  });

  final bool narrow;
  final List<Agent> featured;
  final VoidCallback onOpenStudio;
  final VoidCallback onExploreMarketplace;
  final ValueChanged<Agent> onOpenAgent;

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
              // Mark >= 72 px, so the lockup shows the halftone 3.
              Puls3Logo(markHeight: narrow ? 72 : 80),
              const BuiltOnStellar(compact: true),
            ],
          ),
        ),
        SizedBox(height: narrow ? Puls3Spacing.xxl : Puls3Spacing.huge),
        const SectionLabel(
          'Agent Studio + Marketplace',
          color: Puls3Colors.accent,
        ),
        const SizedBox(height: Puls3Spacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            'The agent hub on Stellar.',
            style: narrow ? Puls3Text.h1Compact : Puls3Text.display,
          ),
        ),
        const SizedBox(height: Puls3Spacing.lg),
        Text(
          'Create agents. Find agents. Pay them in seconds.',
          style: Puls3Text.lead,
        ),
        const SizedBox(height: Puls3Spacing.xl),
        Wrap(
          spacing: Puls3Spacing.sm,
          runSpacing: Puls3Spacing.sm,
          children: [
            PrimaryButton(label: 'Open Studio', onPressed: onOpenStudio),
            PrimaryButton(
              label: 'Explore Marketplace',
              variant: PrimaryButtonVariant.outline,
              onPressed: onExploreMarketplace,
            ),
          ],
        ),
        if (featured.isNotEmpty) ...[
          const SizedBox(height: Puls3Spacing.xxl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Wrap(
              spacing: Puls3Spacing.sm,
              runSpacing: Puls3Spacing.sm,
              children: [
                for (final agent in featured)
                  SizedBox(
                    width: narrow ? double.infinity : 300,
                    child: AgentMiniCard(
                      name: agent.name,
                      stellarAddress: agent.stellarAddress,
                      priceUsdcStroops: agent.priceUsdcStroops,
                      onTap: () => onOpenAgent(agent),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Puls3Spacing.huge),
      ],
    );
  }
}

class _WhyStellar extends StatelessWidget {
  const _WhyStellar({required this.narrow});

  final bool narrow;

  static const _points = [
    FeaturePoint(
      stat: '~5s',
      title: '~5s settlement',
      body: 'Payments to agents finalize in seconds, not days.',
    ),
    FeaturePoint(
      stat: '<\$0.01',
      title: 'Fees of a fraction of a cent',
      body: 'Micro-payments per task stay worth it.',
    ),
    FeaturePoint(
      stat: 'USDC',
      title: 'Native USDC',
      body: 'Price and pay agents in a stable, dollar-backed asset.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Why Stellar', color: Puls3Colors.accent),
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
