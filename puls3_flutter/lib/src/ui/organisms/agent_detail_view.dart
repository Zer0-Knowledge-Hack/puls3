import 'package:flutter/material.dart';

import '../../domain/agent.dart';
import '../../theme/breakpoints.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/address_badge.dart';
import '../atoms/agent_avatar.dart';
import '../atoms/price_tag.dart';
import '../atoms/primary_button.dart';
import '../atoms/rating_badge.dart';
import '../atoms/section_label.dart';
import '../atoms/skeleton_box.dart';
import '../atoms/skill_chip.dart';
import '../molecules/key_value_row.dart';

/// The agent profile (S03, flow F3): about, skills, on-chain identity and
/// the Hire card. Purely presentational: the container passes the agent and
/// the callbacks.
class AgentDetailView extends StatelessWidget {
  const AgentDetailView({
    super.key,
    required this.agent,
    required this.onBack,
    required this.onHire,
    required this.onOpenExplorer,
    this.banner,
    this.hireNote,
  });

  final Agent agent;
  final VoidCallback onBack;

  /// Null disables Hire, for example while the data cannot be verified.
  final VoidCallback? onHire;

  /// Opens the Identity Registry on the explorer.
  final VoidCallback onOpenExplorer;

  /// Shown above the profile, for example a stale-data warning.
  final Widget? banner;

  /// Why Hire is disabled, shown under it.
  final String? hireNote;

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= Puls3Breakpoints.detailTwoColumn;
    final banner = this.banner;
    final hireNote = this.hireNote;
    final registryId = agent.registryId;

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
                  Text(
                    agent.name,
                    style: wide ? Puls3Text.h2 : Puls3Text.h2Compact,
                  ),
                  const SizedBox(height: Puls3Spacing.xxs),
                  Wrap(
                    spacing: Puls3Spacing.sm,
                    runSpacing: Puls3Spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RatingBadge(rating: agent.rating),
                      Text(agent.model, style: Puls3Text.bodyMuted),
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
        const SizedBox(height: Puls3Spacing.xl),
        const SectionLabel('On-chain identity'),
        const SizedBox(height: Puls3Spacing.xs),
        KeyValueRow(
          label: 'Agent id',
          value: registryId == null
              ? 'Demo agent, not on chain'
              : '#$registryId',
        ),
        KeyValueRow(
          label: 'Payment wallet',
          value: agent.stellarAddress,
          valueWidget: AddressBadge(address: agent.stellarAddress),
        ),
        const SizedBox(height: Puls3Spacing.xs),
        TextButton.icon(
          key: const ValueKey('detail-explorer'),
          onPressed: onOpenExplorer,
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('View on explorer'),
          style: TextButton.styleFrom(foregroundColor: Puls3Colors.lavender),
        ),
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
          if (hireNote != null) ...[
            const SizedBox(height: Puls3Spacing.xs),
            Text(
              hireNote,
              style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackLink(onBack: onBack),
        if (banner != null) ...[
          banner,
          const SizedBox(height: Puls3Spacing.lg),
        ],
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

/// The shape of [AgentDetailView] while the agent loads.
class AgentDetailSkeleton extends StatelessWidget {
  const AgentDetailSkeleton({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading agent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackLink(onBack: onBack),
          const Row(
            children: [
              SkeletonBox(width: 72, height: 72),
              SizedBox(width: Puls3Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 220, height: 28),
                    SizedBox(height: Puls3Spacing.xs),
                    SkeletonBox(width: 160),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.xl),
          const SkeletonBox(width: double.infinity),
          const SizedBox(height: Puls3Spacing.xs),
          const SkeletonBox(width: double.infinity),
          const SizedBox(height: Puls3Spacing.xs),
          const SkeletonBox(width: 240),
          const SizedBox(height: Puls3Spacing.xl),
          const SkeletonBox(width: double.infinity, height: 160),
          const SizedBox(height: Puls3Spacing.xxl),
        ],
      ),
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.lg),
      child: TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Marketplace'),
        style: TextButton.styleFrom(foregroundColor: Puls3Colors.muted),
      ),
    );
  }
}
