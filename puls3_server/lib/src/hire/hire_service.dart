import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../agent/agent_catalog_service.dart';
import '../agent/registry_reader.dart';
import '../generated/protocol.dart';
import '../ledger/ledger_errors.dart';
import 'escrow_preparation_store.dart';
import 'escrow_relay_service.dart';
import 'hire_lifecycle_store.dart';
import 'hire_relay_config.dart';

/// Creates hires (ADR-0005). It never moves funds or signs: it stores the
/// hire and hands the consumer's wallet the unsigned `create_job` the relay
/// prepared. The payment is verified by the escrow effects
/// (`HireEscrowEffects`) when the chain tracker confirms a `fund` submission.
class HireService {
  HireService({
    required this.hires,
    required this.preparations,
    required this.relay,
    required this.registry,
    required this.catalog,
    required this.config,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final HireLifecycleStore hires;
  final EscrowPreparationStore preparations;
  final EscrowRelayService relay;
  final RegistryReader registry;
  final AgentCatalogService catalog;
  final HireRelayConfig config;
  final DateTime Function() _now;

  /// Creates the hire of [requestId], or returns the one it already
  /// created, with the `create_job` envelope to sign.
  ///
  /// [requestId] is unique per [consumer]. Repeating it with the same
  /// [agentId] and [input] returns the existing hire; with anything else it
  /// is `IdempotencyKeyReused`. The envelope is prepared first and the hire
  /// and its preparation are stored in one transaction, so a failed
  /// preparation leaves no hire behind. The caller has already checked that
  /// [consumer] is the session wallet.
  Future<CreateHireResult> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  }) async {
    final StellarAddress consumerAddress;
    try {
      consumerAddress = StellarAddress.parse(consumer);
    } on InvalidStellarAddress catch (e) {
      throw HireRequestInvalid(
        message: 'Invalid consumer address: $consumer ($e)',
      );
    }
    if (requestId.trim().isEmpty) {
      throw HireRequestInvalid(message: 'requestId must not be blank.');
    }

    final existing = await hires.findHireByRequest(consumer, requestId);
    if (existing != null) {
      return _repeat(existing, consumerAddress, agentId, input);
    }

    final durationSeconds = config.jobDurationSeconds;

    final AgentSummary? agent;
    try {
      agent = (await catalog.list())
          .where((a) => a.registryId == agentId)
          .firstOrNull;
    } on AgentCatalogUnavailable catch (e) {
      throw HireLedgerUnavailable(message: e.message);
    } on LedgerException catch (e) {
      throw HireLedgerUnavailable(message: e.message);
    }
    final agentWallet = agent?.wallet;
    if (agent == null || agentWallet == null) {
      throw AgentUnavailable(agentId: agentId);
    }

    final Uint8List? rawManifest;
    try {
      rawManifest = await registry.agentMetadata(
        AgentId(agentId),
        'puls3.manifestVersion',
      );
    } on LedgerException catch (e) {
      throw HireLedgerUnavailable(message: e.message);
    }
    final manifestVersion = _manifestVersion(rawManifest, agentId);

    final nowSec = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expiredAt = nowSec + durationSeconds;
    final price = agent.priceUsdcStroops;
    final draft = await relay.draftCreateJob(
      wallet: consumerAddress,
      provider: StellarAddress.parse(agentWallet),
      agentId: agentId,
      price: price,
      expiredAt: expiredAt,
    );

    try {
      final (hire, preparation) = await preparations.inTransaction((
        transaction,
      ) async {
        final hire = await hires.insertHire(
          NewHire(
            consumer: consumer,
            agentId: agentId,
            price: price,
            manifestVersion: manifestVersion,
            expiredAt: expiredAt,
            requestId: requestId,
            input: input,
          ),
          transaction: transaction,
        );
        final stored = await preparations.insert(
          relay.newPreparation(draft, hire.id),
          transaction: transaction,
        );
        return (hire, stored);
      });
      return CreateHireResult(
        hire: hire.toProtocol(),
        preparedCreateJob: relay.preparedOf(preparation),
      );
    } on HireRequestConflict {
      // A concurrent call with the same request won the insert.
      final winner = await hires.findHireByRequest(consumer, requestId);
      if (winner == null) rethrow;
      return _repeat(winner, consumerAddress, agentId, input);
    }
  }

  /// The answer to a request that already created [existing].
  Future<CreateHireResult> _repeat(
    HireRow existing,
    StellarAddress consumer,
    int agentId,
    String input,
  ) async {
    if (existing.agentId != agentId || existing.input != input) {
      throw Puls3ApiException(code: 'IdempotencyKeyReused');
    }
    return CreateHireResult(
      hire: existing.toProtocol(),
      preparedCreateJob: await relay.currentCreateJob(existing, consumer),
    );
  }

  int _manifestVersion(Uint8List? raw, int agentId) {
    if (raw == null || raw.isEmpty) {
      throw HireRequestInvalid(
        message: 'Agent $agentId has no puls3.manifestVersion metadata.',
      );
    }
    try {
      final text = utf8.decode(raw, allowMalformed: false).trim();
      final parsed = int.tryParse(text);
      if (parsed == null || parsed < 1) {
        throw HireRequestInvalid(
          message: 'Agent $agentId has invalid manifest version: $text',
        );
      }
      return parsed;
    } on FormatException {
      throw HireRequestInvalid(
        message: 'Agent $agentId has invalid manifest version encoding.',
      );
    }
  }
}
