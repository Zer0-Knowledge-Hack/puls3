import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:stellar_dart/stellar_dart.dart';

/// Soroban RPC on testnet.
final sorobanTestnet = Uri.parse('https://soroban-testnet.stellar.org');

/// The part of an escrow `Job` a receipt is checked against.
///
/// `create_job` accepts a job only when `provider` is the identity
/// registry's wallet for `agent_id` at that moment, so the job itself binds
/// the agent id to the wallet it pays. A wallet changed later in the
/// registry does not change the job.
final class EscrowJob {
  const EscrowJob({
    required this.agentId,
    required this.provider,
    required this.state,
  });

  /// `JobState::Completed` in the escrow contract.
  static const completed = 3;

  final int agentId;
  final String provider;
  final int state;
}

/// Reads the job [jobId] of the escrow [escrow].
typedef JobLookup = Future<EscrowJob> Function(String escrow, String jobId);

/// The base64 `LedgerKey` of the escrow's persistent `DataKey::Job(jobId)`.
String jobLedgerKey(String escrow, String jobId) => LedgerKeyContractData(
  contract: ScAddressContract.fromBase32Address(escrow),
  key: ScValVec(value: [ScValSymbol('Job'), ScValU64(BigInt.parse(jobId))]),
  durability: ContractDataDurability.persistent,
).toVariantXDRBase64();

/// The job in a `getLedgerEntries` entry's `xdr` (a `LedgerEntryData`).
EscrowJob escrowJobFromEntry(String entryXdr) {
  final data = LedgerEntryData.fromStruct(
    XDRSerialization.deserialize(
      bytes: base64Decode(entryXdr),
      layout: LedgerEntryData.layout(),
    ),
  );
  if (data is! ContractDataEntry || data.val is! ScValMap) {
    throw const FormatException('the entry is not an escrow job');
  }
  final fields = {
    for (final e in (data.val as ScValMap).value ?? const <ScMapEntry>[])
      if (e.key is ScValSymbol) (e.key as ScValSymbol).value: e.value,
  };
  final agentId = fields['agent_id'];
  final provider = fields['provider'];
  final state = fields['state'];
  if (agentId is! ScValU32 || provider is! ScValAddress || state is! ScValU32) {
    throw const FormatException('the entry is not an escrow job');
  }
  return EscrowJob(
    agentId: agentId.value,
    provider: provider.value.address.baseAddress,
    state: state.value,
  );
}

/// Reads escrow jobs from Soroban RPC, with no transaction and no signer.
final class SorobanJobReader {
  SorobanJobReader(this._http, {Uri? rpc}) : _rpc = rpc ?? sorobanTestnet;

  final http.Client _http;
  final Uri _rpc;

  /// Throws [StateError] when the RPC has no live entry for the job: an
  /// unknown job, or one archived after its TTL ran out.
  Future<EscrowJob> job(String escrow, String jobId) async {
    final response = await _http
        .post(
          _rpc,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'getLedgerEntries',
            'params': {
              'keys': [jobLedgerKey(escrow, jobId)],
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Soroban RPC answered HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final entries = (body['result'] as Map?)?['entries'] as List?;
    if (entries == null || entries.isEmpty) {
      throw StateError('no live entry for job $jobId on $escrow');
    }
    return escrowJobFromEntry((entries.first as Map)['xdr'] as String);
  }
}
