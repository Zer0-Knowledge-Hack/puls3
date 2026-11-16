import 'package:puls3_flutter/src/wallet/wallet_port.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// A [WalletPort] for the browser E2E (#256): it signs in memory with an
/// ephemeral Stellar key, so no Freighter popup is needed.
///
/// It is a test fixture, not a wallet: the secret is handed in by the test
/// run and lives only in memory. It signs the server's envelopes unchanged,
/// like a wallet does, and it signs for [signingPassphrase], the local sandbox
/// network.
///
/// [network] still reports the testnet passphrase. The app gates every
/// signature on the wallet being on testnet (`WalletController.isOnTestnet`),
/// and that gate is app behaviour this suite must not change.
final class AutomatedKeyWallet implements WalletPort {
  AutomatedKeyWallet({
    required String secretSeed,
    required this.signingPassphrase,
  }) : _key = KeyPair.fromSecretSeed(secretSeed);

  /// The network the signatures cover: the local standalone network.
  final String signingPassphrase;

  final KeyPair _key;
  String? _address;

  @override
  String get name => 'Automated key';

  @override
  Uri? get installUrl => null;

  @override
  Future<String> connect() async => _address = _key.accountId;

  @override
  Future<void> disconnect() async => _address = null;

  @override
  String? get address => _address;

  @override
  String? get network => _address == null ? null : stellarTestnetPassphrase;

  @override
  Future<String> signTransaction(String unsignedXdr) async =>
      _sign(unsignedXdr, signingPassphrase);

  /// The sign-in challenge carries the network it must be signed for.
  @override
  Future<String> signChallenge(SignInChallenge challenge) async =>
      _sign(challenge.transactionXdr, challenge.networkPassphrase);

  /// The hire flow never signs an authorization entry; Studio does.
  @override
  Future<String> signAuthEntry(String entryXdr) =>
      throw UnsupportedError('The hire flow signs no authorization entry.');

  String _sign(String xdr, String passphrase) {
    if (_address == null) throw const WalletUnavailable();
    final envelope = AbstractTransaction.fromEnvelopeXdrString(xdr);
    envelope.sign(_key, Network(passphrase));
    return envelope.toEnvelopeXdrBase64();
  }
}
