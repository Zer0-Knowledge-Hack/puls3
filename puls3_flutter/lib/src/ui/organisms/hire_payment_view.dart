import 'package:flutter/material.dart';

import '../../domain/stellar_explorer.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/address_badge.dart';
import '../atoms/price_tag.dart';
import '../atoms/primary_button.dart';
import '../molecules/key_value_row.dart';

enum HirePhase { review, signing, confirmed, error }

/// Payment summary, signing, error recovery and confirmation for hiring an agent.
/// Presentational: the container owns the phase and the wallet.
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

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Puls3Durations.medium,
      child: switch (phase) {
        HirePhase.confirmed => _buildConfirmed(),
        HirePhase.error => _buildError(),
        _ => _buildSummary(),
      },
    );
  }

  Widget _buildSummary() {
    final signing = phase == HirePhase.signing;
    return Column(
      key: const ValueKey('summary'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hire $agentName', style: Puls3Text.h3),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          'Demo only: signing here does not move funds. Escrow payments arrive with the server relay.',
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.lg),
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
              const KeyValueRow(label: 'Network', value: 'Stellar'),
              KeyValueRow(
                label: 'Destination',
                value: '',
                valueWidget: AddressBadge(address: destinationAddress),
              ),
              KeyValueRow(
                label: 'Escrow',
                value: '',
                valueWidget: AddressBadge(
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
        PrimaryButton(
          label: signing ? 'Signing…' : 'Confirm & sign',
          icon: Icons.lock_outline_rounded,
          isLoading: signing,
          expand: true,
          onPressed: signing ? () {} : onConfirm,
        ),
      ],
    );
  }

  Widget _buildConfirmed() {
    return Column(
      key: const ValueKey('confirmed'),
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
          'No payment was sent and no hire was created. Real escrow payments arrive with the server relay.',
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

  Widget _buildError() {
    final message = errorMessage ?? 'Payment could not be completed';
    return Column(
      key: const ValueKey('error'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline, color: Puls3Colors.accent, size: 28),
            const SizedBox(width: Puls3Spacing.sm),
            Text('Payment failed', style: Puls3Text.h3),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          message,
          style: Puls3Text.bodyMuted,
        ),
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
