import 'package:flutter/material.dart';

import '../../domain/stellar_format.dart';
import '../../domain/usdc.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/address_badge.dart';
import '../atoms/price_tag.dart';
import '../atoms/primary_button.dart';
import '../molecules/key_value_row.dart';
import 'success_panel.dart';

enum HirePhase { review, signing, confirmed }

/// Payment summary, signing and confirmation for hiring an agent.
/// Presentational: the container owns the phase and the wallet.
class HirePaymentView extends StatelessWidget {
  const HirePaymentView({
    super.key,
    required this.phase,
    required this.agentName,
    required this.priceUsdcStroops,
    required this.destinationAddress,
    required this.onConfirm,
    required this.onBackToMarketplace,
    this.txHash,
  });

  final HirePhase phase;
  final String agentName;
  final int priceUsdcStroops;
  final String destinationAddress;
  final String? txHash;
  final VoidCallback onConfirm;
  final VoidCallback onBackToMarketplace;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Puls3Durations.medium,
      child: phase == HirePhase.confirmed ? _buildConfirmed() : _buildSummary(),
    );
  }

  Widget _buildSummary() {
    final signing = phase == HirePhase.signing;
    return Column(
      key: const ValueKey('summary'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hire $agentName', style: Puls3Text.displayMd),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          'Review the payment. It settles on Stellar in about 5 seconds.',
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.lg),
        Container(
          padding: const EdgeInsets.all(Puls3Spacing.md),
          decoration: BoxDecoration(
            color: Puls3Colors.surface2,
            borderRadius: Puls3Radius.mdAll,
            border: Border.all(color: Puls3Colors.border),
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
          onPressed: onConfirm,
        ),
      ],
    );
  }

  Widget _buildConfirmed() {
    return SuccessPanel(
      key: const ValueKey('confirmed'),
      title: 'Payment confirmed',
      subtitle: 'Paid ${formatUsdc(priceUsdcStroops)} USDC on Stellar',
      children: [
        if (txHash != null)
          KeyValueRow(
            label: 'Tx hash',
            value: shortenAddress(txHash!, head: 10, tail: 10),
            mono: true,
          ),
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
}
