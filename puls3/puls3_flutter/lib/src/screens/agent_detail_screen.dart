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
        return SingleChildScrollView(
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

    final profile = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AgentAvatar(name: agent.name, size: 72),
            const SizedBox(width: Puls3Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agent.name, style: Puls3Text.displayLg),
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
        Text(agent.description, style: Puls3Text.lead),
        const SizedBox(height: Puls3Spacing.xl),
        const SectionLabel('Skills'),
        const SizedBox(height: Puls3Spacing.sm),
        Wrap(
          spacing: Puls3Spacing.xs,
          runSpacing: Puls3Spacing.xs,
          children: [for (final s in agent.skills) SkillChip(label: s)],
        ),
      ],
    );

    final hireCard = Container(
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.lgAll,
        border: Border.all(color: Puls3Colors.border),
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
        const SizedBox(height: Puls3Spacing.lg),
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Marketplace'),
          style: TextButton.styleFrom(foregroundColor: Puls3Colors.textMuted),
        ),
        const SizedBox(height: Puls3Spacing.lg),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: profile),
              const SizedBox(width: Puls3Spacing.xxl),
              Expanded(flex: 2, child: hireCard),
            ],
          )
        else ...[
          profile,
          const SizedBox(height: Puls3Spacing.xl),
          hireCard,
        ],
        const SizedBox(height: Puls3Spacing.xxl),
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
          Text('Agent not found', style: Puls3Text.displayMd),
          const SizedBox(height: Puls3Spacing.lg),
          PrimaryButton(label: 'Back to Marketplace', onPressed: onBack),
        ],
      ),
    );
  }
}
