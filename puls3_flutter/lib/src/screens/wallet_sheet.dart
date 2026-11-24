import 'dart:async';

import 'package:flutter/material.dart';
import 'package:puls3_client/puls3_client.dart' as api;
import 'package:url_launcher/url_launcher.dart';

import '../cli/cli_session_dialog.dart';
import '../cli/cli_session_issuer.dart';
import '../state/app_scope.dart';
import '../state/wallet_controller.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/wallet_panel.dart';

/// Opens the wallet sheet (S09). It connects, shows the connected account
/// with Disconnect, and keeps every failure as a recoverable state.
Future<void> showWalletSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the whole app, so the phone's bottom navigation bar does not
    // cover the end of the sheet.
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const WalletSheet(),
  );
}

/// Container for [WalletPanel]: listens to the app's wallet controller and
/// loads the CLI sessions of the connected wallet (#344).
class WalletSheet extends StatefulWidget {
  const WalletSheet({super.key});

  @override
  State<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<WalletSheet> {
  WalletController? _wallet;
  String? _cliWallet;
  List<api.CliSession>? _cliSessions;
  String? _cliSessionsError;
  bool _loadingCliSessions = false;
  bool _reloadRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = AppScope.of(context).wallet;
    if (identical(wallet, _wallet)) return;
    _wallet?.removeListener(_onWallet);
    _wallet = wallet..addListener(_onWallet);
    _syncCliWallet();
  }

  @override
  void dispose() {
    _wallet?.removeListener(_onWallet);
    super.dispose();
  }

  void _onWallet() {
    if (!mounted) return;
    _syncCliWallet();
    setState(() {});
  }

  /// Starts over when the connected address changes, and clears the list on
  /// disconnect.
  void _syncCliWallet() {
    final address = _wallet?.address;
    if (address == _cliWallet) return;
    _cliWallet = address;
    _cliSessions = null;
    _cliSessionsError = null;
    if (address != null) unawaited(_loadCliSessions(force: true));
  }

  CliSessionIssuer? get _cli => AppScope.of(context).cliSessions;

  Future<void> _loadCliSessions({bool force = false}) async {
    final cli = _cli;
    final address = _wallet?.address;
    if (cli == null || address == null) return;
    if (_loadingCliSessions) {
      if (force) _reloadRequested = true;
      return;
    }
    if (!force && _cliSessions != null) return;
    _loadingCliSessions = true;
    try {
      final sessions = await cli.list(address);
      if (!mounted || _cliWallet != address) return;
      setState(() {
        _cliSessions = sessions;
        _cliSessionsError = null;
      });
    } on api.ServerpodClientUnauthorized {
      // The wallet is connected but the app has no session yet. The copy
      // action signs in; until then there is nothing to list.
      if (!mounted || _cliWallet != address) return;
      setState(() {
        _cliSessions = const [];
        _cliSessionsError = null;
      });
    } on Object catch (e) {
      if (!mounted || _cliWallet != address) return;
      debugPrint('CLI sessions: could not load: $e');
      setState(() {
        _cliSessionsError = _cliSessions == null
            ? 'Could not load CLI sessions. The server did not answer.'
            : 'Could not refresh CLI sessions. The list below may be stale.';
      });
    } finally {
      _loadingCliSessions = false;
      if (_reloadRequested && mounted) {
        _reloadRequested = false;
        unawaited(_loadCliSessions(force: true));
      }
    }
  }

  Future<void> _copyCliSession() async {
    final cli = _cli;
    final address = _wallet?.address;
    if (cli == null || address == null) return;
    await showCliSessionDialog(
      context,
      issue: () async {
        final grant = await cli.issue(address);
        // Reload while the dialog is open, so the new session is listed as
        // soon as the token is shown.
        unawaited(_loadCliSessions(force: true));
        return grant;
      },
    );
    if (mounted) unawaited(_loadCliSessions(force: true));
  }

  Future<void> _revokeCliSession(api.CliSession session) async {
    final cli = _cli;
    final address = _wallet?.address;
    if (cli == null || address == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('Revoke CLI session?'),
        content: const Text(
          'A revoked session can still answer for up to 10 minutes. '
          'Revoking it does not sign out this app.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('cli-session-revoke-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('cli-session-revoke-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _wallet?.address != address) {
      return;
    }
    try {
      final revoked = await cli.revoke(address, session.id);
      if (!mounted || _wallet?.address != address) return;
      if (!revoked) {
        setState(
          () => _cliSessionsError =
              'That CLI session is no longer live. The list was refreshed.',
        );
        unawaited(_loadCliSessions(force: true));
        return;
      }
      setState(() {
        _cliSessions = [
          for (final other in _cliSessions ?? const <api.CliSession>[])
            if (other.id != session.id) other,
        ];
        _cliSessionsError = null;
      });
    } on api.ServerpodClientUnauthorized {
      if (!mounted || _wallet?.address != address) return;
      setState(() {
        _cliSessions = const [];
        _cliSessionsError =
            'Your app session ended. Copy a new session for the CLI.';
      });
    } on Object catch (e) {
      if (!mounted || _wallet?.address != address) return;
      debugPrint('CLI sessions: could not revoke: $e');
      setState(
        () => _cliSessionsError =
            'Could not revoke the CLI session. The server did not answer.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    if (wallet == null) return const SizedBox.shrink();
    final narrow =
        MediaQuery.sizeOf(context).width < Puls3Breakpoints.narrowGutter;
    final gutter = narrow ? Puls3Spacing.md : Puls3Spacing.lg;
    final installUrl = wallet.installUrl;
    final address = wallet.address;
    final cli = _cli;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Puls3Spacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: WalletPanel(
            status: wallet.status,
            walletName: wallet.walletName,
            address: address,
            isOnTestnet: wallet.isOnTestnet,
            error: wallet.lastError,
            onConnect: () => unawaited(wallet.tryConnect()),
            onDisconnect: () => unawaited(wallet.disconnect()),
            onCopyCliSession: cli == null || address == null
                ? null
                : () => unawaited(_copyCliSession()),
            cliSessions: cli == null ? null : _cliSessions,
            onRevokeCliSession: cli == null
                ? null
                : (session) => unawaited(_revokeCliSession(session)),
            onRetryCliSessions: cli == null
                ? null
                : () => unawaited(_loadCliSessions(force: true)),
            cliSessionsError: _cliSessionsError,
            onInstall: installUrl == null
                ? null
                : () => unawaited(
                    launchUrl(
                      installUrl,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
