import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/agent.dart';
import '../domain/usdc.dart';
import '../state/app_scope.dart';
import '../state/notification_center.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/hire_payment_view.dart';
import '../ui/organisms/reviews_section.dart';
import '../wallet/wallet_port.dart';

/// Opens the hire and pay flow for [agent].
Future<void> showHireSheet(BuildContext context, Agent agent) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => HireSheet(agent: agent),
  );
}

/// Container for the hire flow: owns the phase, talks to the wallet, maps
/// every wallet failure to a message with a retry, and records the hire.
class HireSheet extends StatefulWidget {
  const HireSheet({super.key, required this.agent});

  final Agent agent;

  @override
  State<HireSheet> createState() => _HireSheetState();
}

class _HireSheetState extends State<HireSheet> {
  HirePhase _phase = HirePhase.review;
  HireFailure? _failure;
  String? _txHash;

  Future<void> _connect() async {
    try {
      await AppScope.of(context).wallet.connect();
    } on WalletException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = HirePhase.failed;
        _failure = _failureFor(e);
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    if (_phase == HirePhase.signing) return; // no double payment
    final scope = AppScope.of(context);
    setState(() {
      _phase = HirePhase.signing;
      _failure = null;
    });
    try {
      // Mock payload: the escrow `fund` call is prepared by the server
      // (API contract #77) once the hire endpoint exists.
      final hash = await scope.wallet.signTransaction(
        'mock-escrow-fund:${widget.agent.id}:${widget.agent.priceUsdcStroops}',
      );
      if (!mounted) return;
      scope.reviews.markHired(widget.agent.id);
      scope.notifications.push(
        kind: NotificationKind.hire,
        title: 'Hire started',
        body:
            '${formatUsdc(widget.agent.priceUsdcStroops)} USDC held in escrow '
            'for ${widget.agent.name}.',
        route: '/agent/${widget.agent.id}',
      );
      setState(() {
        _txHash = hash;
        _phase = HirePhase.confirmed;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = HirePhase.failed;
        _failure = e is WalletException ? _failureFor(e) : HireFailure.unknown;
      });
    }
  }

  static HireFailure _failureFor(WalletException e) => switch (e) {
    WalletSignatureRejected() => HireFailure.rejected,
    WalletInsufficientFunds() => HireFailure.insufficientFunds,
    WalletWrongNetwork() => HireFailure.wrongNetwork,
    WalletUnavailable() => HireFailure.walletUnavailable,
  };

  void _backToMarketplace() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/market');
  }

  void _rate() {
    final scope = AppScope.of(context);
    final author =
        scope.profile.profileFor(scope.wallet.address)?.displayName ?? 'You';
    showRateSheet(
      context,
      agentName: widget.agent.name,
      onSubmit: (rating, comment) => scope.reviews.add(
        agentId: widget.agent.id,
        author: author,
        rating: rating,
        comment: comment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.wallet, scope.reviews]),
      builder: (context, _) => PopScope(
        canPop: _phase != HirePhase.signing,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            narrow ? Puls3Spacing.md : Puls3Spacing.lg,
            0,
            narrow ? Puls3Spacing.md : Puls3Spacing.lg,
            Puls3Spacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: HirePaymentView(
                phase: _phase,
                failure: _failure,
                agentName: widget.agent.name,
                priceUsdcStroops: widget.agent.priceUsdcStroops,
                destinationAddress: widget.agent.stellarAddress,
                walletConnected: scope.wallet.isConnected,
                txHash: _txHash,
                onConfirm: _confirm,
                onConnectWallet: _connect,
                onCancel: () => Navigator.of(context).pop(),
                onBackToMarketplace: _backToMarketplace,
                onViewTransaction: _txHash == null
                    ? null
                    : () => unawaited(
                        launchUrl(
                          Uri.parse(
                            'https://stellar.expert/explorer/testnet/tx/'
                            '$_txHash',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                onRate: scope.reviews.canRate(widget.agent.id) ? _rate : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
