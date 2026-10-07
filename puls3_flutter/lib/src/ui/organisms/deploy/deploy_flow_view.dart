import 'package:flutter/material.dart';

import '../../../deploy/deploy_flow_controller.dart';
import '../../../domain/stellar_format.dart';
import '../../../theme/puls3_theme.dart';
import '../../molecules/copyable_value_row.dart';
import 'deploy_copy.dart';
import 'deploy_error_panel.dart';
import 'deploy_phase_card.dart';
import 'deploy_stepper.dart';
import 'deploy_success.dart';

/// The whole deploy screen for one state: a header, then either the
/// current step (or its error), the step list and the values received so
/// far, or the success. Presentational: [DeployFlow] supplies the state.
class DeployFlowView extends StatelessWidget {
  const DeployFlowView({
    super.key,
    required this.agentName,
    required this.step,
    required this.busy,
    required this.onRetry,
    this.isDemo = false,
    required this.onClose,
    required this.onOpenAgent,
    required this.onViewTransaction,
    this.error,
    this.agentId,
    this.transactionHash,
    this.result,
  });

  final String agentName;
  final DeployStep step;

  /// A step is in flight: closing is disabled.
  final bool busy;

  /// The gateway is a stand-in: say so, and never show made-up values as
  /// on-chain facts.
  final bool isDemo;
  final DeployError? error;

  /// Known once the registration is confirmed; skeletons until then.
  final int? agentId;
  final String? transactionHash;
  final DeployResult? result;

  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback onOpenAgent;
  final VoidCallback onViewTransaction;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final error = this.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(agentName: agentName, onClose: busy ? null : onClose),
        if (isDemo) ...[
          const SizedBox(height: Puls3Spacing.sm),
          const _DemoBanner(),
        ],
        const SizedBox(height: Puls3Spacing.md),
        AnimatedSwitcher(
          duration: Puls3Durations.medium,
          child: result != null
              ? DeploySuccess(
                  result: result,
                  onOpenAgent: onOpenAgent,
                  onViewTransaction: onViewTransaction,
                  onDone: onClose,
                )
              : Column(
                  key: const ValueKey('deploy-progress'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSwitcher(
                      duration: Puls3Durations.fast,
                      child: error != null
                          ? DeployErrorPanel(
                              key: ValueKey(error),
                              error: error,
                              onRetry: onRetry,
                              onCancel: onClose,
                            )
                          : DeployPhaseCard(
                              key: ValueKey(step),
                              step: step,
                            ),
                    ),
                    const SizedBox(height: Puls3Spacing.md),
                    DeployStepper(current: step, failed: error != null),
                    if (!isDemo) ...[
                      const Divider(height: Puls3Spacing.lg),
                      _ReceivedValues(
                        agentId: agentId,
                        transactionHash: transactionHash,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.agentName, required this.onClose});

  final String agentName;

  /// Null while a step runs, which hides the close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Deploy agent', style: DeployText.title),
              ),
              Text(
                agentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DeployText.bodyMuted,
              ),
            ],
          ),
        ),
        // Same footprint with or without the button: no layout jump.
        SizedBox.square(
          dimension: 48,
          child: onClose == null
              ? null
              : IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ],
    );
  }
}

/// The agent id and transaction as soon as the chain confirms them, with
/// skeletons of the same size before that.
class _ReceivedValues extends StatelessWidget {
  const _ReceivedValues({this.agentId, this.transactionHash});

  final int? agentId;
  final String? transactionHash;

  @override
  Widget build(BuildContext context) {
    final hash = transactionHash;
    return Column(
      children: [
        CopyableValueRow(
          label: 'Agent ID',
          value: agentId?.toString(),
          display: agentId == null ? null : '#$agentId',
          copyLabel: 'Copy agent ID',
        ),
        CopyableValueRow(
          label: 'Transaction',
          value: hash,
          display: hash == null ? null : shortenAddress(hash, head: 8, tail: 8),
          copyLabel: 'Copy transaction',
        ),
      ],
    );
  }
}

/// Says plainly that nothing in this flow reaches Stellar.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('deploy-demo-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: Puls3Spacing.sm,
        vertical: Puls3Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: Puls3Colors.accent.withValues(alpha: 0.10),
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.accent),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: Puls3Colors.accent,
          ),
          const SizedBox(width: Puls3Spacing.xs),
          Expanded(
            child: Text(
              'Demo: nothing is registered on Stellar until the deploy '
              'endpoint (#18) is live.',
              style: DeployText.caption.copyWith(color: Puls3Colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
