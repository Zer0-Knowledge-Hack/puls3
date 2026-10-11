import 'package:flutter/foundation.dart';

import '../wallet/wallet_port.dart';

/// The wallet as the UI sees it: one explicit state, never a mix of flags.
enum WalletStatus {
  disconnected,
  connecting,
  connected,

  /// The wallet is showing a signing prompt.
  signing,

  /// Connected, and the last transaction was signed.
  signed,

  /// The user declined the connection or the signature in the wallet.
  rejected,

  /// The wallet is not on Stellar Testnet; nothing can be signed.
  wrongNetwork,

  /// Any other failure (not installed, locked, account changed, refused
  /// payload): see [WalletController.lastError].
  error,
}

/// Observable wrapper around a [WalletPort]: the container that owns the
/// connection state (#25). Presentational widgets get its values through
/// their constructors. It knows nothing about deploys, hires or escrow.
class WalletController extends ChangeNotifier {
  WalletController(
    this._wallet, {
    this.connectTimeout = const Duration(minutes: 2),
  });

  final WalletPort _wallet;

  /// Upper bound for the connect prompt, so a popup that is ignored,
  /// blocked or stuck never leaves a flow waiting forever. Null disables it.
  final Duration? connectTimeout;

  /// Bumped by [disconnect], so a connect that finishes afterwards is
  /// dropped instead of reconnecting behind the user's back.
  int _session = 0;

  /// [WalletStatus.connecting] or [WalletStatus.signing] while the wallet
  /// is busy; null otherwise.
  WalletStatus? _busy;
  bool _signed = false;
  WalletException? _lastError;

  String get walletName => _wallet.name;
  Uri? get installUrl => _wallet.installUrl;
  String? get address => _wallet.address;
  String? get network => _wallet.network;
  bool get isConnected => _wallet.address != null;
  bool get isConnecting => _busy == WalletStatus.connecting;
  bool get isOnTestnet => _wallet.network == stellarTestnetPassphrase;

  /// Why the last connection or signature failed, until the next attempt.
  WalletException? get lastError => _lastError;

  WalletStatus get status {
    final busy = _busy;
    if (busy != null) return busy;
    final error = _lastError;
    if (error != null) {
      return switch (error) {
        WalletSignatureRejected() => WalletStatus.rejected,
        WalletWrongNetwork() => WalletStatus.wrongNetwork,
        _ => WalletStatus.error,
      };
    }
    if (isConnected) {
      return _signed ? WalletStatus.signed : WalletStatus.connected;
    }
    return WalletStatus.disconnected;
  }

  /// Connects and returns the address. Throws a [WalletException] on
  /// failure, for flows that map it themselves (deploy, hire). UI buttons
  /// use [tryConnect] instead.
  Future<String> connect() async {
    final existing = _wallet.address;
    if (existing != null) return existing;
    final session = _session;
    _busy = WalletStatus.connecting;
    _lastError = null;
    _signed = false;
    notifyListeners();
    try {
      final timeout = connectTimeout;
      final attempt = _wallet.connect();
      final address = await (timeout == null
          ? attempt
          : attempt.timeout(
              timeout,
              onTimeout: () => throw const WalletTimedOut(),
            ));
      if (session != _session) {
        // Disconnected while the prompt was open: do not stay connected.
        await _wallet.disconnect();
        throw const WalletSignatureRejected();
      }
      return address;
    } on WalletException catch (e) {
      if (session == _session) _lastError = e;
      rethrow;
    } finally {
      if (session == _session) _busy = null;
      notifyListeners();
    }
  }

  /// Connects from a button: a failure becomes [lastError] (a recoverable
  /// state), never an unhandled exception. Returns whether it connected.
  Future<bool> tryConnect() async {
    if (_busy != null) return false;
    _lastError = null;
    try {
      await connect();
      return true;
    } on WalletException {
      return false;
    }
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _session++;
    _busy = null;
    await _wallet.disconnect();
    _lastError = null;
    _signed = false;
    notifyListeners();
  }

  /// Signs a server-prepared transaction unchanged; returns the signed XDR.
  ///
  /// Refuses before any prompt when the wallet is not on Testnet. If the
  /// wallet switched network or account, the session is forgotten so the
  /// next attempt connects again.
  Future<String> signTransaction(String unsignedXdr) =>
      _sign(() => _wallet.signTransaction(unsignedXdr));

  /// Signs a Soroban authorization entry; returns the signed entry XDR.
  Future<String> signAuthEntry(String entryXdr) =>
      _sign(() => _wallet.signAuthEntry(entryXdr));

  /// Signs a SEP-10 sign-in challenge (#136); returns the signed XDR.
  Future<String> signChallenge(SignInChallenge challenge) =>
      _sign(() => _wallet.signChallenge(challenge));

  Future<String> _sign(Future<String> Function() sign) async {
    _lastError = null;
    _signed = false;
    try {
      if (!isConnected) throw const WalletUnavailable();
      if (!isOnTestnet) throw const WalletWrongNetwork();
      _busy = WalletStatus.signing;
      notifyListeners();
      final signed = await sign();
      _signed = true;
      return signed;
    } on WalletException catch (e) {
      _lastError = e;
      if (e is WalletWrongNetwork || e is WalletAccountChanged) {
        await _wallet.disconnect();
      }
      rethrow;
    } finally {
      _busy = null;
      notifyListeners();
    }
  }
}
