import 'package:flutter/material.dart';

import '../../domain/stellar_explorer.dart';
import '../../domain/stellar_format.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/address_badge.dart';
import '../atoms/price_tag.dart';
import '../atoms/primary_button.dart';
import '../molecules/key_value_row.dart';

enum HirePhase { review, signing, confirmed, error }

/// Payment summary, signing, error recovery and confirmation for hiring an
/// agent (flow F5). Presentational: the container owns the flow and the
/// wallet, and passes the phase and the callbacks.
class HirePaymentView extends StatelessWidget {
  const HirePaymentView({
    super.key,
    required this.phase,
    required this.agentName,
    required this.priceUsdcStroops,
    required this.destinationAddress,
    this.escrowContractAddress,
    required this.onConfirm,
    required this.onBackToMarketplace,
    this.errorMessage,
    this.onRetry,
    this.isDemo = true,
    this.progressLabel,
    this.inputController,
    this.hireId,
    this.transactionHash,
    this.onOpenExplorer,
  });

  final HirePhase phase;
  final String agentName;
  final int priceUsdcStroops;
  final String destinationAddress;

  /// Escrow contract shown in the summary; null shows
  /// [defaultEscrowContractAddress].
  final String? escrowContractAddress;
  final String? errorMessage;
  final VoidCallback onConfirm;
  final VoidCallback onBackToMarketplace;
  final VoidCallback? onRetry;

  /// The backend is a stand-in that moves no funds: say so everywhere.
  final bool isDemo;

  /// What the flow is doing while [phase] is signing.
  final String? progressLabel;

  /// The work request for the agent. When given, Confirm needs some text.
  final TextEditingController? inputController;

  /// The created hire, once confirmed.
  final int? hireId;

  /// The `fund` transaction, once confirmed (not for a demo).
  final String? transactionHash;

  /// Opens [transactionHash] on StellarExpert.
  final VoidCallback? onOpenExplorer;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Puls3Durations.medium,
      child: switch (phase) {
        HirePhase.confirmed => isDemo ? _buildDemoDone() : _buildConfirmed(),
        HirePhase.error => _buildError(),
        _ => _buildSummary(),
      },
    );
  }

  Widget _buildSummary() {
    final signing = phase == HirePhase.signing;
    final input = inputController;
    final progress = progressLabel;
    return Column(
      key: const ValueKey('summary'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hire $agentName', style: Puls3Text.h3),
        const SizedBox(height: Puls3Spacing.xs),
        if (isDemo)
          Text(
            'Demo only: signing here does not move funds. Escrow payments '
            'arrive once wallet sign-in is live on the server.',
            style: Puls3Text.bodyMuted,
          ),
        const SizedBox(height: Puls3Spacing.sm),
        const _EscrowGuarantee(),
        const SizedBox(height: Puls3Spacing.md),
        if (input != null) ...[
          TextField(
            key: const ValueKey('hire-input'),
            controller: input,
            enabled: !signing,
            minLines: 2,
            maxLines: 4,
            style: Puls3Text.body,
            decoration: const InputDecoration(
              labelText: 'What should the agent do?',
              hintText: 'Describe the task for this hire',
            ),
          ),
          const SizedBox(height: Puls3Spacing.md),
        ],
        Container(
          padding: const EdgeInsets.all(Puls3Spacing.md),
          decoration: BoxDecoration(
            color: Puls3Colors.background,
            borderRadius: Puls3Radius.mdAll,
            border: Border.all(color: Puls3Colors.hairline),
          ),
          child: Column(
            children: [
              KeyValueRow(
                label: 'Price',
                value: '',
                valueWidget: PriceTag(
                  stroops: priceUsdcStroops,
                  suffix: null,
                ),
              ),
              const KeyValueRow(label: 'Asset', value: 'USDC'),
              const KeyValueRow(label: 'Network', value: 'Stellar Testnet'),
              KeyValueRow(
                label: 'Destination',
                value: '',
                valueWidget: AddressBadge(address: destinationAddress),
              ),
              KeyValueRow(
                label: 'Escrow',
                value: '',
                valueWidget: AddressBadge(
                  icon: Icons.shield_outlined,
                  address:
                      escrowContractAddress ?? defaultEscrowContractAddress,
                ),
              ),
              const KeyValueRow(
                label: 'Network fee',
                value: '< 0.00001 XLM',
                mono: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: Puls3Spacing.lg),
        ListenableBuilder(
          listenable: input ?? const _Always(),
          builder: (context, _) {
            final ready = input == null || input.text.trim().isNotEmpty;
            return PrimaryButton(
              label: signing ? 'Signing…' : 'Confirm & sign',
              icon: Icons.lock_outline_rounded,
              isLoading: signing,
              expand: true,
              onPressed: signing ? () {} : (ready ? onConfirm : null),
            );
          },
        ),
        if (signing && progress != null) ...[
          const SizedBox(height: Puls3Spacing.sm),
          Text(
            progress,
            key: const ValueKey('hire-progress'),
            textAlign: TextAlign.center,
            style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
          ),
        ],
      ],
    );
  }

  /// Demo result: never claims a payment, never links to the explorer.
  Widget _buildDemoDone() {
    return Column(
      key: const ValueKey('confirmed-demo'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, color: Puls3Colors.accent, size: 28),
            const SizedBox(width: Puls3Spacing.sm),
            Text('Demo signature only', style: Puls3Text.h3),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          'No payment was sent and no hire was created. Real escrow '
          'payments arrive once wallet sign-in is live on the server.',
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.md),
        KeyValueRow(label: 'Agent', value: agentName),
        const SizedBox(height: Puls3Spacing.lg),
        PrimaryButton(
          label: 'Back to Marketplace',
          icon: Icons.storefront_outlined,
          expand: true,
          onPressed: onBackToMarketplace,
        ),
      ],
    );
  }

  Widget _buildConfirmed() {
    final hash = transactionHash;
    final hireId = this.hireId;
    return Column(
      key: const ValueKey('confirmed'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.verified_user_outlined,
              color: Puls3Colors.success,
              size: 28,
            ),
            const SizedBox(width: Puls3Spacing.sm),
            Expanded(
              child: Text('Payment sent to the escrow', style: Puls3Text.h3),
            ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          'Your USDC is held by the escrow contract until you approve the '
          "result. puls3 confirms the payment on Stellar and starts the agent.",
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.md),
        KeyValueRow(label: 'Agent', value: agentName),
        if (hireId != null) KeyValueRow(label: 'Hire', value: '#$hireId'),
        if (hash != null && hash.isNotEmpty)
          KeyValueRow(
            label: 'Tx hash',
            value: shortenAddress(hash, head: 8, tail: 8),
            mono: true,
          ),
        const SizedBox(height: Puls3Spacing.md),
        if (hash != null && hash.isNotEmpty && onOpenExplorer != null) ...[
          PrimaryButton(
            label: 'View on StellarExpert',
            icon: Icons.open_in_new_rounded,
            variant: PrimaryButtonVariant.outline,
            expand: true,
            onPressed: onOpenExplorer,
          ),
          const SizedBox(height: Puls3Spacing.sm),
        ],
        PrimaryButton(
          label: 'Back to Marketplace',
          icon: Icons.storefront_outlined,
          expand: true,
          onPressed: onBackToMarketplace,
        ),
      ],
    );
  }

  Widget _buildError() {
    final message = errorMessage ?? 'Payment could not be completed';
    return Column(
      key: const ValueKey('error'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Puls3Colors.accent,
              size: 28,
            ),
            const SizedBox(width: Puls3Spacing.sm),
            Text('Payment failed', style: Puls3Text.h3),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(message, style: Puls3Text.bodyMuted),
        const SizedBox(height: Puls3Spacing.xl),
        PrimaryButton(
          label: 'Try again',
          icon: Icons.refresh,
          expand: true,
          onPressed: onRetry ?? onConfirm,
        ),
        const SizedBox(height: Puls3Spacing.sm),
        TextButton(
          onPressed: onBackToMarketplace,
          child: const Text('Back to Marketplace'),
        ),
      ],
    );
  }
}

/// The custody guarantee of the escrow (ADR-0005).
class _EscrowGuarantee extends StatelessWidget {
  const _EscrowGuarantee();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('escrow-guarantee'),
      padding: const EdgeInsets.all(Puls3Spacing.sm),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 20,
            color: Puls3Colors.success,
          ),
          const SizedBox(width: Puls3Spacing.sm),
          Expanded(
            child: Text(
              'Escrow protection: your USDC stays in the escrow contract. '
              'The agent is paid only when you approve the result, and you '
              'get a refund if it never delivers.',
              style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// A listenable that never changes, for a button without an input.
class _Always implements Listenable {
  const _Always();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
