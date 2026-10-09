import 'package:flutter/material.dart';

import '../../domain/stellar_format.dart';
import '../../state/wallet_controller.dart';
import '../../theme/puls3_theme.dart';
import '../../wallet/wallet_port.dart';
import '../atoms/primary_button.dart';
import '../molecules/copyable_value_row.dart';

/// The wallet sheet (S09, flow F1): connect, connecting, connected (short
/// address, network, copy, disconnect) and every recoverable error.
/// Presentational: the container passes the state and the callbacks.
class WalletPanel extends StatelessWidget {
  const WalletPanel({
    super.key,
    required this.status,
    required this.walletName,
    required this.onConnect,
    required this.onDisconnect,
    this.address,
    this.isOnTestnet = true,
    this.error,
    this.onInstall,
  });

  final WalletStatus status;
  final String walletName;
  final String? address;
  final bool isOnTestnet;
  final WalletException? error;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  /// Opens the wallet's install page; null when there is none.
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final address = this.address;
    final Widget body = switch (status) {
      WalletStatus.connected ||
      WalletStatus.signed when address != null => _Connected(
        address: address,
        walletName: walletName,
        isOnTestnet: isOnTestnet,
        signed: status == WalletStatus.signed,
        onDisconnect: onDisconnect,
      ),
      WalletStatus.connecting => _Connecting(walletName: walletName),
      WalletStatus.signing => _Signing(walletName: walletName),
      WalletStatus.rejected ||
      WalletStatus.wrongNetwork ||
      WalletStatus.error => _Error(
        error: error,
        walletName: walletName,
        // Connected means the failure came from a signature, not a
        // connection.
        whileSigning: address != null,
        onRetry: onConnect,
        onInstall: onInstall,
      ),
      _ => _Disconnected(walletName: walletName, onConnect: onConnect),
    };
    return AnimatedSwitcher(duration: Puls3Durations.fast, child: body);
  }
}

TextStyle get _title => Puls3Text.title.copyWith(fontSize: 17);
TextStyle get _muted => Puls3Text.bodyMuted.copyWith(fontSize: 13, height: 1.4);

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.message,
    this.color = Puls3Colors.lavender,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Puls3Colors.surface,
              border: Border.all(color: Puls3Colors.hairline),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: Puls3Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _title),
                const SizedBox(height: 2),
                Text(message, style: _muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disconnected extends StatelessWidget {
  const _Disconnected({required this.walletName, required this.onConnect});

  final String walletName;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('wallet-state-disconnected'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Connect a wallet',
          message:
              'Your wallet signs deploys and payments. puls3 never sees '
              'your secret key.',
        ),
        const SizedBox(height: Puls3Spacing.md),
        PrimaryButton(
          label: 'Connect $walletName',
          icon: Icons.account_balance_wallet_outlined,
          expand: true,
          onPressed: onConnect,
        ),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          'Stellar Testnet only. No real funds.',
          textAlign: TextAlign.center,
          style: _muted.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting({required this.walletName});

  final String walletName;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('wallet-state-connecting'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: Icons.hourglass_top_rounded,
          title: 'Waiting for $walletName…',
          message: 'Approve the connection in the $walletName window.',
          color: Puls3Colors.accent,
        ),
        const SizedBox(height: Puls3Spacing.md),
        const _WaitingBar(),
      ],
    );
  }
}

/// Progress shown while a wallet prompt is open.
class _WaitingBar extends StatelessWidget {
  const _WaitingBar();

  @override
  Widget build(BuildContext context) {
    return const ClipRRect(
      borderRadius: Puls3Radius.pillAll,
      child: LinearProgressIndicator(
        minHeight: 3,
        color: Puls3Colors.accent,
        backgroundColor: Puls3Colors.hairline,
      ),
    );
  }
}

class _Signing extends StatelessWidget {
  const _Signing({required this.walletName});

  final String walletName;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('wallet-state-signing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: Icons.draw_outlined,
          title: 'Waiting for wallet confirmation…',
          message:
              'Review the transaction in $walletName and approve it. '
              'puls3 sends it exactly as prepared.',
          color: Puls3Colors.accent,
        ),
        const SizedBox(height: Puls3Spacing.md),
        const _WaitingBar(),
      ],
    );
  }
}

class _Connected extends StatelessWidget {
  const _Connected({
    required this.address,
    required this.walletName,
    required this.isOnTestnet,
    required this.onDisconnect,
    this.signed = false,
  });

  final String address;
  final String walletName;
  final bool isOnTestnet;
  final bool signed;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(signed ? 'wallet-state-signed' : 'wallet-state-connected'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: Icons.check_circle_rounded,
          title: signed ? 'Transaction signed' : 'Connected',
          message: signed
              ? 'Signed with $walletName. puls3 submits it for you.'
              : 'Signing with $walletName.',
          color: Puls3Colors.success,
        ),
        const SizedBox(height: Puls3Spacing.md),
        Container(
          padding: const EdgeInsets.only(
            left: Puls3Spacing.sm,
            top: Puls3Spacing.xxs,
            bottom: Puls3Spacing.xxs,
          ),
          decoration: BoxDecoration(
            color: Puls3Colors.surface,
            borderRadius: Puls3Radius.mdAll,
            border: Border.all(color: Puls3Colors.hairline),
          ),
          child: Column(
            children: [
              CopyableValueRow(
                label: 'Address',
                value: address,
                display: shortenAddress(address),
                copyLabel: 'Copy address',
              ),
              Padding(
                padding: const EdgeInsets.only(
                  right: Puls3Spacing.sm,
                  bottom: Puls3Spacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Network',
                        style: _muted.copyWith(fontSize: 12),
                      ),
                    ),
                    _NetworkBadge(onTestnet: isOnTestnet),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Puls3Spacing.md),
        PrimaryButton(
          label: 'Disconnect',
          icon: Icons.logout_rounded,
          variant: PrimaryButtonVariant.outline,
          expand: true,
          onPressed: onDisconnect,
        ),
      ],
    );
  }
}

class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge({required this.onTestnet});

  final bool onTestnet;

  @override
  Widget build(BuildContext context) {
    final color = onTestnet ? Puls3Colors.success : Puls3Colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: Puls3Radius.pillAll,
        border: Border.all(color: color),
      ),
      child: Text(
        onTestnet ? 'Testnet' : 'Wrong network',
        style: Puls3Text.caption.copyWith(fontSize: 12, color: color),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({
    required this.error,
    required this.walletName,
    required this.onRetry,
    this.whileSigning = false,
    this.onInstall,
  });

  final WalletException? error;
  final String walletName;
  final bool whileSigning;
  final VoidCallback onRetry;
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final (key, icon, title, message) = switch (error) {
      WalletSignatureRejected() when whileSigning => (
        'rejected',
        Icons.block_rounded,
        'Signature rejected',
        'You rejected the transaction in $walletName. Nothing was sent.',
      ),
      WalletSignatureRejected() => (
        'rejected',
        Icons.block_rounded,
        'Connection cancelled',
        'You declined the request in $walletName. Nothing was shared.',
      ),
      WalletWrongNetwork() => (
        'wrong-network',
        Icons.swap_horiz_rounded,
        'Wrong network',
        'Your wallet is on another network. Switch $walletName to '
            'Stellar Testnet to continue.',
      ),
      WalletAccountChanged() => (
        'account-changed',
        Icons.manage_accounts_outlined,
        'Account changed',
        'The account in $walletName changed. Connect again to continue.',
      ),
      WalletTimedOut() => (
        'timed-out',
        Icons.hourglass_disabled_rounded,
        'No answer from $walletName',
        'The $walletName window was closed or never opened. Open '
            '$walletName, then try again.',
      ),
      WalletInvalidPayload() => (
        'invalid-payload',
        Icons.gpp_bad_outlined,
        'Transaction refused',
        'puls3 refused to ask $walletName to sign this transaction. '
            'Nothing was signed.',
      ),
      WalletNotInstalled() => (
        'not-installed',
        Icons.extension_off_outlined,
        '$walletName not found',
        'Install the $walletName extension, reload this page, then '
            'connect.',
      ),
      WalletUnavailable() => (
        'unavailable',
        Icons.lock_outline_rounded,
        '$walletName is locked',
        'Unlock $walletName, then try again.',
      ),
      _ => (
        'failed',
        Icons.error_outline_rounded,
        'Wallet connection failed',
        'Something went wrong with $walletName. Try again.',
      ),
    };
    final install = error is WalletNotInstalled ? onInstall : null;
    return Column(
      key: ValueKey('wallet-state-$key'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: icon,
          title: title,
          message: message,
          color: Puls3Colors.accent,
        ),
        const SizedBox(height: Puls3Spacing.md),
        if (install != null) ...[
          PrimaryButton(
            label: 'Install $walletName',
            icon: Icons.open_in_new_rounded,
            expand: true,
            onPressed: install,
          ),
          const SizedBox(height: Puls3Spacing.xs),
        ],
        PrimaryButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          variant: install == null
              ? PrimaryButtonVariant.filled
              : PrimaryButtonVariant.outline,
          expand: true,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
