import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../hire/hire_flow_controller.dart' show walletErrorMessage;
import '../hire/hire_gateway.dart';
import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../state/wallet_controller.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/molecules/empty_state.dart';
import '../ui/molecules/error_banner.dart';
import '../ui/molecules/screen_header.dart';
import '../ui/organisms/my_hires_view.dart';
import '../wallet/wallet_port.dart';

enum _Status { loading, ready, needsWallet, needsSignIn, error }

/// `/hires` (My hires): the container. It lists the connected wallet's
/// hires through [HireGateway.listMyHires] and opens one at `/hires/:id`.
/// The presentational [MyHiresView] never calls the gateway.
class MyHiresScreen extends StatefulWidget {
  const MyHiresScreen({super.key});

  @override
  State<MyHiresScreen> createState() => _MyHiresScreenState();
}

class _MyHiresScreenState extends State<MyHiresScreen> {
  _Status _status = _Status.loading;
  List<HireSummaryItem> _hires = const [];
  String? _error;
  bool _busy = false;
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
  void dispose() {
    _wallet?.removeListener(_onWallet);
    super.dispose();
  }

  void _onWallet() {
    final address = _wallet?.address;
    if (address == _address) return;
    _address = address;
    setState(() {
      _hires = const [];
      _status = _Status.loading;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    final consumer = _wallet?.address;
    if (consumer == null) {
      setState(() => _status = _Status.needsWallet);
      return;
    }
    setState(() => _busy = true);
    try {
      final hires = await AppScope.of(
        context,
      ).hireGateway.listMyHires(consumer);
      if (!mounted || request != _request) return;
      setState(() {
        _hires = hires;
        _error = null;
        _busy = false;
        _status = _Status.ready;
      });
    } on HireGatewayException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _busy = false;
        if (e is HireNotSignedIn) {
          _status = _Status.needsSignIn;
        } else {
          _error = e.message;
          _status = _Status.error;
        }
      });
    }
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
        _error = walletErrorMessage(e);
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = _error;
    final Widget body = switch (_status) {
      _Status.needsWallet => EmptyState(
        key: const ValueKey('my-hires-connect'),
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.myHiresConnectTitle,
        message: l10n.myHiresConnectBody,
        actionLabel: l10n.myHiresConnectAction,
        onAction: () => unawaited(_wallet!.tryConnect()),
      ),
      _Status.needsSignIn => Column(
        key: const ValueKey('my-hires-sign-in'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyState(
            icon: Icons.lock_outline_rounded,
            title: l10n.myHiresSignInTitle,
            message: l10n.myHiresSignInBody,
            actionLabel: _busy
                ? l10n.myHiresSigningIn
                : l10n.myHiresSignInAction,
            onAction: _busy ? () {} : () => unawaited(_signIn()),
          ),
          if (error != null)
            Text(
              error,
              textAlign: TextAlign.center,
              style: Puls3Text.bodyMuted.copyWith(color: Puls3Colors.accent),
            ),
        ],
      ),
      _Status.error => ErrorBanner(
        key: const ValueKey('my-hires-error'),
        title: l10n.myHiresLoadErrorTitle,
        message: error ?? '',
        retrying: _busy,
        onRetry: () => unawaited(_load()),
      ),
      _Status.loading => const Padding(
        key: ValueKey('my-hires-loading'),
        padding: EdgeInsets.symmetric(vertical: Puls3Spacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      _Status.ready => Expanded(
        child: MyHiresView(
          key: const ValueKey('my-hires'),
          hires: _hires,
          isDemo: AppScope.of(context).hireGateway.isDemo,
          initialTab: _hires.any((h) => h.tab == HireListTab.needsAction)
              ? HireListTab.needsAction
              : HireListTab.inProgress,
          onOpenHire: (hire) => context.go(
            hire.paidByAgentId == null
                ? '/hires/${hire.hireId}'
                : '/hires/${hire.hireId}?as=${hire.paidByAgentId}',
          ),
          onBrowseMarketplace: () => context.go('/market'),
        ),
      ),
    };
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.only(top: Puls3Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: l10n.myHiresTitle,
              subtitle: l10n.myHiresSubtitle,
            ),
            const SizedBox(height: Puls3Spacing.lg),
            body,
          ],
        ),
      ),
    );
  }
}
