import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';

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

/// The wallet of the user's agent that pays a hire (#312), with copy and
/// the testnet faucet. Presentational.
class AgentWalletCard extends StatelessWidget {
  const AgentWalletCard({
    super.key,
    required this.wallet,
    required this.onCopyWallet,
    required this.onOpenFaucet,
  });

  /// The paying agent's wallet, when known.
  final String? wallet;
  final VoidCallback onCopyWallet;
  final VoidCallback onOpenFaucet;

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
  });

  final int hireId;
  final List<AgentHireStepView> steps;
  final ValueChanged<String> onOpenTransaction;
  final String? result;

  /// Why the hire stopped, when it did.
  final String? stopped;

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
      ],
    );
  }
}
