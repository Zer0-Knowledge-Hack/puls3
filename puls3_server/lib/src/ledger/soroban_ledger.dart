/// Read-only access to the Stellar chain over Soroban JSON-RPC.
///
/// [SorobanLedger] implements the domain `LedgerPort` and adds registry and
/// escrow reads. It only calls `simulateTransaction` (unsigned envelopes) and
/// `getTransaction`; it never signs or submits a transaction. Submission goes
/// through `SorobanRpcClient.sendTransaction`, outside this read adapter.
///
/// Configuration comes from `PULS3_STELLAR_*` environment variables, see
/// `StellarConfig.fromEnvironment`: `PULS3_STELLAR_RPC_URL`,
/// `PULS3_STELLAR_NETWORK_PASSPHRASE`, `PULS3_STELLAR_USDC_SAC`,
/// `PULS3_STELLAR_IDENTITY_REGISTRY`, `PULS3_STELLAR_ESCROW` and
/// `PULS3_STELLAR_SIMULATION_SOURCE`. Each one that is unset falls back to the
/// testnet value.
///
/// Retention: a public RPC node keeps about 7 days of transactions (the
/// `oldestLedger` field of `getTransaction` shows the limit). `findPayment`
/// returns `null` for a payment older than that, exactly as for an unknown
/// hash. Verify a payment soon after it is made, or keep the verified result.
library;

import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import '../agent/registry_reader.dart';
import 'contract_reader.dart';
import 'escrow_job.dart';
import 'ledger_errors.dart';
import 'sc_val_json.dart';
import 'soroban_rpc_client.dart';
import 'stellar_config.dart';
import 'transfer_event_parser.dart';
import 'xdr_invoke_encoder.dart';

/// Registry `UriNotSet`: the agent exists but has no metadata uri.
const _registryUriNotSet = 2;

/// Registry `AgentNotFound`: there is no agent with that id.
const _registryAgentNotFound = 3;

/// Escrow `JobNotFound`: there is no job with that id.
const _escrowJobNotFound = 1;

/// Reads the Stellar chain through Soroban RPC. It never signs or submits,
/// although the [SorobanRpcClient] it uses can submit.
///
/// Contract reads are simulations of unsigned envelopes. A result of `null`
/// means the chain says "not there"; an infrastructure problem or a response
/// the adapter cannot read is a [LedgerException] instead.
final class SorobanLedger
    implements
        LedgerPort,
        RegistryReader,
        EscrowJobReader,
        AgentOwnerReader,
        EscrowExpiryReader {
  SorobanLedger(this._rpc, this._config)
    : _reader = ContractReader(_rpc, source: _config.simulationSource);

  final SorobanRpcClient _rpc;
  final StellarConfig _config;
  final ContractReader _reader;

  Future<Object?> _read(
    StellarAddress contract,
    String function,
    List<ScArg> args, {
    Set<int> absentErrors = const {},
  }) => _reader.read(contract, function, args, absentErrors: absentErrors);

  /// Registry `agent_exists`.
  Future<bool> agentExists(AgentId id) async => readBool(
    await _read(_config.identityRegistry, 'agent_exists', [
      ScArg.u32(id.value),
    ]),
  );

  /// Registry `owner_of`: who registered [agent], or `null` when there is no
  /// such agent.
  @override
  Future<StellarAddress?> ownerOf(AgentId agent) async {
    final value = await _read(
      _config.identityRegistry,
      'owner_of',
      [ScArg.u32(agent.value)],
      absentErrors: const {_registryAgentNotFound},
    );
    return value == null ? null : readAddress(value);
  }

  /// Registry `agent_uri`, or `null` when the agent has no uri.
  Future<String?> agentUri(AgentId id) async {
    final value = await _read(
      _config.identityRegistry,
      'agent_uri',
      [ScArg.u32(id.value)],
      absentErrors: const {_registryUriNotSet},
    );
    return value == null ? null : readOptional(value, readString);
  }

  /// Registry `total_agents`: how many agents were ever registered.
  @override
  Future<int> totalAgents() async =>
      readU32(await _read(_config.identityRegistry, 'total_agents', const []));

  /// Registry `get_metadata`, or `null` when the agent has no value for [key].
  ///
  /// The contract returns `Option<Bytes>` and never fails for an absent key or
  /// an unknown agent. [key] is sent as an ScVal string.
  @override
  Future<Uint8List?> agentMetadata(AgentId id, String key) async {
    final value = await _read(_config.identityRegistry, 'get_metadata', [
      ScArg.u32(id.value),
      ScArg.string(key),
    ]);
    return readOptional(value, readBytes);
  }

  @override
  Future<StellarAddress?> agentWallet(AgentId agent) async {
    final value = await _read(_config.identityRegistry, 'get_agent_wallet', [
      ScArg.u32(agent.value),
    ]);
    return readOptional(value, readAddress);
  }

  /// Escrow `get_job`, or `null` when the job does not exist.
  @override
  Future<EscrowJob?> escrowJob(int jobId) async {
    final value = await _read(
      _config.escrow,
      'get_job',
      [ScArg.u64(jobId)],
      absentErrors: const {_escrowJobNotFound},
    );
    return value == null ? null : readOptional(value, decodeEscrowJob);
  }

  /// Escrow `is_expired`. This adapter only simulates the view; it does not
  /// submit `release` or `claim_refund`.
  @override
  Future<bool> isExpired(int jobId) async => readBool(
    await _read(_config.escrow, 'is_expired', [ScArg.u64(jobId)]),
  );

  @override
  Future<Payment?> findPayment(TransactionHash transaction) async {
    final result = await _rpc.getTransaction(transaction.value);
    return firstUsdcPayment(
      result,
      transaction: transaction,
      usdcSac: _config.usdcSac,
    );
  }
}
