import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/wallet_panel.dart';

/// Opens the wallet sheet (S09). It connects, shows the connected account
/// with Disconnect, and keeps every failure as a recoverable state.
Future<void> showWalletSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const WalletSheet(),
  );
}

/// Container for [WalletPanel]: listens to the app's wallet controller.
class WalletSheet extends StatelessWidget {
  const WalletSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = AppScope.of(context).wallet;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final gutter = narrow ? Puls3Spacing.md : Puls3Spacing.lg;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Puls3Spacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: wallet,
            builder: (context, _) {
              final installUrl = wallet.installUrl;
              return WalletPanel(
                status: wallet.status,
                walletName: wallet.walletName,
                address: wallet.address,
                isOnTestnet: wallet.isOnTestnet,
                error: wallet.lastError,
                onConnect: () => unawaited(wallet.tryConnect()),
                onDisconnect: () => unawaited(wallet.disconnect()),
                onInstall: installUrl == null
                    ? null
                    : () => unawaited(
                        launchUrl(
                          installUrl,
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
