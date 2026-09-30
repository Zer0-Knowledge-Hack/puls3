import 'dart:convert';
import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'wallet_port.dart';

abstract interface class FreighterBridge {
  Future<WalletSession> connect();
  Future<WalletSession> currentSession();
  Future<String> signTransaction(
    String xdr,
    String networkPassphrase,
    String address,
  );

  /// Mirrors Freighter's `signAuthEntry`: [preimageXdr] is the base64 XDR of
  /// a `HashIdPreimage` (ENVELOPE_TYPE_SOROBAN_AUTHORIZATION or, for
  /// ADDRESS_V2, ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS) and the wallet
  /// answers with an ed25519 signature over sha256(preimage), not with a
  /// signed `SorobanAuthorizationEntry`.
  Future<AuthEntrySignature> signAuthEntryPreimage(
    String preimageXdr,
    String networkPassphrase,
    String address,
  );
}

/// Wallet answer to an auth-entry preimage signing request.
final class AuthEntrySignature {
  const AuthEntrySignature({required this.signature, this.signerAddress});

  /// Base64 of the raw 64-byte ed25519 signature.
  final String signature;

  /// Signer reported by the wallet, when it reports one.
  final String? signerAddress;
}

final class FreighterWallet implements WalletPort {
  FreighterWallet(this._bridge);
  final FreighterBridge _bridge;
  WalletSession? _session;

  @override
  Future<WalletSession> connect() async {
    final session = await _bridge.connect();
    if (session.networkPassphrase != stellarTestnetPassphrase) {
      throw WrongNetwork('Freighter must be switched to Stellar Testnet.');
    }
    _session = session;
    return session;
  }

  @override
  Future<String> signTransaction(String transactionXdr) async {
    final session = _requireSession();
    await _assertActiveSession(session);
    final unsigned = _parse(transactionXdr);
    if (unsigned is Transaction) _assertSourceBinding(unsigned, session);
    final signedXdr = await _bridge.signTransaction(
      transactionXdr,
      stellarTestnetPassphrase,
      session.address,
    );
    final signed = _parse(signedXdr);
    if (unsigned is! Transaction || signed is! Transaction) {
      throw const InvalidEnvelope(
        'Only standard transaction envelopes are supported by this spike.',
      );
    }
    if (unsigned.toXdrBase64() != signed.toXdrBase64()) {
      throw const ModifiedEnvelope('Wallet changed transaction semantics.');
    }
    final originalSignatures = unsigned.signatures
        .map((signature) => signature.toBase64EncodedXdrString())
        .toList();
    final added = signed.signatures.where((signature) {
      final encoded = signature.toBase64EncodedXdrString();
      final index = originalSignatures.indexOf(encoded);
      if (index == -1) return true;
      originalSignatures.removeAt(index);
      return false;
    }).toList();
    if (added.isEmpty) {
      throw const InvalidEnvelope('Wallet did not add a new signature.');
    }
    final key = KeyPair.fromAccountId(session.address);
    final hash = signed.hash(Network.TESTNET);
    if (!added.any(
      (signature) => key.verify(hash, signature.signature.signature),
    )) {
      throw const InvalidEnvelope(
        'Wallet did not add a valid signature from the connected account.',
      );
    }
    return signedXdr;
  }

  /// Signs a server-simulated `SorobanAuthorizationEntry` with Freighter.
  ///
  /// Freighter's `signAuthEntry` signs a `HashIdPreimage`, not an entry, so
  /// this method builds the preimage with the SDK's `buildPreimage` for the
  /// entry's arm: legacy ADDRESS -> ENVELOPE_TYPE_SOROBAN_AUTHORIZATION;
  /// ADDRESS_V2 (CAP-71, what Testnet protocol 29 simulates) ->
  /// ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS, which also binds the
  /// credential address. It then verifies the returned signature against the
  /// connected account and attaches it the way `SorobanAuthorizationEntry.sign`
  /// does.
  @override
  Future<String> signAuthEntry(String authorizationEntryXdr) async {
    final session = _requireSession();
    await _assertActiveSession(session);
    final entry = _parseAuthEntry(authorizationEntryXdr);
    final credentials = _requireOwnAddressCredentials(entry, session);

    final XdrHashIDPreimage preimage;
    try {
      preimage = entry.buildPreimage(Network.TESTNET);
    } catch (_) {
      throw const InvalidEnvelope('Cannot build the authorization preimage.');
    }
    final preimageStream = XdrDataOutputStream();
    XdrHashIDPreimage.encode(preimageStream, preimage);
    final preimageBytes = Uint8List.fromList(preimageStream.bytes);

    final answer = await _bridge.signAuthEntryPreimage(
      base64Encode(preimageBytes),
      stellarTestnetPassphrase,
      session.address,
    );
    final reportedSigner = answer.signerAddress;
    if (reportedSigner != null && reportedSigner != session.address) {
      throw const WalletAccountChanged(
        'Wallet signed the authorization entry with a different account.',
      );
    }
    final signature = _decodeSignature(answer.signature);
    final key = KeyPair.fromAccountId(session.address);
    if (!key.verify(Util.hash(preimageBytes), signature)) {
      throw const InvalidEnvelope(
        'Wallet signature does not verify for the connected account.',
      );
    }

    // Mirrors SorobanAuthorizationEntry.sign/_appendSignature in
    // stellar_flutter_sdk 3.8.0: a vec of {public_key, signature} maps, where
    // a void signature becomes a one-element vec. [credentials] is the arm's
    // own object, so the ADDRESS or ADDRESS_V2 arm is preserved.
    credentials.signature = XdrSCVal.forVec([
      ...?credentials.signature.vec,
      AccountEd25519Signature(key.xdrPublicKey, signature).toXdrSCVal(),
    ]);
    return entry.toBase64EncodedXdrString();
  }

  SorobanAuthorizationEntry _parseAuthEntry(String xdr) {
    final trimmed = xdr.trim();
    if (trimmed.isEmpty) {
      throw const InvalidEnvelope('Authorization entry XDR is empty.');
    }
    try {
      final entry = SorobanAuthorizationEntry.fromBase64EncodedXdr(trimmed);
      // Reject trailing bytes or non-canonical encodings.
      if (entry.toBase64EncodedXdrString() != trimmed) {
        throw const FormatException('non-canonical');
      }
      return entry;
    } catch (_) {
      throw const InvalidEnvelope('Authorization entry XDR is malformed.');
    }
  }

  /// Signs legacy ADDRESS and ADDRESS_V2 credentials for the connected G...
  /// account. Everything else is rejected before the wallet is prompted.
  /// Returns the arm's own credentials object, so mutating its signature
  /// updates the entry without changing the arm.
  SorobanAddressCredentials _requireOwnAddressCredentials(
    SorobanAuthorizationEntry entry,
    WalletSession session,
  ) {
    final credentials = switch (entry.credentials.arm) {
      XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_ADDRESS ||
      XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_ADDRESS_V2 =>
        entry.credentials.innerAddressCredentials,
      XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_SOURCE_ACCOUNT =>
        throw const InvalidEnvelope(
          'Source-account credentials are authorized by the transaction '
          'signature; there is no auth entry to sign.',
        ),
      _ => throw const UnsupportedAuthCredentials(
        'ADDRESS_WITH_DELEGATES credentials are not supported by this spike.',
      ),
    };
    if (credentials == null) {
      throw const InvalidEnvelope('Authorization entry has no credentials.');
    }
    final address = credentials.address;
    if (address.type != Address.TYPE_ACCOUNT ||
        address.accountId != session.address) {
      throw const PayloadAccountMismatch(
        'Authorization entry credentials belong to another address.',
      );
    }
    return credentials;
  }

  Uint8List _decodeSignature(String encoded) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } catch (_) {
      throw const InvalidEnvelope('Wallet returned a non-base64 signature.');
    }
    if (bytes.length != 64) {
      throw const InvalidEnvelope(
        'Wallet returned a signature that is not 64 bytes.',
      );
    }
    return bytes;
  }

  Future<void> _assertActiveSession(WalletSession expected) async {
    final active = await _bridge.currentSession();
    if (active.networkPassphrase != stellarTestnetPassphrase) {
      throw const WrongNetwork(
        'Wallet network changed; reconnect and try again.',
      );
    }
    if (active.address != expected.address) {
      throw const WalletAccountChanged(
        'Active Freighter account changed; reconnect and prepare a new payload.',
      );
    }
  }

  /// Rejects, before the wallet is prompted, any envelope whose transaction
  /// source or explicit operation source is not the connected account.
  /// Muxed (M...) sources are compared by their underlying G... account.
  void _assertSourceBinding(Transaction transaction, WalletSession session) {
    if (transaction.sourceAccount.ed25519AccountId != session.address) {
      throw const PayloadAccountMismatch(
        'Transaction source account is not the connected wallet account; '
        'prepare a new payload for this account.',
      );
    }
    for (final operation in transaction.operations) {
      final source = operation.sourceAccount;
      if (source != null && source.ed25519AccountId != session.address) {
        throw const PayloadAccountMismatch(
          'An operation source account is not the connected wallet account.',
        );
      }
    }
  }

  WalletSession _requireSession() =>
      _session ?? (throw const WalletUnavailable('Connect Freighter first.'));

  AbstractTransaction _parse(String xdr) {
    try {
      return AbstractTransaction.fromEnvelopeXdrString(xdr);
    } catch (_) {
      throw const InvalidEnvelope('Transaction envelope XDR is malformed.');
    }
  }
}
