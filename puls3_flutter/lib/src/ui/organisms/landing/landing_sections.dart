import 'package:flutter/material.dart';

import '../../../domain/stellar_format.dart';
import '../../../theme/puls3_theme.dart';
import '../../atoms/content_width.dart';
import '../../atoms/primary_button.dart';
import '../../atoms/puls3_logo.dart';
import '../../atoms/section_label.dart';
import '../../molecules/built_on_stellar.dart';

/// The landing page sections. Purely presentational: the screen passes the
/// data and the navigation callbacks.

/// A link of the landing navigation or footer.
class LandingLink {
  const LandingLink({
    required this.label,
    required this.onTap,
    this.external = false,
  });

  final String label;
  final VoidCallback onTap;

  /// Opens outside the app (GitHub, docs): shown with an arrow.
  final bool external;
}

/// Top navigation of the landing: logo, links and "Open app". On phones the
/// links move into a menu.
class LandingNav extends StatelessWidget {
  const LandingNav({
    super.key,
    required this.links,
    required this.onOpenApp,
    required this.compact,
  });

  final List<LandingLink> links;
  final VoidCallback onOpenApp;
  final bool compact;

  /// Below this width the links move into a menu.
  static const double menuBelow = 1000;

  /// Below this width "Open app" leaves the bar (the menu has it).
  static const double openAppFrom = 400;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final menu = width < menuBelow;
    return Row(
      children: [
        Puls3Logo(markHeight: compact ? 28 : 32),
        const Spacer(),
        if (menu)
          PopupMenuButton<int>(
            key: const Key('landing-menu'),
            tooltip: 'Menu',
            icon: const Icon(Icons.menu_rounded),
            onSelected: (i) => links[i].onTap(),
            itemBuilder: (context) => [
              for (var i = 0; i < links.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Row(
                    children: [
                      Text(links[i].label),
                      if (links[i].external) ...[
                        const SizedBox(width: Puls3Spacing.xxs),
                        const Icon(Icons.north_east_rounded, size: 14),
                      ],
                    ],
                  ),
                ),
            ],
          )
        else
          for (final link in links)
            TextButton(
              onPressed: link.onTap,
              style: TextButton.styleFrom(foregroundColor: Puls3Colors.text),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(link.label),
                  if (link.external) ...[
                    const SizedBox(width: 2),
                    const Icon(Icons.north_east_rounded, size: 14),
                  ],
                ],
              ),
            ),
        if (width >= openAppFrom) ...[
          const SizedBox(width: Puls3Spacing.xs),
          PrimaryButton(
            key: const Key('landing-open-app'),
            label: 'Open app',
            onPressed: onOpenApp,
          ),
        ],
      ],
    );
  }
}

/// Eyebrow, title and one-line lead of a section.
class LandingSectionHeading extends StatelessWidget {
  const LandingSectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.lead,
    required this.compact,
  });

  final String eyebrow;
  final String title;
  final String? lead;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lead = this.lead;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(eyebrow, color: Puls3Colors.accent),
        const SizedBox(height: Puls3Spacing.xs),
        Semantics(
          header: true,
          child: Text(
            title,
            style: compact
                ? Puls3Text.h3.copyWith(fontSize: 20, height: 1.25)
                : Puls3Text.h2Compact,
          ),
        ),
        if (lead != null) ...[
          const SizedBox(height: Puls3Spacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              lead,
              style: compact
                  ? Puls3Text.bodyMuted.copyWith(fontSize: 14, height: 1.5)
                  : Puls3Text.lead,
            ),
          ),
        ],
      ],
    );
  }
}

/// A section with consistent width and vertical rhythm.
class LandingSection extends StatelessWidget {
  const LandingSection({
    super.key,
    required this.child,
    required this.compact,
    this.divider = true,
  });

  final Widget child;
  final bool compact;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? const Border(top: BorderSide(color: Puls3Colors.hairline))
            : null,
      ),
      child: ContentWidth(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? Puls3Spacing.xxl : Puls3Spacing.xxxl,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A verifiable on-chain fact: a label, a shortened id and an explorer
/// link.
class OnChainFact {
  const OnChainFact({
    required this.label,
    required this.detail,
    required this.value,
    required this.onOpen,
  });

  final String label;
  final String detail;

  /// The contract address or transaction hash.
  final String value;
  final VoidCallback onOpen;
}

/// [OnChainFact]s as rows that open StellarExpert.
class OnChainFacts extends StatelessWidget {
  const OnChainFacts({super.key, required this.facts});

  final List<OnChainFact> facts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Puls3Colors.hairline),
            Material(
              color: Puls3Colors.transparent,
              child: InkWell(
                onTap: facts[i].onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(Puls3Spacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(facts[i].label, style: Puls3Text.body),
                            const SizedBox(height: 2),
                            Text(
                              facts[i].detail,
                              style: Puls3Text.caption.copyWith(
                                color: Puls3Colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Puls3Spacing.sm),
                      Text(
                        shortenAddress(facts[i].value, head: 6, tail: 6),
                        style: Puls3Text.data.copyWith(fontSize: 13),
                      ),
                      const SizedBox(width: Puls3Spacing.xxs),
                      Tooltip(
                        message: 'Open on StellarExpert',
                        child: const Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Puls3Colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The closing call to action.
class LandingFinalCta extends StatelessWidget {
  const LandingFinalCta({
    super.key,
    required this.onExplore,
    required this.onBuild,
    required this.onContribute,
    required this.compact,
  });

  final VoidCallback onExplore;
  final VoidCallback onBuild;
  final VoidCallback onContribute;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? Puls3Spacing.lg : Puls3Spacing.xxl),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.lgAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start with an agent.',
            style: compact
                ? Puls3Text.h3.copyWith(fontSize: 22)
                : Puls3Text.h2Compact,
          ),
          const SizedBox(height: Puls3Spacing.xs),
          Text(
            'Hire one on testnet, build your own in the Studio, or help '
            'build puls3 in the open.',
            style: Puls3Text.bodyMuted,
          ),
          const SizedBox(height: Puls3Spacing.lg),
          Wrap(
            spacing: Puls3Spacing.sm,
            runSpacing: Puls3Spacing.sm,
            children: [
              PrimaryButton(label: 'Explore agents', onPressed: onExplore),
              PrimaryButton(
                label: 'Build an agent',
                variant: PrimaryButtonVariant.outline,
                onPressed: onBuild,
              ),
              TextButton.icon(
                key: const Key('landing-contribute'),
                onPressed: onContribute,
                icon: const Icon(Icons.north_east_rounded, size: 16),
                label: const Text('Contribute on GitHub'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The landing footer: product and project links, the network note and the
/// Stellar lockup.
class LandingFooter extends StatelessWidget {
  const LandingFooter({
    super.key,
    required this.product,
    required this.project,
  });

  final List<LandingLink> product;
  final List<LandingLink> project;

  @override
  Widget build(BuildContext context) {
    Widget column(String title, List<LandingLink> links) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        const SizedBox(height: Puls3Spacing.xs),
        for (final link in links)
          TextButton(
            onPressed: link.onTap,
            style: TextButton.styleFrom(
              foregroundColor: Puls3Colors.muted,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              alignment: Alignment.centerLeft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(link.label),
                if (link.external) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.north_east_rounded, size: 13),
                ],
              ],
            ),
          ),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Puls3Colors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xl),
      child: ContentWidth(
        child: Wrap(
          spacing: Puls3Spacing.xxl,
          runSpacing: Puls3Spacing.lg,
          children: [
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Puls3Logo(markHeight: 24),
                  const SizedBox(height: Puls3Spacing.sm),
                  Text(
                    'Runs on Stellar Testnet: test USDC only, no real money.',
                    style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
                  ),
                  const SizedBox(height: Puls3Spacing.sm),
                  const BuiltOnStellar(compact: true),
                ],
              ),
            ),
            column('Product', product),
            column('Project', project),
          ],
        ),
      ),
    );
  }
}
