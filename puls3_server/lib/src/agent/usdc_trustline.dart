import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import '../chain/chain_log.dart';
import '../ledger/classic_asset.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/network_id.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/strkey.dart';
import '../ledger/xdr_invoke_encoder.dart' show XdrWriter;
import 'stellar_agent_wallet_custody.dart';

/// Makes sure a custodied agent wallet can receive the USDC the escrow pays.
///
/// The USDC Stellar Asset Contract only credits an account that holds a
/// trustline to the classic asset; without one, escrow `complete` fails with
/// "trustline entry is missing for account".
abstract interface class TrustlineEnsurer {
  /// Adds the trustline of [account] when it has none. Returns `true` when a
  /// trustline was added and `false` when one already existed.
  ///
  /// Throws a [LedgerException] when the trustline could not be read, added
  /// or confirmed.
  Future<bool> ensure(StellarAddress account);
}

/// [TrustlineEnsurer] over Soroban RPC.
///
/// It reads the trustline with `getLedgerEntries` (one call when it exists),
/// otherwise submits a classic `ChangeTrust` with the account as source,
/// signed with its custodied key, and polls `getTransaction` until the
/// transaction is final.
final class RpcTrustlineEnsurer implements TrustlineEnsurer {
  RpcTrustlineEnsurer({
    required SorobanRpcClient rpc,
    required AgentEnvelopeSigner signer,
    required ClassicAsset asset,
    required String networkPassphrase,
    int feeStroops = 10000,
    Duration validity = const Duration(minutes: 5),
    Duration pollInterval = const Duration(seconds: 1),
    int maxPolls = 30,
    DateTime Function()? now,
  }) : _rpc = rpc,
       _signer = signer,
       _asset = asset,
       _networkId = networkIdOf(networkPassphrase),
       _fee = feeStroops,
       _validity = validity,
       _pollInterval = pollInterval,
       _maxPolls = maxPolls,
       _now = now ?? DateTime.now;

  final SorobanRpcClient _rpc;
  final AgentEnvelopeSigner _signer;
  final ClassicAsset _asset;
  final List<int> _networkId;
  final int _fee;
  final Duration _validity;
  final Duration _pollInterval;
  final int _maxPolls;
  final DateTime Function() _now;

  @override
  Future<bool> ensure(StellarAddress account) async {
    if (await _rpc.ledgerEntry(_trustlineKey(account)) != null) return false;
    final sequence = await _rpc.accountSequence(account);
    if (sequence == null) {
      throw const LedgerUnavailable('the agent wallet account does not exist');
    }
    final prepared = _changeTrust(account, sequence);
    final signed = await _signer.sign(prepared, account);
    final sent = await _rpc.sendTransaction(signed, prepared.hashHex);
    switch (sent.status) {
      case SendTransactionStatus.pending:
      case SendTransactionStatus.duplicate:
        break;
      case SendTransactionStatus.tryAgainLater:
      case SendTransactionStatus.error:
        throw LedgerUnavailable(
          'ChangeTrust was not accepted (${sent.status.name})',
        );
    }
    for (var poll = 0; poll < _maxPolls; poll++) {
      if (poll > 0) await Future<void>.delayed(_pollInterval);
      final tx = await _rpc.getTransaction(prepared.hashHex);
      switch (tx['status']) {
        case 'SUCCESS':
          return true;
        case 'FAILED':
          throw const LedgerUnavailable('ChangeTrust failed on chain');
      }
    }
    throw const LedgerUnavailable('ChangeTrust was not confirmed in time');
  }

  /// XDR `LedgerKey` TRUSTLINE of [account] for the asset.
  Uint8List _trustlineKey(StellarAddress account) {
    final key = XdrWriter()
      ..uint32(_ledgerEntryTypeTrustline)
      ..uint32(_publicKeyTypeEd25519)
      ..opaque(rawKey(account))
      ..raw(_asset.toXdr());
    return key.bytes;
  }

  /// An unsigned v1 envelope with one `ChangeTrust` to the asset at the
  /// maximum limit, valid for [_validity].
  PreparedEnvelope _changeTrust(StellarAddress account, int sequence) {
    final maxTime =
        _now().toUtc().add(_validity).millisecondsSinceEpoch ~/ 1000;
    final body = XdrWriter()
      ..uint32(_publicKeyTypeEd25519) // MuxedAccount KEY_TYPE_ED25519
      ..opaque(rawKey(account))
      ..uint32(_fee)
      ..int64(sequence + 1)
      ..uint32(_precondTime)
      ..uint64(0) // minTime
      ..uint64(maxTime)
      ..uint32(_memoNone)
      ..uint32(1) // one operation
      ..uint32(0) // no operation source account
      ..uint32(_changeTrustOperation)
      ..raw(_asset.toXdr())
      ..int64(_maxLimit)
      ..uint32(0); // no transaction extension
    final envelope = XdrWriter()
      ..uint32(_envelopeTypeTx)
      ..raw(body.bytes)
      ..uint32(0); // no signatures
    final bytes = envelope.bytes;
    final decoded =
        stellar.Envelope.fromXdr(bytes) as stellar.TransactionV1Envelope;
    return PreparedEnvelope(
      envelopeXdr: base64Encode(bytes),
      body: body.bytes,
      hash: Uint8List.fromList(
        stellar.TransactionSignaturePayload(
          networkId: _networkId,
          taggedTransaction: decoded.tx,
        ).txHash(),
      ),
    );
  }
}

/// Ensures the trustline of every wallet [wallets] lists, one at a time.
///
/// Logs one info line per trustline added and one warning per failure. It
/// never throws, so a startup backfill cannot crash the server.
Future<void> backfillTrustlines({
  required Future<List<StellarAddress>> Function() wallets,
  required TrustlineEnsurer ensurer,
  required ChainLog log,
}) async {
  final List<StellarAddress> accounts;
  try {
    accounts = await wallets();
  } on Object catch (e) {
    log(
      ChainLogLevel.warning,
      'USDC trustline backfill could not list wallets: ${e.runtimeType}',
    );
    return;
  }
  for (final account in accounts) {
    try {
      if (await ensurer.ensure(account)) {
        log(
          ChainLogLevel.info,
          'added the USDC trustline of agent wallet ${account.value}',
        );
      }
    } on Object catch (e) {
      final reason = e is LedgerException ? e.message : '${e.runtimeType}';
      log(
        ChainLogLevel.warning,
        'could not add the USDC trustline of agent wallet ${account.value}: '
        '$reason',
      );
    }
  }
}

// XDR discriminants, from Stellar-ledger-entries.x and Stellar-transaction.x.
const _ledgerEntryTypeTrustline = 1;
const _publicKeyTypeEd25519 = 0;
const _envelopeTypeTx = 2;
const _precondTime = 1;
const _memoNone = 0;
const _changeTrustOperation = 6;

/// INT64_MAX, the largest trustline limit.
const _maxLimit = 0x7fffffffffffffff;
