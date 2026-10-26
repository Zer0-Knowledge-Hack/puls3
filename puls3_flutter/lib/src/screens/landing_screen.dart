import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/agent.dart';
import '../domain/project_links.dart';
import '../domain/stellar_explorer.dart';
import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/pulse_background.dart';
import '../ui/atoms/section_label.dart';
import '../ui/organisms/landing/how_it_works_diagram.dart';
import '../ui/organisms/landing/landing_bento.dart';
import '../ui/organisms/landing/landing_sections.dart';
import '../ui/organisms/landing/scroll_reveal.dart';
import '../ui/organisms/site_footer.dart';

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// `/`: experience first (hire), proof (Stellar), then a reason to act.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  /// Status of each product job. Copy is localized in the widgets.
  static const flow = [
    FlowStep(
      title: 'Discover and hire',
      body:
          'One Marketplace, read from the registry. Compare skills and '
          'prices, then describe the task.',
      icon: Icons.storefront_outlined,
      status: FlowStepStatus.live,
    ),
    FlowStep(
      title: 'Pay into escrow',
      body:
          'Your wallet funds the job in USDC. The contract holds the '
          'payment until the work is done.',
      icon: Icons.shield_outlined,
      status: FlowStepStatus.live,
    ),
    FlowStep(
      title: 'Create an agent',
      body:
          'Name it, set a price and describe what it does. The Studio '
          'checks the definition as you type.',
      icon: Icons.auto_awesome_outlined,
      status: FlowStepStatus.inDevelopment,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < Puls3Breakpoints.compact;
    final catalog = AppScope.of(context).catalog;
    final l10n = context.l10n;

    void go(String path) => context.go(path);

    return SingleChildScrollView(
      child: Column(
        children: [
          PulseBackground(
            focalPoint: Alignment.centerRight,
            radiusFactor: compact ? 0.55 : 0.42,
            opacity: 0.3,
            child: Stack(
              children: [
                const Positioned.fill(child: IgnorePointer(child: _HeroScrim())),
                ContentWidth(
                  child: ListenableBuilder(
                    listenable: catalog,
                    builder: (context, _) => _Hero(
                      compact: compact,
                      featured: catalog.agents.isEmpty
                          ? null
                          : catalog.agents.first,
                    ),
                  ),
                ),
              ],
            ),
          ),
          LandingSection(
            compact: compact,
            child: Column(
              children: [
                ScrollReveal(child: _FlowStrip(compact: compact)),
                SizedBox(height: compact ? Puls3Spacing.lg : Puls3Spacing.xl),
                ScrollReveal(
                  delay: const Duration(milliseconds: 80),
                  child: _StellarStrip(compact: compact),
                ),
                const SizedBox(height: Puls3Spacing.md),
                ScrollReveal(
                  delay: const Duration(milliseconds: 120),
                  child: OnChainFacts(
                    facts: [
                      OnChainFact(
                        label: l10n.landingSeeFirstHire,
                        detail: l10n.footerTestnet,
                        value: firstHireFundTx,
                        onOpen: () => _open(stellarExpertTxUrl(firstHireFundTx)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LandingSection(
            compact: compact,
            child: LandingFinalCta(
              compact: compact,
              onExplore: () => go('/market'),
              onBuild: () => go('/studio'),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}

class _HeroScrim extends StatelessWidget {
  const _HeroScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Puls3Colors.background,
            Puls3Colors.background.withValues(alpha: 0.85),
            Puls3Colors.background.withValues(alpha: 0.55),
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.compact, required this.featured});

  final bool compact;
  final Agent? featured;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l10n.landingKicker, color: Puls3Colors.accent),
        SizedBox(height: compact ? Puls3Spacing.md : Puls3Spacing.lg),
        Semantics(
          header: true,
          child: Text(
            l10n.landingHeadline,
            style: compact
                ? Puls3Text.h1.copyWith(fontSize: 34, height: 1.08)
                : Puls3Text.display,
          ),
        ),
        SizedBox(height: compact ? Puls3Spacing.md : Puls3Spacing.lg),
        Text(
          l10n.landingLead,
          style: compact
              ? Puls3Text.body.copyWith(fontSize: 16, height: 1.5)
              : Puls3Text.lead.copyWith(
                  color: Puls3Colors.text,
                  fontSize: 20,
                  height: 1.45,
                ),
        ),
      ],
    );

    final agent = featured;
    final demo = agent == null
        ? null
        : HireDemo(
            key: const Key('landing-hire-demo'),
            agentName: agent.name,
            priceUsdcStroops: agent.priceUsdcStroops,
          );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? Puls3Spacing.xxl : Puls3Spacing.huge,
      ),
      child: compact || demo == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                if (demo != null) ...[
                  const SizedBox(height: Puls3Spacing.xl),
                  demo,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: copy),
                const SizedBox(width: Puls3Spacing.xxl),
                Expanded(flex: 4, child: demo),
              ],
            ),
    );
  }
}

class _FlowStrip extends StatelessWidget {
  const _FlowStrip({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (l10n.landingStep1Title, false),
      (l10n.landingStep2Title, false),
      (l10n.landingStep3Title, true),
    ];
    final children = [
      for (var i = 0; i < items.length; i++)
        _FlowNode(
          key: Key('flow-step-${i + 1}'),
          index: i + 1,
          title: items[i].$1,
          coming: items[i].$2,
          comingLabel: l10n.landingComing,
        ),
    ];
    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: Puls3Spacing.sm),
            children[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Divider(color: Puls3Colors.hairline),
              ),
            ),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({
    super.key,
    required this.index,
    required this.title,
    required this.coming,
    required this.comingLabel,
  });

  final int index;
  final String title;
  final bool coming;
  final String comingLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          index.toString().padLeft(2, '0'),
          style: Puls3Text.accentMd.copyWith(fontSize: 18),
        ),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Puls3Text.title,
        ),
        if (coming)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              comingLabel,
              style: Puls3Text.caption.copyWith(color: Puls3Colors.accent),
            ),
          ),
      ],
    );
  }
}

class _StellarStrip extends StatelessWidget {
  const _StellarStrip({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      ('~5s', l10n.landingSettleTitle),
      ('¢', l10n.landingFeesTitle),
      ('USDC', l10n.landingUsdcTitle),
    ];
    Widget cell(String stat, String label) => Column(
      children: [
        Text(stat, style: Puls3Text.accentXl.copyWith(fontSize: compact ? 36 : 48)),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Puls3Text.caption.copyWith(color: Puls3Colors.text),
        ),
      ],
    );

    if (compact) {
      return Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: Puls3Spacing.sm),
            Expanded(child: cell(items[i].$1, items[i].$2)),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: Puls3Spacing.lg),
          Expanded(child: cell(items[i].$1, items[i].$2)),
        ],
      ],
    );
  }
}
