import 'package:flutter/material.dart';

import '../../../deploy/deploy_flow_controller.dart';
import '../../../domain/stellar_format.dart';
import '../../../theme/puls3_theme.dart';
import '../../atoms/primary_button.dart';
import '../../molecules/copyable_value_row.dart';
import 'deploy_copy.dart';

/// The live agent: its id, the registration transaction and its wallet,
/// each copyable, then "Open agent" as the main action.
class DeploySuccess extends StatelessWidget {
  const DeploySuccess({
    super.key,
    required this.result,
    required this.onOpenAgent,
    required this.onViewTransaction,
    required this.onDone,
  });

  final DeployResult result;
  final VoidCallback onOpenAgent;
  final VoidCallback onViewTransaction;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    if (result.isDemo) return _DemoResult(onDone: onDone);
    final copy = DeployStepCopy.of[DeployStep.live]!;
    return Column(
      key: const ValueKey('deploy-success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: '${copy.headline}. ${copy.message}',
          excludeSemantics: true,
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: Puls3Durations.medium,
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Puls3Colors.success,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Puls3Colors.onAccent,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: Puls3Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.headline, style: DeployText.title),
                    Text(copy.message, style: DeployText.bodyMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Puls3Spacing.md),
        Container(
          padding: const EdgeInsets.only(
            left: Puls3Spacing.md,
            top: Puls3Spacing.xs,
            bottom: Puls3Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: Puls3Colors.surface,
            borderRadius: Puls3Radius.mdAll,
            border: Border.all(color: Puls3Colors.hairline),
          ),
          child: Column(
            children: [
              CopyableValueRow(
                label: 'Agent ID',
                value: '${result.agentId}',
                display: '#${result.agentId}',
                copyLabel: 'Copy agent ID',
              ),
              CopyableValueRow(
                label: 'Transaction',
                value: result.transactionHash,
                display: shortenAddress(
                  result.transactionHash,
                  head: 8,
                  tail: 8,
                ),
                copyLabel: 'Copy transaction',
              ),
              CopyableValueRow(
                label: 'Agent wallet',
                value: result.agentWallet,
                display: shortenAddress(result.agentWallet, head: 6, tail: 6),
                copyLabel: 'Copy agent wallet',
              ),
            ],
          ),
        ),
        const SizedBox(height: Puls3Spacing.md),
        PrimaryButton(
          label: 'Open agent',
          icon: Icons.arrow_forward_rounded,
          expand: true,
          onPressed: onOpenAgent,
        ),
        const SizedBox(height: Puls3Spacing.xxs),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              key: const Key('deploy-explorer-link'),
              onPressed: onViewTransaction,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('View transaction'),
            ),
            TextButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ],
    );
  }
}

/// The end of a demo deploy: what happened (nothing on chain) and a way
/// back. No agent page, no explorer link, no made-up hash.
class _DemoResult extends StatelessWidget {
  const _DemoResult({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('deploy-demo-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Puls3Colors.accent.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.science_outlined,
                  color: Puls3Colors.accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: Puls3Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Demo deploy only', style: DeployText.title),
                    Text(
                      'Nothing was registered on Stellar and no agent was '
                      'created.',
                      style: DeployText.bodyMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Puls3Spacing.md),
        Text(
          'Real deploys arrive with the deploy endpoint. The steps '
          'above show the flow your wallet will go through.',
          style: DeployText.caption,
        ),
        const SizedBox(height: Puls3Spacing.md),
        PrimaryButton(
          label: 'Back to Studio',
          icon: Icons.arrow_back_rounded,
          expand: true,
          onPressed: onDone,
        ),
      ],
    );
  }
}
