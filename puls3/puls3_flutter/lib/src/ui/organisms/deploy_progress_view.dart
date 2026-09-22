import 'package:flutter/material.dart';

import '../../domain/stellar_format.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/primary_button.dart';
import '../molecules/key_value_row.dart';
import '../molecules/progress_step_row.dart';
import 'success_panel.dart';

/// Staged deploy progress, then a success state. Presentational: the
/// container drives [completedSteps] and supplies the ids.
class DeployProgressView extends StatelessWidget {
  const DeployProgressView({
    super.key,
    required this.agentName,
    required this.steps,
    required this.completedSteps,
    required this.onViewInMarketplace,
    required this.onBackToStudio,
    this.contractId,
    this.txHash,
  });

  final String agentName;
  final List<String> steps;

  /// How many [steps] are finished. Equal to `steps.length` when live.
  final int completedSteps;
  final String? contractId;
  final String? txHash;
  final VoidCallback onViewInMarketplace;
  final VoidCallback onBackToStudio;

  bool get isDone => completedSteps >= steps.length;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Puls3Durations.medium,
      child: isDone ? _buildSuccess() : _buildProgress(),
    );
  }

  Widget _buildProgress() {
    return Column(
      key: const ValueKey('progress'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Deploying $agentName', style: Puls3Text.displayMd),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          'Provisioning an on-chain identity and a Stellar wallet.',
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.lg),
        for (var i = 0; i < steps.length; i++)
          ProgressStepRow(
            label: steps[i],
            status: i < completedSteps
                ? StepStatus.done
                : i == completedSteps
                ? StepStatus.active
                : StepStatus.pending,
          ),
      ],
    );
  }

  Widget _buildSuccess() {
    return SuccessPanel(
      key: const ValueKey('success'),
      title: '$agentName is live',
      subtitle: 'Your agent now has its own wallet and identity on Stellar.',
      children: [
        if (contractId != null)
          KeyValueRow(
            label: 'Agent ID',
            value: shortenAddress(contractId!, head: 8, tail: 8),
            mono: true,
          ),
        if (txHash != null)
          KeyValueRow(
            label: 'Tx hash',
            value: shortenAddress(txHash!, head: 10, tail: 10),
            mono: true,
          ),
        const SizedBox(height: Puls3Spacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Puls3Spacing.sm,
          runSpacing: Puls3Spacing.sm,
          children: [
            PrimaryButton(
              label: 'View in Marketplace',
              icon: Icons.storefront_outlined,
              onPressed: onViewInMarketplace,
            ),
            PrimaryButton(
              label: 'Back to Studio',
              variant: PrimaryButtonVariant.outline,
              onPressed: onBackToStudio,
            ),
          ],
        ),
      ],
    );
  }
}
