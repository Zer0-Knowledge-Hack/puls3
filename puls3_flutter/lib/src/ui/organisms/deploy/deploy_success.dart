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
