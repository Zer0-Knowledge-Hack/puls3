import 'package:flutter/material.dart';

import '../../domain/stellar_explorer.dart';
import '../../domain/stellar_format.dart';
import '../../l10n/l10n.dart';
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
    this.inputLocked = false,
    this.resumeNote,
    this.hireId,
    this.transactionHash,
    this.paymentConfirmed = false,
    this.onOpenExplorer,
    this.onViewHire,
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

  /// The task is fixed (the hire was started): shown, not editable.
  final bool inputLocked;

  /// Shown above the summary when an unfinished hire is resumed.
  final String? resumeNote;

  /// The created hire, once confirmed.
  final int? hireId;

  /// The `fund` transaction, once relayed (not for a demo).
  final String? transactionHash;

  /// The chain confirmed the payment and the server verified it. Until
  /// then the payment is only sent, and the view says so.
  final bool paymentConfirmed;

  /// Opens [transactionHash] on StellarExpert.
  final VoidCallback? onOpenExplorer;

  /// Opens the hire detail (S06), where the agent's progress shows.
  final VoidCallback? onViewHire;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Puls3Durations.medium,
      child: switch (phase) {
        HirePhase.confirmed =>
          isDemo ? _buildDemoDone(context) : _buildConfirmed(context),
        HirePhase.error => _buildError(context),
        _ => _buildSummary(context),
      },
    );
  }

  Widget _buildSummary(BuildContext context) {
    final l10n = context.l10n;
    final signing = phase == HirePhase.signing;
    final input = inputController;
    final progress = progressLabel;
    return Column(
      key: const ValueKey('summary'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.hireAgent(agentName), style: Puls3Text.h3),
        const SizedBox(height: Puls3Spacing.xs),
        if (isDemo)
          Text(
            l10n.hireDemoOnly,
            style: Puls3Text.bodyMuted,
          ),
        if (resumeNote != null) ...[
          const SizedBox(height: Puls3Spacing.sm),
          Container(
            key: const ValueKey('hire-resume-note'),
            padding: const EdgeInsets.all(Puls3Spacing.sm),
            decoration: BoxDecoration(
              color: Puls3Colors.surface,
              borderRadius: Puls3Radius.mdAll,
              border: Border.all(color: Puls3Colors.accent),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: Puls3Colors.accent,
                ),
                const SizedBox(width: Puls3Spacing.sm),
                Expanded(
                  child: Text(
                    resumeNote!,
                    style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Puls3Spacing.sm),
        const _EscrowGuarantee(),
        const SizedBox(height: Puls3Spacing.md),
        if (input != null) ...[
          TextField(
            key: const ValueKey('hire-input'),
            controller: input,
            enabled: !signing,
            readOnly: inputLocked,
            minLines: 2,
            maxLines: 4,
            style: Puls3Text.body,
            decoration: InputDecoration(
              labelText: l10n.hireTaskLabel,
              hintText: l10n.hireTaskHint,
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
                label: l10n.agentPrice,
                value: '',
                valueWidget: PriceTag(
                  stroops: priceUsdcStroops,
                  perTask: false,
                ),
              ),
              KeyValueRow(label: l10n.hireAsset, value: 'USDC'),
              KeyValueRow(label: l10n.hireNetwork, value: 'Stellar Testnet'),
              KeyValueRow(
                label: l10n.hireDestination,
                value: '',
                valueWidget: AddressBadge(address: destinationAddress),
              ),
              KeyValueRow(
                label: l10n.hireEscrow,
                value: '',
                valueWidget: AddressBadge(
                  icon: Icons.shield_outlined,
                  address:
                      escrowContractAddress ?? defaultEscrowContractAddress,
                ),
              ),
              KeyValueRow(
                label: l10n.hireNetworkFee,
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
              label: signing ? l10n.hireSigning : l10n.hireConfirmSign,
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

  /// Demo result: never claims a payment, never links to the explorer or
  /// to a hire.
  Widget _buildDemoDone(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const ValueKey('confirmed-demo'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, color: Puls3Colors.accent, size: 28),
            const SizedBox(width: Puls3Spacing.sm),
            Text(l10n.hireDemoSignature, style: Puls3Text.h3),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          l10n.hireDemoDone,
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.md),
        KeyValueRow(label: l10n.hireAgentLabel, value: agentName),
        const SizedBox(height: Puls3Spacing.lg),
        PrimaryButton(
          label: l10n.agentBackToMarketplace,
          icon: Icons.storefront_outlined,
          expand: true,
          onPressed: onBackToMarketplace,
        ),
      ],
    );
  }

  Widget _buildConfirmed(BuildContext context) {
    final l10n = context.l10n;
    final hash = transactionHash;
    final hireId = this.hireId;
    return Column(
      key: const ValueKey('confirmed'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              paymentConfirmed
                  ? Icons.verified_user_outlined
                  : Icons.hourglass_top_rounded,
              color: paymentConfirmed
                  ? Puls3Colors.success
                  : Puls3Colors.accent,
              size: 28,
            ),
            const SizedBox(width: Puls3Spacing.sm),
            Expanded(
              child: Text(
                paymentConfirmed
                    ? l10n.hirePaymentHeld
                    : l10n.hirePaymentConfirming,
                style: Puls3Text.h3,
              ),
            ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          paymentConfirmed
              ? l10n.hirePaymentHeldBody
              : l10n.hirePaymentConfirmingBody,
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.md),
        KeyValueRow(label: l10n.hireAgentLabel, value: agentName),
        if (hireId != null)
          KeyValueRow(label: l10n.hireIdLabel, value: '#$hireId'),
        if (hash != null && hash.isNotEmpty)
          KeyValueRow(
            label: l10n.hireTxHash,
            value: shortenAddress(hash, head: 8, tail: 8),
            mono: true,
          ),
        const SizedBox(height: Puls3Spacing.md),
        if (onViewHire != null) ...[
          PrimaryButton(
            label: l10n.hireViewHire,
            icon: Icons.track_changes_rounded,
            expand: true,
            onPressed: onViewHire,
          ),
          const SizedBox(height: Puls3Spacing.sm),
        ],
        if (hash != null && hash.isNotEmpty && onOpenExplorer != null) ...[
          PrimaryButton(
            label: l10n.hireViewExplorer,
            icon: Icons.open_in_new_rounded,
            variant: PrimaryButtonVariant.outline,
            expand: true,
            onPressed: onOpenExplorer,
          ),
          const SizedBox(height: Puls3Spacing.sm),
        ],
        PrimaryButton(
          label: l10n.agentBackToMarketplace,
          icon: Icons.storefront_outlined,
          variant: onViewHire == null
              ? PrimaryButtonVariant.filled
              : PrimaryButtonVariant.outline,
          expand: true,
          onPressed: onBackToMarketplace,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final l10n = context.l10n;
    final message = errorMessage ?? l10n.hirePaymentIncomplete;
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
            Text(l10n.hirePaymentFailed, style: Puls3Text.h3),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(message, style: Puls3Text.bodyMuted),
        const SizedBox(height: Puls3Spacing.xl),
        PrimaryButton(
          label: l10n.commonTryAgain,
          icon: Icons.refresh,
          expand: true,
          onPressed: onRetry ?? onConfirm,
        ),
        const SizedBox(height: Puls3Spacing.sm),
        TextButton(
          onPressed: onBackToMarketplace,
          child: Text(l10n.agentBackToMarketplace),
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
              context.l10n.hireEscrowProtection,
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
