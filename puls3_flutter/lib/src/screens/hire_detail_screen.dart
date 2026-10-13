import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/stellar_explorer.dart';
import '../hire/hire_flow_controller.dart' show walletErrorMessage;
import '../hire/hire_gateway.dart';
import '../state/app_scope.dart';
import '../state/wallet_controller.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/molecules/empty_state.dart';
import '../ui/molecules/error_banner.dart';
import '../ui/organisms/hire_detail_view.dart';
import '../ui/organisms/site_footer.dart';
import '../wallet/wallet_port.dart';

Future<void> _launch(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

Future<void> _copy(String text) => Clipboard.setData(ClipboardData(text: text));

enum _Status { loading, ready, notFound, needsWallet, needsSignIn, error }

/// `/hires/:id` (S06, flow F6): the container. It reads the hire with the
/// connected wallet (`HireEndpoint.getHire`) and polls it every
/// [pollInterval] until nothing changes without the client any more.
///
/// Approve and Reject are not offered yet: they need the agent's
/// server-signed `submit` (#97), so a hire stops at "result ready".
class HireDetailScreen extends StatefulWidget {
  const HireDetailScreen({
    super.key,
    required this.hireId,
    this.openUrl = _launch,
    this.copyText = _copy,
    this.pollInterval = const Duration(seconds: 4),
  });

  /// The `:id` path parameter, unparsed.
  final String hireId;
  final Future<void> Function(Uri url) openUrl;
  final Future<void> Function(String text) copyText;
  final Duration pollInterval;

  @override
  State<HireDetailScreen> createState() => _HireDetailScreenState();
}

class _HireDetailScreenState extends State<HireDetailScreen> {
  _Status _status = _Status.loading;
  HireProgress? _hire;

  /// Why the last refresh or sign-in failed, until the next attempt.
  String? _error;
  bool _busy = false;
  Timer? _poll;
  WalletController? _wallet;
  String? _address;

  /// Bumped per request, so a stale answer never overwrites a newer one.
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = AppScope.of(context).wallet;
    if (identical(wallet, _wallet)) return;
    _wallet?.removeListener(_onWallet);
    _wallet = wallet..addListener(_onWallet);
    _address = wallet.address;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(HireDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hireId != widget.hireId) _restart();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _wallet?.removeListener(_onWallet);
    super.dispose();
  }

  /// Another account can read other hires only: start over with it.
  void _onWallet() {
    final address = _wallet?.address;
    if (address == _address) return;
    _address = address;
    _restart();
  }

  void _restart() {
    setState(() {
      _hire = null;
      _error = null;
      _status = _Status.loading;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    _poll?.cancel();
    final request = ++_request;
    final id = int.tryParse(widget.hireId);
    if (id == null || id < 1) {
      setState(() => _status = _Status.notFound);
      return;
    }
    final consumer = _wallet?.address;
    if (consumer == null) {
      setState(() => _status = _Status.needsWallet);
      return;
    }
    setState(() => _busy = true);
    try {
      final hire = await AppScope.of(
        context,
      ).hireGateway.getHire(id, consumer);
      if (!mounted || request != _request) return;
      setState(() {
        _hire = hire;
        _error = null;
        _busy = false;
        _status = _Status.ready;
      });
      if (!hire.stage.isFinal) {
        _poll = Timer(widget.pollInterval, () => unawaited(_load()));
      }
    } on HireGatewayException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _busy = false;
        switch (e) {
          case HireNotFound():
            _hire = null;
            _status = _Status.notFound;
          case HireNotSignedIn():
            _status = _Status.needsSignIn;
          default:
            _error = e.message;
            _status = _hire == null ? _Status.error : _Status.ready;
        }
      });
    }
  }

  Future<void> _connect() async {
    // A connected wallet notifies [_onWallet], which loads the hire.
    await _wallet!.tryConnect();
  }

  Future<void> _signIn() async {
    final wallet = _wallet!;
    final address = wallet.address;
    if (address == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(
        context,
      ).hireGateway.ensureSignedIn(address, wallet.signChallenge);
    } on WalletException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is WalletSignatureRejected
            ? 'You cancelled the sign-in in your wallet.'
            : walletErrorMessage(e);
      });
      return;
    } on HireGatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _status = _Status.loading);
    await _load();
  }

  void _back() => context.go('/market');

  void _openPayment(HireProgress hire) {
    final url =
        hire.paymentExplorerUrl ?? stellarExpertTxUrl(hire.paymentTransaction!);
    unawaited(widget.openUrl(Uri.parse(url)));
  }

  Future<void> _copyResult(String result) async {
    await widget.copyText(result);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Result copied')));
  }

  @override
  Widget build(BuildContext context) {
    final hire = _hire;
    final error = _error;
    final Widget body = switch (_status) {
      _Status.notFound => EmptyState(
        key: const ValueKey('hire-detail-not-found'),
        icon: Icons.receipt_long_outlined,
        title: 'Hire not found',
        message:
            'No hire with this id belongs to the connected wallet. The link '
            'may be wrong, or the hire was made with another account.',
        actionLabel: 'Back to Marketplace',
        onAction: _back,
      ),
      _Status.needsWallet => EmptyState(
        key: const ValueKey('hire-detail-connect'),
        icon: Icons.account_balance_wallet_outlined,
        title: 'Connect your wallet',
        message: 'Only the wallet that paid for this hire can see it.',
        actionLabel: 'Connect wallet',
        onAction: () => unawaited(_connect()),
      ),
      _Status.needsSignIn => Column(
        key: const ValueKey('hire-detail-sign-in'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Sign in to see this hire',
            message:
                'Your wallet signs a sign-in message. It only proves the '
                'account is yours and moves no funds.',
            actionLabel: _busy ? 'Signing in…' : 'Sign in with wallet',
            onAction: _busy ? () {} : () => unawaited(_signIn()),
          ),
          if (error != null)
            Text(
              error,
              textAlign: TextAlign.center,
              style: Puls3Text.bodyMuted.copyWith(color: Puls3Colors.accent),
            ),
          const SizedBox(height: Puls3Spacing.xl),
        ],
      ),
      _Status.error => Column(
        key: const ValueKey('hire-detail-error'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Puls3Spacing.xl),
          ErrorBanner(
            title: 'Could not load this hire',
            message: error ?? 'The puls3 server did not answer.',
            retrying: _busy,
            onRetry: () => unawaited(_load()),
          ),
          const SizedBox(height: Puls3Spacing.xxl),
        ],
      ),
      _ when hire == null => const Padding(
        key: ValueKey('hire-detail-loading'),
        padding: EdgeInsets.symmetric(vertical: Puls3Spacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      _ => HireDetailView(
        key: const ValueKey('hire-detail'),
        hire: hire,
        onBackToMarketplace: _back,
        onOpenPayment: hire.paymentTransaction == null
            ? null
            : () => _openPayment(hire),
        onCopyResult: hire.result == null
            ? null
            : () => unawaited(_copyResult(hire.result!)),
        banner: error == null
            ? null
            : ErrorBanner(
                key: const ValueKey('hire-detail-stale'),
                title: 'Showing the last known status',
                message: error,
                retrying: _busy,
                onRetry: () => unawaited(_load()),
              ),
      ),
    };
    return SingleChildScrollView(
      child: Column(
        children: [
          ContentWidth(child: body),
          const SiteFooter(),
        ],
      ),
    );
  }
}
