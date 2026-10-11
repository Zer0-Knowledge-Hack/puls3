import 'dart:convert';
import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../wallet_port.dart';
import 'freighter_bridge.dart';

/// [WalletPort] over the Freighter browser extension (ADR-0003), ported from
/// the #70 spike with the #69 pre-prompt checks.
///
/// Before Freighter is ever prompted it verifies that the active account and
/// network are still the ones connected, that the XDR is canonical (no
/// trailing bytes), that the payload belongs to the connected account, and
/// that it is a kind this app signs. After signing it verifies that the
/// transaction body is unchanged and carries a valid new signature from the
/// connected account on Testnet.
final class FreighterWallet implements WalletPort {
  FreighterWallet(this._bridge);

  final FreighterBridge _bridge;
  FreighterSession? _session;

  @override
  String get name => 'Freighter';

  @override
  Uri? get installUrl => Uri.parse('https://www.freighter.app/');

  @override
  String? get address => _session?.address;

  @override
  String? get network => _session?.networkPassphrase;

  @override
  Future<String> connect() async {
    final session = await _bridge.connect();
    if (session.networkPassphrase != stellarTestnetPassphrase) {
      // Not kept: the app must not look connected on the wrong network.
      throw const WalletWrongNetwork();
    }
    _session = session;
    return session.address;
  }

  @override
  Future<void> disconnect() async {
    // Freighter has no programmatic disconnect; the app forgets the session.
    _session = null;
  }

  @override
  Future<String> signTransaction(String unsignedXdr) async {
    final session = _requireSession();
    await _assertActiveSession(session);
    final unsigned = _parse(unsignedXdr, canonical: true);
    // #69 (R3-001): fee-bump and other envelopes are refused before the
    // prompt, so the wallet never shows another payer's payload.
    if (unsigned is! Transaction) {
      throw const WalletInvalidPayload(
        'Only standard transaction envelopes can be signed.',
      );
    }
    _assertSourceBinding(unsigned, session);

    return _signAndVerify(unsigned, unsignedXdr, session);
  }

  /// SEP-10 sign-in (#136). The challenge source is the server, so the
  /// payment rule of [signTransaction] (every source is the connected
  /// account) does not apply. Instead it must be a challenge that can only
  /// prove ownership; [assertSep10Challenge] lists the checks.
  @override
  Future<String> signChallenge(SignInChallenge challenge) async {
    final session = _requireSession();
    await _assertActiveSession(session);
    if (challenge.networkPassphrase != stellarTestnetPassphrase) {
      throw const WalletWrongNetwork();
    }
    final unsigned = _parse(challenge.transactionXdr, canonical: true);
    if (unsigned is! Transaction) {
      throw const WalletInvalidPayload(
        'A sign-in challenge must be a transaction.',
      );
    }
    assertSep10Challenge(
      unsigned,
      account: session.address,
      serverSigningKey: challenge.serverSigningKey,
      homeDomain: challenge.homeDomain,
      now: DateTime.now(),
    );
    return _signAndVerify(unsigned, challenge.transactionXdr, session);
  }

  /// Asks Freighter to sign [unsigned], then verifies that the body is
  /// unchanged and that a new signature from the connected account covers it
  /// on Testnet.
  Future<String> _signAndVerify(
    Transaction unsigned,
    String unsignedXdr,
    FreighterSession session,
  ) async {
    final signedXdr = await _bridge.signTransaction(
      unsignedXdr,
      stellarTestnetPassphrase,
      session.address,
    );
    final signed = _parse(signedXdr);
    if (signed is! Transaction) {
      throw const WalletInvalidPayload('The wallet returned another envelope.');
    }
    if (unsigned.toXdrBase64() != signed.toXdrBase64()) {
      throw const WalletInvalidPayload('The wallet changed the transaction.');
    }
    final before = unsigned.signatures
        .map((s) => s.toBase64EncodedXdrString())
        .toList();
    final added = signed.signatures.where((s) {
      final encoded = s.toBase64EncodedXdrString();
      return !before.remove(encoded);
    }).toList();
    if (added.isEmpty) {
      throw const WalletInvalidPayload('The wallet did not add a signature.');
    }
    final key = KeyPair.fromAccountId(session.address);
    final hash = signed.hash(Network.TESTNET);
    if (!added.any((s) => key.verify(hash, s.signature.signature))) {
      throw const WalletInvalidPayload(
        'The signature is not from the connected account.',
      );
    }
    return signedXdr;
  }

  /// Freighter's `signAuthEntry` signs a `HashIdPreimage`, not an entry, so
  /// this builds the preimage for the entry's arm (legacy ADDRESS or
  /// CAP-71 ADDRESS_V2), verifies the returned signature against the
  /// connected account and attaches it like `SorobanAuthorizationEntry.sign`.
  @override
  Future<String> signAuthEntry(String entryXdr) async {
    final session = _requireSession();
    await _assertActiveSession(session);
    final entry = _parseAuthEntry(entryXdr);
    final credentials = _requireOwnAddressCredentials(entry, session);
    // #69: an unset expiration would make the signature unusable on chain.
    if (credentials.signatureExpirationLedger == 0) {
      throw const WalletInvalidPayload(
        'The authorization entry has no expiration ledger.',
      );
    }

    final XdrHashIDPreimage preimage;
    try {
      preimage = entry.buildPreimage(Network.TESTNET);
    } on Object {
      throw const WalletInvalidPayload(
        'Cannot build the authorization preimage.',
      );
    }
    final stream = XdrDataOutputStream();
    XdrHashIDPreimage.encode(stream, preimage);
    final preimageBytes = Uint8List.fromList(stream.bytes);

    final answer = await _bridge.signAuthEntryPreimage(
      base64Encode(preimageBytes),
      stellarTestnetPassphrase,
      session.address,
    );
    final signer = answer.signerAddress;
    if (signer != null && signer != session.address) {
      throw const WalletAccountChanged();
    }
    final signature = _decodeSignature(answer.signature);
    final key = KeyPair.fromAccountId(session.address);
    if (!key.verify(Util.hash(preimageBytes), signature)) {
      throw const WalletInvalidPayload(
        'The signature is not from the connected account.',
      );
    }
    credentials.signature = XdrSCVal.forVec([
      ...?credentials.signature.vec,
      AccountEd25519Signature(key.xdrPublicKey, signature).toXdrSCVal(),
    ]);
    return entry.toBase64EncodedXdrString();
  }

  SorobanAuthorizationEntry _parseAuthEntry(String xdr) {
    final trimmed = xdr.trim();
    if (trimmed.isEmpty) {
      throw const WalletInvalidPayload('The authorization entry is empty.');
    }
    try {
      final entry = SorobanAuthorizationEntry.fromBase64EncodedXdr(trimmed);
      // Rejects trailing bytes and non-canonical encodings.
      if (entry.toBase64EncodedXdrString() != trimmed) {
        throw const FormatException('non-canonical');
      }
      return entry;
    } on Object {
      throw const WalletInvalidPayload(
        'The authorization entry XDR is malformed.',
      );
    }
  }

  /// Legacy ADDRESS and ADDRESS_V2 credentials of the connected G… account
  /// are signed; everything else is refused before the prompt.
  SorobanAddressCredentials _requireOwnAddressCredentials(
    SorobanAuthorizationEntry entry,
    FreighterSession session,
  ) {
    final credentials = switch (entry.credentials.arm) {
      XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_ADDRESS ||
      XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_ADDRESS_V2 =>
        entry.credentials.innerAddressCredentials,
      XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_SOURCE_ACCOUNT =>
        throw const WalletInvalidPayload(
          'Source-account credentials need no entry signature.',
        ),
      _ => throw const WalletInvalidPayload(
        'Delegated credentials are not supported.',
      ),
    };
    if (credentials == null) {
      throw const WalletInvalidPayload(
        'The authorization entry has no credentials.',
      );
    }
    final address = credentials.address;
    if (address.type != Address.TYPE_ACCOUNT ||
        address.accountId != session.address) {
      throw const WalletInvalidPayload(
        'The authorization entry belongs to another address.',
      );
    }
    return credentials;
  }

  Uint8List _decodeSignature(String encoded) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      throw const WalletInvalidPayload('The wallet returned a bad signature.');
    }
    if (bytes.length != 64) {
      throw const WalletInvalidPayload('The wallet returned a bad signature.');
    }
    return bytes;
  }

  /// The account or network may change in Freighter after connecting.
  Future<void> _assertActiveSession(FreighterSession expected) async {
    final active = await _bridge.currentSession();
    if (active.networkPassphrase != stellarTestnetPassphrase) {
      throw const WalletWrongNetwork();
    }
    if (active.address != expected.address) {
      throw const WalletAccountChanged();
    }
  }

  /// The transaction source and every explicit operation source must be the
  /// connected account (muxed M… sources compare by their G… account).
  void _assertSourceBinding(Transaction tx, FreighterSession session) {
    if (tx.sourceAccount.ed25519AccountId != session.address) {
      throw const WalletInvalidPayload(
        'The transaction was prepared for another account.',
      );
    }
    for (final operation in tx.operations) {
      final source = operation.sourceAccount;
      if (source != null && source.ed25519AccountId != session.address) {
        throw const WalletInvalidPayload(
          'An operation is for another account.',
        );
      }
    }
  }

  FreighterSession _requireSession() =>
      _session ?? (throw const WalletUnavailable());

  /// With [canonical], the XDR must re-encode to the same base64, so trailing
  /// bytes or non-canonical encodings never reach the wallet.
  AbstractTransaction _parse(String xdr, {bool canonical = false}) {
    try {
      final parsed = AbstractTransaction.fromEnvelopeXdrString(xdr);
      if (canonical && parsed.toEnvelopeXdrBase64() != xdr) {
        throw const FormatException('non-canonical');
      }
      return parsed;
    } on Object {
      throw const WalletInvalidPayload('The transaction XDR is malformed.');
    }
  }
}

/// Throws [WalletInvalidPayload] unless [tx] is a SEP-10 challenge that only
/// lets [account] prove it owns its key (#136, SEP-10 "Challenge"):
///
/// - sequence number 0, so it can never be submitted;
/// - every operation is `manage_data`;
/// - the first one is `<home domain> auth` with [account] as its source;
/// - the transaction source is not [account], and every other operation's
///   source is the transaction source (the server);
/// - time bounds are set and include [now];
/// - when known, the source is [serverSigningKey] and the first operation is
///   `<homeDomain> auth`.
void assertSep10Challenge(
  Transaction tx, {
  required String account,
  required DateTime now,
  String? serverSigningKey,
  String? homeDomain,
}) {
  Never refuse(String reason) => throw WalletInvalidPayload(reason);

  final server = tx.sourceAccount.ed25519AccountId;
  if (tx.sequenceNumber != BigInt.zero) {
    refuse('A sign-in challenge must have sequence number 0.');
  }
  if (server == account) {
    refuse('A sign-in challenge must come from the server, not your account.');
  }
  if (serverSigningKey != null && server != serverSigningKey) {
    refuse('The sign-in challenge is not from the puls3 server.');
  }
  final operations = tx.operations;
  if (operations.isEmpty) refuse('The sign-in challenge has no operation.');
  for (final (index, operation) in operations.indexed) {
    if (operation is! ManageDataOperation) {
      refuse('A sign-in challenge may only contain manage_data operations.');
    }
    final source = operation.sourceAccount?.ed25519AccountId;
    if (index == 0) {
      if (source != account) {
        refuse('The sign-in challenge is not for your account.');
      }
      final name = operation.name;
      final expected = homeDomain == null ? null : '$homeDomain auth';
      if (expected != null ? name != expected : !name.endsWith(' auth')) {
        refuse('The sign-in challenge is not for this server.');
      }
    } else if (source != server) {
      refuse('A sign-in challenge operation is for another account.');
    }
  }
  final bounds = tx.preconditions?.timeBounds;
  if (bounds == null || bounds.maxTime == 0) {
    refuse('The sign-in challenge has no expiry.');
  }
  final seconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
  if (seconds < bounds.minTime || seconds > bounds.maxTime) {
    refuse('The sign-in challenge has expired. Try again.');
  }
}
