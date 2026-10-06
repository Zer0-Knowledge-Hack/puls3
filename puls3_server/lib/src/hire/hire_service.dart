import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import '../agent/agent_catalog_service.dart';
import '../agent/registry_reader.dart';
import '../generated/protocol.dart';
import '../ledger/ledger_errors.dart';
import 'hire_escrow_effects.dart';

/// Creates hires (ADR-0005). The payment is verified by the escrow effects
/// ([HireEscrowEffects]) when the chain tracker confirms a `fund` submission.
class HireService {
  HireService({
    required this.repo,
    required this.registry,
    required this.catalog,
    Map<String, String>? environment,
    DateTime Function()? now,
  }) : _environment = environment ?? Platform.environment,
       _now = now ?? DateTime.now;

  final HireRepository repo;
  final RegistryReader registry;
  final AgentCatalogService catalog;
  final Map<String, String> _environment;
  final DateTime Function() _now;

  /// Creates a requested hire. It has no endpoint yet: payments go through the
  /// server relay (Decision A in `docs/architecture/api.md`).
  Future<HireView> createHire({
    required int agentId,
    required String consumer,
  }) async {
    final StellarAddress consumerAddress;
    try {
      consumerAddress = StellarAddress.parse(consumer);
    } on InvalidStellarAddress catch (e) {
      throw HireRequestInvalid(
        message: 'Invalid consumer address: $consumer ($e)',
      );
    }

    final durationSeconds = _durationSeconds();

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
    if (agent == null || agent.wallet == null) {
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

    final hire = await repo.create(
      agentId: AgentId(agentId),
      consumer: consumerAddress,
      price: UsdcAmount.stroops(agent.priceUsdcStroops),
      manifestVersion: manifestVersion,
      expiredAt: expiredAt,
    );

    return HireView(
      hireId: hire.id.value,
      agentRegistryId: hire.agentId.value,
      consumer: hire.consumer.value,
      priceStroops: hire.price.stroops,
      status: hire.status.name,
    );
  }

  int _durationSeconds() {
    final raw = _environment['PULS3_HIRE_JOB_DURATION_SECONDS'];
    if (raw == null || raw.isEmpty) {
      throw HireConfigurationMissing(
        setting: 'PULS3_HIRE_JOB_DURATION_SECONDS',
      );
    }
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      throw HireConfigurationMissing(
        setting: 'PULS3_HIRE_JOB_DURATION_SECONDS',
      );
    }
    return parsed;
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
