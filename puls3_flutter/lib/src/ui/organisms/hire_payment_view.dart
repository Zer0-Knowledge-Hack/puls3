import 'package:flutter/material.dart';

import '../../domain/stellar_format.dart';
import '../../domain/usdc.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/price_tag.dart';
import '../atoms/primary_button.dart';
import '../molecules/copyable_value_row.dart';

enum HirePhase { review, signing, failed, confirmed }

/// Why a payment did not go through. In every case no funds moved.
enum HireFailure {
  rejected,
  insufficientFunds,
  wrongNetwork,
  walletUnavailable,
  unknown,
}

/// Payment review, wallet signature, failure with retry, and confirmation
/// for hiring an agent. Presentational: the container owns the phase and
/// talks to the wallet.
class HirePaymentView extends StatelessWidget {
  const HirePaymentView({
    super.key,
    required this.phase,
    required this.agentName,
    required this.priceUsdcStroops,
    required this.destinationAddress,
    required this.walletConnected,
    required this.onConfirm,
    required this.onConnectWallet,
    required this.onBackToMarketplace,
    required this.onCancel,
    this.failure,
    this.txHash,
    this.onViewTransaction,
    this.onRate,
  });

  final HirePhase phase;
  final String agentName;
  final int priceUsdcStroops;

  /// The agent's payout wallet, paid by the escrow on approval.
  final String destinationAddress;
  final bool walletConnected;
  final HireFailure? failure;
  final String? txHash;
  final VoidCallback onConfirm;
  final VoidCallback onConnectWallet;
  final VoidCallback onBackToMarketplace;
  final VoidCallback onCancel;
  final VoidCallback? onViewTransaction;
  final VoidCallback? onRate;

  /// Platform fee in basis points; 0 in the MVP (ADR-0005 D7).
  static const platformFeeBps = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Puls3Durations.medium,
      child: phase == HirePhase.confirmed
          ? _Confirmed(view: this)
          : _Review(view: this),
    );
  }
}

TextStyle get _title => Puls3Text.title.copyWith(fontSize: 17);
TextStyle get _muted => Puls3Text.bodyMuted.copyWith(fontSize: 13, height: 1.4);

class _Review extends StatelessWidget {
  const _Review({required this.view});

  final HirePaymentView view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final signing = v.phase == HirePhase.signing;
    final fee = v.priceUsdcStroops * HirePaymentView.platformFeeBps ~/ 10000;
    return Column(
      key: const ValueKey('hire-review'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hire ${v.agentName}', style: _title),
        const SizedBox(height: 2),
        Text('Review the payment before you sign.', style: _muted),
        const SizedBox(height: Puls3Spacing.md),
        _Card(
          children: [
            _Line(
              label: 'Price per task',
              value: PriceTag(stroops: v.priceUsdcStroops, suffix: null),
            ),
            _Line(
              label: 'Platform fee (0%)',
              value: Text('${formatUsdc(fee)} USDC', style: Puls3Text.data),
            ),
            _Line(
              label: 'Network fee',
              value: Text('< 0.00001 XLM', style: Puls3Text.data),
            ),
            const Divider(height: Puls3Spacing.md),
            _Line(
              label: 'Total',
              bold: true,
              value: PriceTag(stroops: v.priceUsdcStroops + fee, suffix: null),
            ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        _Card(
          children: [
            Text(
              'Protected by escrow',
              style: Puls3Text.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Puls3Spacing.xs),
            const _Step(
              icon: Icons.lock_outline_rounded,
              text: 'Your USDC is held by the escrow contract.',
            ),
            const _Step(
              icon: Icons.smart_toy_outlined,
              text: 'The agent works and delivers the result.',
            ),
            const _Step(
              icon: Icons.verified_outlined,
              text: 'Approve to pay the agent, or reject for a full refund.',
            ),
            const SizedBox(height: Puls3Spacing.xs),
            Row(
              children: [
                Text('Agent wallet', style: _muted),
                const Spacer(),
                Text(
                  shortenAddress(v.destinationAddress),
                  style: Puls3Text.data,
                ),
              ],
            ),
          ],
        ),
        if (v.phase == HirePhase.failed && v.failure != null) ...[
          const SizedBox(height: Puls3Spacing.sm),
          _FailureBanner(failure: v.failure!),
        ],
        if (signing) ...[
          const SizedBox(height: Puls3Spacing.sm),
          const _SigningBanner(),
        ],
        const SizedBox(height: Puls3Spacing.md),
        if (!v.walletConnected)
          PrimaryButton(
            label: 'Connect wallet to pay',
            icon: Icons.account_balance_wallet_outlined,
            expand: true,
            onPressed: v.onConnectWallet,
          )
        else
          PrimaryButton(
            label: signing
                ? 'Waiting for signature…'
                : v.phase == HirePhase.failed
                ? 'Try again'
                : 'Confirm & sign',
            icon: v.phase == HirePhase.failed
                ? Icons.refresh_rounded
                : Icons.lock_outline_rounded,
            isLoading: signing,
            expand: true,
            onPressed: v.onConfirm,
          ),
        if (!signing)
          TextButton(onPressed: v.onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

class _Confirmed extends StatelessWidget {
  const _Confirmed({required this.view});

  final HirePaymentView view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final hash = v.txHash;
    return Column(
      key: const ValueKey('hire-confirmed'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Puls3Colors.success,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Puls3Colors.onAccent,
              ),
            ),
            const SizedBox(width: Puls3Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment confirmed', style: _title),
                  Text(
                    'Paid ${formatUsdc(v.priceUsdcStroops)} USDC on Stellar',
                    style: _muted,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.md),
        _Card(
          children: [
            _Line(
              label: 'Agent',
              value: Text(
                v.agentName,
                style: Puls3Text.body.copyWith(fontSize: 14),
              ),
            ),
            _Line(
              label: 'Held in escrow',
              value: PriceTag(stroops: v.priceUsdcStroops, suffix: null),
            ),
            if (hash != null)
              CopyableValueRow(
                label: 'Transaction',
                value: hash,
                display: shortenAddress(hash, head: 8, tail: 8),
                copyLabel: 'Copy transaction',
              ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          '${v.agentName} is working on your task. You will be notified when '
          'it delivers, then you approve or reject.',
          style: _muted,
        ),
        const SizedBox(height: Puls3Spacing.md),
        PrimaryButton(
          label: 'Back to Marketplace',
          icon: Icons.storefront_outlined,
          expand: true,
          onPressed: v.onBackToMarketplace,
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (v.onViewTransaction != null)
              TextButton.icon(
                onPressed: v.onViewTransaction,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('View transaction'),
              ),
            if (v.onRate != null)
              TextButton.icon(
                onPressed: v.onRate,
                icon: const Icon(Icons.star_outline_rounded, size: 18),
                label: const Text('Rate agent'),
              ),
          ],
        ),
      ],
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final HireFailure failure;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (failure) {
      HireFailure.rejected => (
        Icons.block_rounded,
        'Payment cancelled',
        'You rejected the request in your wallet. No funds moved.',
      ),
      HireFailure.insufficientFunds => (
        Icons.account_balance_wallet_outlined,
        'Not enough funds',
        'Add USDC and a little XLM for fees, then try again.',
      ),
      HireFailure.wrongNetwork => (
        Icons.swap_horiz_rounded,
        'Wrong network',
        'Switch your wallet to Stellar Testnet, then try again.',
      ),
      HireFailure.walletUnavailable => (
        Icons.link_off_rounded,
        'Wallet not available',
        'Open or unlock your wallet, then try again.',
      ),
      HireFailure.unknown => (
        Icons.error_outline_rounded,
        'Payment failed',
        'Something went wrong. No funds moved. Try again.',
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: ValueKey('hire-failure-${failure.name}'),
        padding: const EdgeInsets.all(Puls3Spacing.sm),
        decoration: BoxDecoration(
          color: Puls3Colors.accent.withValues(alpha: 0.08),
          borderRadius: Puls3Radius.mdAll,
          border: Border.all(color: Puls3Colors.accent),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Puls3Colors.accent, size: 20),
            const SizedBox(width: Puls3Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Puls3Text.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(body, style: _muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SigningBanner extends StatelessWidget {
  const _SigningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Puls3Spacing.sm),
      decoration: BoxDecoration(
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.accent),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Puls3Colors.accent,
            size: 20,
          ),
          const SizedBox(width: Puls3Spacing.sm),
          Expanded(
            child: Text(
              'Confirm the payment in your wallet.',
              style: Puls3Text.body.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Puls3Spacing.sm),
      decoration: BoxDecoration(
        color: Puls3Colors.background,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final Widget value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold
                  ? Puls3Text.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )
                  : _muted,
            ),
          ),
          value,
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Puls3Colors.lavender),
          const SizedBox(width: Puls3Spacing.xs),
          Expanded(child: Text(text, style: _muted)),
        ],
      ),
    );
  }
}
