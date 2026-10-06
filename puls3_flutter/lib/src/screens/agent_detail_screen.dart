import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/address_badge.dart';
import '../ui/atoms/agent_avatar.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/price_tag.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/rating_badge.dart';
import '../ui/atoms/section_label.dart';
import '../ui/atoms/skill_chip.dart';
import '../ui/molecules/screen_header.dart';
import '../ui/organisms/reviews_section.dart';
import '../ui/organisms/site_footer.dart';
import 'hire_sheet.dart';

/// `/agent/:id`: agent profile with a Hire call to action.
class AgentDetailScreen extends StatelessWidget {
  const AgentDetailScreen({super.key, required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.of(context).catalog;
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        final agent = catalog.byId(agentId);
        if (agent == null) {
          if (catalog.isLoading || !catalog.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return _NotFound(onBack: () => context.go('/market'));
        }
        final scroll = SingleChildScrollView(
          child: Column(
            children: [
              ContentWidth(
                child: _AgentDetailBody(
                  agent: agent,
                  onBack: () => context.go('/market'),
                  onHire: () => showHireSheet(context, agent),
                ),
              ),
              const SiteFooter(),
            ],
          ),
        );
        if (!isCompactLayout(context)) return scroll;
        // Phones: price and Hire stay under the thumb.
        return Column(
          children: [
            Expanded(child: scroll),
            _HireBar(
              stroops: agent.priceUsdcStroops,
              onHire: () => showHireSheet(context, agent),
            ),
          ],
        );
      },
    );
  }
}

class _AgentDetailBody extends StatelessWidget {
  const _AgentDetailBody({
    required this.agent,
    required this.onBack,
    required this.onHire,
  });

  final Agent agent;
  final VoidCallback onBack;
  final VoidCallback onHire;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final compact = isCompactLayout(context);

    final profile = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AgentAvatar(name: agent.name, size: compact ? 56 : 72),
            const SizedBox(width: Puls3Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agent.name,
                    style: wide
                        ? Puls3Text.h2
                        : compact
                        ? Puls3Text.h3.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          )
                        : Puls3Text.h2Compact,
                  ),
                  const SizedBox(height: Puls3Spacing.xxs),
                  Wrap(
                    spacing: Puls3Spacing.sm,
                    runSpacing: Puls3Spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RatingBadge(rating: agent.rating),
                      Text(agent.model, style: Puls3Text.bodyMuted),
                      AddressBadge(address: agent.stellarAddress),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.xl),
        const SectionLabel('About'),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          agent.description,
          style: compact
              ? Puls3Text.body.copyWith(fontSize: 14, height: 1.5)
              : Puls3Text.lead,
        ),
        const SizedBox(height: Puls3Spacing.xl),
        const SectionLabel('Skills'),
        const SizedBox(height: Puls3Spacing.sm),
        Wrap(
          spacing: Puls3Spacing.xs,
          runSpacing: Puls3Spacing.xs,
          children: [for (final s in agent.skills) SkillChip(label: s)],
        ),
        SizedBox(height: compact ? Puls3Spacing.lg : Puls3Spacing.xl),
        const SectionLabel('Ratings & reviews'),
        const SizedBox(height: Puls3Spacing.sm),
        _AgentReviews(agent: agent),
      ],
    );

    final hireCard = Container(
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.lgAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Price'),
          const SizedBox(height: Puls3Spacing.sm),
          PriceTag(stroops: agent.priceUsdcStroops, large: true),
          const SizedBox(height: Puls3Spacing.xs),
          Text(
            'Paid in USDC on Stellar. Settles in about 5 seconds.',
            style: Puls3Text.bodyMuted,
          ),
          const SizedBox(height: Puls3Spacing.lg),
          PrimaryButton(
            label: 'Hire',
            icon: Icons.handshake_outlined,
            expand: true,
            onPressed: onHire,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: compact ? Puls3Spacing.xs : Puls3Spacing.lg),
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Marketplace'),
          style: TextButton.styleFrom(foregroundColor: Puls3Colors.muted),
        ),
        SizedBox(height: compact ? Puls3Spacing.sm : Puls3Spacing.lg),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: profile),
              const SizedBox(width: Puls3Spacing.xxl),
              Expanded(flex: 2, child: hireCard),
            ],
          )
        else if (compact)
          profile
        else ...[
          profile,
          const SizedBox(height: Puls3Spacing.xl),
          hireCard,
        ],
        SizedBox(height: compact ? Puls3Spacing.lg : Puls3Spacing.xxl),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Agent not found', style: Puls3Text.h3),
          const SizedBox(height: Puls3Spacing.lg),
          PrimaryButton(label: 'Back to Marketplace', onPressed: onBack),
        ],
      ),
    );
  }
}

/// Sticky bottom bar with the price and the Hire action, for phones.
class _HireBar extends StatelessWidget {
  const _HireBar({required this.stroops, required this.onHire});

  final int stroops;
  final VoidCallback onHire;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Puls3Colors.background,
        border: Border(top: BorderSide(color: Puls3Colors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Puls3Spacing.md,
          Puls3Spacing.sm,
          Puls3Spacing.md,
          Puls3Spacing.sm,
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Price per task',
                  style: Puls3Text.bodyMuted.copyWith(fontSize: 12),
                ),
                PriceTag(stroops: stroops),
              ],
            ),
            const SizedBox(width: Puls3Spacing.md),
            Expanded(
              child: PrimaryButton(
                label: 'Hire',
                icon: Icons.handshake_outlined,
                expand: true,
                onPressed: onHire,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reviews of [agent] from the review store, with rating unlocked after a
/// paid hire.
class _AgentReviews extends StatelessWidget {
  const _AgentReviews({required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final reviews = scope.reviews;
    return ListenableBuilder(
      listenable: reviews,
      builder: (context, _) => ReviewsSection(
        summary: reviews.summaryFor(agent.id),
        reviews: reviews.forAgent(agent.id),
        onRate: reviews.canRate(agent.id)
            ? () => showRateSheet(
                context,
                agentName: agent.name,
                onSubmit: (rating, comment) => reviews.add(
                  agentId: agent.id,
                  author:
                      scope.profile
                          .profileFor(scope.wallet.address)
                          ?.displayName ??
                      'You',
                  rating: rating,
                  comment: comment,
                ),
              )
            : null,
      ),
    );
  }
}
