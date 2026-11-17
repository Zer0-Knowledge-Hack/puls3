import 'package:flutter/material.dart';

import '../../domain/agent.dart';
import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/primary_button.dart';

/// Where one step of an agent-to-agent hire is.
enum AgentHireStepState { pending, active, done }

/// One row of [AgentHireProgressView]: a step, where it is and, once it is
/// on chain, its explorer link.
class AgentHireStepView {
  const AgentHireStepView({
    required this.label,
    required this.state,
    this.transactionUrl,
  });

  final String label;
  final AgentHireStepState state;
  final String? transactionUrl;
}

/// The "Collaborate: hire another agent" form (#312). Presentational: the
/// container owns the controllers, the agents and the hire call.
class AgentHireForm extends StatelessWidget {
  const AgentHireForm({
    super.key,
    required this.wallet,
    required this.agents,
    required this.selected,
    required this.onAgentChanged,
    required this.instructionsController,
    required this.budgetController,
    required this.onCopyWallet,
    required this.onOpenFaucet,
    required this.onHire,
    this.busy = false,
    this.error,
  });

  /// The hiring agent's wallet, when known.
  final String? wallet;
  final List<Agent> agents;
  final Agent? selected;
  final ValueChanged<Agent?> onAgentChanged;
  final TextEditingController instructionsController;
  final TextEditingController budgetController;
  final VoidCallback onCopyWallet;
  final VoidCallback onOpenFaucet;

  /// Null disables Hire.
  final VoidCallback? onHire;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final address = wallet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.collabWalletLabel, style: Puls3Text.caption),
        const SizedBox(height: Puls3Spacing.xxs),
        if (address == null)
          Text(l10n.collabWalletUnknown, style: Puls3Text.bodyMuted)
        else
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  address,
                  key: const Key('collab-wallet'),
                  style: Puls3Text.data,
                ),
              ),
              IconButton(
                key: const Key('collab-copy-wallet'),
                tooltip: l10n.collabCopyWallet,
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: onCopyWallet,
              ),
            ],
          ),
        const SizedBox(height: Puls3Spacing.xs),
        Text(l10n.collabWalletHint, style: Puls3Text.bodyMuted),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('collab-faucet'),
            onPressed: onOpenFaucet,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(l10n.collabFaucet),
          ),
        ),
        const SizedBox(height: Puls3Spacing.md),
        if (agents.isEmpty)
          Text(l10n.collabNoAgents, style: Puls3Text.bodyMuted)
        else
          DropdownButtonFormField<Agent>(
            key: const Key('collab-agent'),
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.collabAgentLabel),
            items: [
              for (final agent in agents)
                DropdownMenuItem(value: agent, child: Text(agent.name)),
            ],
            onChanged: busy ? null : onAgentChanged,
          ),
        const SizedBox(height: Puls3Spacing.md),
        TextField(
          key: const Key('collab-instructions'),
          controller: instructionsController,
          enabled: !busy,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: l10n.collabInstructionsLabel,
            hintText: l10n.collabInstructionsHint,
          ),
        ),
        const SizedBox(height: Puls3Spacing.md),
        TextField(
          key: const Key('collab-budget'),
          controller: budgetController,
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.collabBudgetLabel),
        ),
        if (error case final message?) ...[
          const SizedBox(height: Puls3Spacing.sm),
          Text(
            message,
            key: const Key('collab-error'),
            style: Puls3Text.body.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Puls3Spacing.md),
        PrimaryButton(
          key: const Key('collab-hire'),
          label: busy ? l10n.collabHiring : l10n.collabHire,
          icon: Icons.handshake_outlined,
          isLoading: busy,
          expand: true,
          onPressed: busy ? null : onHire,
        ),
      ],
    );
  }
}

/// The steps of a running agent-to-agent hire, each transaction as an
/// explorer link, and the hired agent's result once delivered.
class AgentHireProgressView extends StatelessWidget {
  const AgentHireProgressView({
    super.key,
    required this.hireId,
    required this.steps,
    required this.onOpenTransaction,
    this.result,
    this.stopped,
    this.onHireAgain,
  });

  final int hireId;
  final List<AgentHireStepView> steps;
  final ValueChanged<String> onOpenTransaction;
  final String? result;

  /// Why the hire stopped, when it did.
  final String? stopped;

  /// Shown once the hire is final.
  final VoidCallback? onHireAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const Key('collab-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.collabProgressTitle(hireId), style: Puls3Text.title),
        const SizedBox(height: Puls3Spacing.sm),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: Puls3Spacing.xs),
            child: Row(
              children: [
                switch (step.state) {
                  AgentHireStepState.done => const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Puls3Colors.success,
                  ),
                  AgentHireStepState.active => const SizedBox.square(
                    dimension: 20,
                    child: Padding(
                      padding: EdgeInsets.all(3),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  AgentHireStepState.pending => const Icon(
                    Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: Puls3Colors.muted,
                  ),
                },
                const SizedBox(width: Puls3Spacing.xs),
                Expanded(
                  child: Text(
                    step.label,
                    style: step.state == AgentHireStepState.pending
                        ? Puls3Text.bodyMuted
                        : Puls3Text.body,
                  ),
                ),
                if (step.transactionUrl case final url?)
                  TextButton(
                    onPressed: () => onOpenTransaction(url),
                    child: Text(l10n.collabViewTransaction),
                  ),
              ],
            ),
          ),
        if (stopped case final message?) ...[
          const SizedBox(height: Puls3Spacing.xs),
          Text(
            message,
            key: const Key('collab-stopped'),
            style: Puls3Text.body.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (result case final text?) ...[
          const SizedBox(height: Puls3Spacing.sm),
          Text(l10n.collabResultLabel, style: Puls3Text.caption),
          const SizedBox(height: Puls3Spacing.xxs),
          SelectableText(
            text,
            key: const Key('collab-result'),
            style: Puls3Text.body,
          ),
        ],
        if (onHireAgain != null) ...[
          const SizedBox(height: Puls3Spacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: PrimaryButton(
              key: const Key('collab-hire-again'),
              label: l10n.collabHireAnother,
              variant: PrimaryButtonVariant.outline,
              onPressed: onHireAgain,
            ),
          ),
        ],
      ],
    );
  }
}
