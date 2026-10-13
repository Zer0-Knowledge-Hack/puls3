import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import '../wallet_port.dart';
import 'freighter_bridge.dart';

@JS('puls3FreighterConnect')
external JSPromise<JSString>? _connect();

/// Set by `web/index.html` when `freighter_bridge.js` failed to load.
@JS('puls3FreighterBridgeFailed')
external JSBoolean? get _bridgeFailed;

@JS('puls3FreighterCurrentSession')
external JSPromise<JSString> _currentSession();

@JS('puls3FreighterSignTransaction')
external JSPromise<JSString> _signTransaction(
  JSString xdr,
  JSString passphrase,
  JSString address,
);

@JS('puls3FreighterSignAuthEntryPreimage')
external JSPromise<JSString> _signAuthEntryPreimage(
  JSString xdr,
  JSString passphrase,
  JSString address,
);

/// The web [FreighterBridge]: calls `web/freighter_bridge.js` through JS
/// interop and turns its "<code>: message" errors into [WalletException]s.
FreighterBridge createFreighterBridge() => _FreighterWebBridge();

final class _FreighterWebBridge implements FreighterBridge {
  @override
  Future<FreighterSession> connect() async {
    final JSPromise<JSString>? promise;
    try {
      promise = _connect();
    } on Object {
      // The bridge script did not load: no extension API to talk to.
      throw _bridgeMissing();
    }
    if (promise == null) throw _bridgeMissing();
    return _session(await _call(promise));
  }

  @override
  Future<FreighterSession> currentSession() async =>
      _session(await _call(_currentSession()));

  @override
  Future<String> signTransaction(
    String xdr,
    String networkPassphrase,
    String address,
  ) => _call(_signTransaction(xdr.toJS, networkPassphrase.toJS, address.toJS));

  @override
  Future<AuthEntrySignature> signAuthEntryPreimage(
    String preimageXdr,
    String networkPassphrase,
    String address,
  ) async {
    final raw = await _call(
      _signAuthEntryPreimage(
        preimageXdr.toJS,
        networkPassphrase.toJS,
        address.toJS,
      ),
    );
    final Object? value;
    try {
      value = jsonDecode(raw);
    } on FormatException {
      throw const WalletInvalidPayload('Freighter returned a bad signature.');
    }
    if (value case {
      'signature': final String signature,
      'signerAddress': final String? signerAddress,
    }) {
      return AuthEntrySignature(
        signature: signature,
        signerAddress: signerAddress,
      );
    }
    throw const WalletInvalidPayload('Freighter returned a bad signature.');
  }

  FreighterSession _session(String raw) {
    final Object? value;
    try {
      value = jsonDecode(raw);
    } on FormatException {
      throw const WalletUnavailable();
    }
    if (value case {
      'address': final String address,
      'networkPassphrase': final String passphrase,
    }) {
      return FreighterSession(address: address, networkPassphrase: passphrase);
    }
    throw const WalletUnavailable();
  }

  Future<String> _call(JSPromise<JSString> promise) async {
    try {
      return (await promise.toDart).toDart;
    } on WalletException {
      rethrow;
    } on Object catch (error) {
      throw _translate(error.toString());
    }
  }

  /// Why there is no bridge to call: it failed to load (the wallet may be
  /// installed), or it loaded nothing, which only happens without a wallet.
  static WalletException _bridgeMissing() => bridgeMissingError(
    bridgeFailedToLoad: _bridgeFailed?.toDart ?? false,
  );

  static WalletException _translate(String message) {
    if (message.contains('not_installed:')) return const WalletNotInstalled();
    if (message.contains('wrong_network:')) return const WalletWrongNetwork();
    if (message.contains('account_changed:')) {
      return const WalletAccountChanged();
    }
    if (message.contains('unavailable:')) return const WalletUnavailable();
    if (message.contains('invalid:')) {
      return const WalletInvalidPayload('Freighter returned bad data.');
    }
    // Freighter reports a declined prompt as an error result ("rejected:").
    if (message.contains('rejected:')) return const WalletSignatureRejected();
    // Anything else (a JS error, an extension crash) is not the user saying
    // no. Log only that it happened: messages may carry payload data.
    debugPrint('Freighter bridge failed with an unexpected error.');
    return const WalletUnavailable();
  }
}
