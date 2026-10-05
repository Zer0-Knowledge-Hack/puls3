@JS()
library;

import 'dart:js_interop';
import 'dart:convert';

import 'wallet_port.dart';
import 'wallet_service.dart';

@JS('puls3FreighterConnect')
external JSPromise<JSString> _connect();
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

final class FreighterWebBridge implements FreighterBridge {
  @override
  Future<WalletSession> connect() async {
    try {
      return _decodeSession((await _connect().toDart).toDart);
    } catch (error) {
      throw WalletUnavailable('Freighter connection failed: $error');
    }
  }

  @override
  Future<WalletSession> currentSession() async {
    try {
      return _decodeSession((await _currentSession().toDart).toDart);
    } catch (error) {
      throw WalletUnavailable('Freighter session check failed: $error');
    }
  }

  @override
  Future<String> signTransaction(
    String xdr,
    String networkPassphrase,
    String address,
  ) => _translate(
    _signTransaction(xdr.toJS, networkPassphrase.toJS, address.toJS),
  );

  @override
  Future<AuthEntrySignature> signAuthEntryPreimage(
    String preimageXdr,
    String networkPassphrase,
    String address,
  ) async {
    final source = await _translate(
      _signAuthEntryPreimage(
        preimageXdr.toJS,
        networkPassphrase.toJS,
        address.toJS,
      ),
    );
    final Object? value;
    try {
      value = jsonDecode(source);
    } on FormatException {
      throw const InvalidEnvelope('Bridge returned a malformed signature.');
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
    throw const InvalidEnvelope('Bridge returned a malformed signature.');
  }

  WalletSession _decodeSession(String source) {
    final value = jsonDecode(source) as Map<String, dynamic>;
    final address = value['address'];
    final passphrase = value['networkPassphrase'];
    if (address is! String || passphrase is! String) {
      throw const FormatException('Invalid session payload');
    }
    return WalletSession(address: address, networkPassphrase: passphrase);
  }

  Future<String> _translate(JSPromise<JSString> promise) async {
    try {
      return (await promise.toDart).toDart;
    } catch (error) {
      final message = error.toString();
      if (message.contains('wrong_network:')) {
        throw WrongNetwork(message);
      }
      if (message.contains('account_changed:')) {
        throw WalletAccountChanged(message);
      }
      throw WalletRejected('wallet_rejected: $message');
    }
  }
}
