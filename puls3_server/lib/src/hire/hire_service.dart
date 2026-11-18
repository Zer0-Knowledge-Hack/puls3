import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../agent/agent_catalog_service.dart';
import '../agent/custodied_wallets.dart';
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
    required this.custody,
    required this.config,
    this.unpublished = noStudioAgents,
    AgentSummaryLookup? agentOf,
    DateTime Function()? now,
  }) : _agentOf = agentOf,
       _now = now ?? DateTime.now;

  final HireLifecycleStore hires;
  final EscrowPreparationStore preparations;
  final EscrowRelayService relay;
  final RegistryReader registry;
  final AgentCatalogService catalog;

  /// The one custody rule: which payment wallets the server can sign for.
  final CustodyLookup custody;

  /// Which agents are Studio agents without a published version.
  final PublicationLookup unpublished;
  final HireRelayConfig config;
  final DateTime Function() _now;

  /// Finds the hired agent by registry id. The wiring passes the catalog
  /// index (`hireAgentLookup`); without it, the whole [catalog] is read.
  final AgentSummaryLookup? _agentOf;

  Future<AgentSummary?> _agent(int registryId) async {
    final lookup = _agentOf;
    if (lookup != null) return lookup(registryId);
    return (await catalog.list())
        .where((a) => a.registryId == registryId)
        .firstOrNull;
  }

  /// Creates the hire of [requestId], or returns the one it already
  /// created, with the `create_job` envelope to sign.
  ///
  /// [requestId] is unique per [consumer]. Repeating it with the same
  /// [agentId] and [input] returns the existing hire; with anything else it
  /// is `IdempotencyKeyReused`. The envelope is prepared first and the hire
  /// and its preparation are stored in one transaction, so a failed
  /// preparation leaves no hire behind. The caller has already checked that
  /// [consumer] is the session wallet.
  ///
  /// An agent whose payment wallet is not custodied is refused with
  /// [AgentCannotDeliver] before anything is stored: the server could never
  /// sign its `submit`, so the payment would sit in the escrow until expiry.
  /// A Studio agent whose deploy is not `active` (published) is refused the
  /// same way: it has no version the server could run.
  ///
  /// [subcontractReserve] (USDC stroops, default 0) is the cap the consumer
  /// funds beside the price for child jobs (ADR-0011 D1): a hire with one is
  /// later funded with `fund_with_reserve`, a hire without one with `fund`
  /// as before. It must be 0 or more and at most the platform ceiling, else
  /// [HireRequestInvalid]. [allowRelatedParty] (default true) is the
  /// consumer's related-party choice (D10). Both are part of the request:
  /// a retry with other values is `IdempotencyKeyReused`.
  Future<CreateHireResult> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
    int? subcontractReserve,
    bool? allowRelatedParty,
  }) async {
    final reserve = subcontractReserve ?? 0;
    final relatedParty = allowRelatedParty ?? true;
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
    _checkReserve(reserve);

    final existing = await hires.findHireByRequest(consumer, requestId);
    if (existing != null) {
      return _repeat(
        existing,
        consumerAddress,
        agentId,
        input,
        reserve,
        relatedParty,
      );
    }

    final durationSeconds = config.jobDurationSeconds;

    final AgentSummary? agent;
    final StellarAddress? liveWallet;
    try {
      agent = await _agent(agentId);
      // The payee is read live, never from the catalog or its index: a stale
      // wallet would make a job the funding check rejects, and the payment
      // would sit in the escrow until expiry.
      liveWallet = agent == null
          ? null
          : await registry.agentWallet(AgentId(agentId));
    } on AgentCatalogUnavailable catch (e) {
      throw HireLedgerUnavailable(message: e.message);
    } on LedgerException catch (e) {
      throw HireLedgerUnavailable(message: e.message);
    }
    if (agent == null || liveWallet == null) {
      throw AgentUnavailable(agentId: agentId);
    }
    final agentWallet = liveWallet.value;
    final custodied = await custody({agentWallet});
    final deliverable =
        custodied.contains(agentWallet) &&
        canDeliver(
          registryId: agentId,
          wallet: agentWallet,
          custodied: custodied,
          unpublished: await unpublished({agentId}),
        );
    if (!deliverable) {
      // The server would never send this agent's `submit`, so the escrow would
      // hold the consumer's payment until the job expires (#276).
      throw AgentCannotDeliver(agentId: agentId);
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
            subcontractReserve: reserve,
            allowRelatedParty: relatedParty,
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
      return _repeat(
        winner,
        consumerAddress,
        agentId,
        input,
        reserve,
        relatedParty,
      );
    }
  }

  /// Refuses a negative reserve, or one above the platform ceiling. The
  /// ceiling is read only for a reserve above 0.
  void _checkReserve(int reserve) {
    if (reserve < 0) {
      throw HireRequestInvalid(
        message: 'subcontractReserve must not be negative.',
      );
    }
    if (reserve == 0) return;
    final ceiling = config.subcontractReserveMaxStroops;
    if (reserve > ceiling) {
      throw HireRequestInvalid(
        message:
            'subcontractReserve $reserve is above the platform ceiling '
            '$ceiling.',
      );
    }
  }

  /// The answer to a request that already created [existing].
  Future<CreateHireResult> _repeat(
    HireRow existing,
    StellarAddress consumer,
    int agentId,
    String input,
    int reserve,
    bool allowRelatedParty,
  ) async {
    if (existing.agentId != agentId ||
        existing.input != input ||
        existing.subcontractReserve != reserve ||
        existing.allowRelatedParty != allowRelatedParty) {
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
