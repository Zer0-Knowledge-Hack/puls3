import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/registry_reader.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';

class FakeHireRepository implements HireRepository {
  final Map<int, Hire> hires = {};
  final Map<int, Payment> payments = {};
  final Map<int, int> jobIds = {};
  final Map<int, int> expiredAtByHire = {};
  int _nextId = 1;

  int recordPaymentCalls = 0;

  @override
  Future<Hire> create({
    required AgentId agentId,
    required StellarAddress consumer,
    required UsdcAmount price,
    required int manifestVersion,
    required int expiredAt,
  }) async {
    final hire = Hire(
      id: HireId(_nextId++),
      agentId: agentId,
      consumer: consumer,
      price: price,
      manifestVersion: manifestVersion,
    );
    hires[hire.id.value] = hire;
    expiredAtByHire[hire.id.value] = expiredAt;
    return hire;
  }

  @override
  Future<Hire?> findById(HireId id) async => hires[id.value];

  @override
  Future<int?> preparedExpiry(HireId id) async => expiredAtByHire[id.value];

  @override
  Future<Hire> recordPayment(Hire paid, Payment payment, int jobId) async {
    recordPaymentCalls++;
    final existing = payments[paid.id.value];
    if (existing != null) {
      if (existing.transaction == payment.transaction) return paid;
      throw const HirePaymentConflict(HirePaymentIndex.hireId);
    }
    for (final p in payments.values) {
      if (p.transaction == payment.transaction) {
        throw const HirePaymentConflict(HirePaymentIndex.transactionHash);
      }
    }
    if (jobIds.values.contains(jobId)) {
      throw const HirePaymentConflict(HirePaymentIndex.jobId);
    }
    payments[paid.id.value] = payment;
    jobIds[paid.id.value] = jobId;
    hires[paid.id.value] = paid;
    return paid;
  }
}

class FakeLedger implements LedgerPort, RegistryReader, EscrowJobReader {
  final Map<int, StellarAddress> wallets = {};
  Exception? walletError;
  final Map<int, Map<String, Uint8List>> metadata = {};
  Exception? metadataError;

  final Map<int, EscrowJob> jobs = {};
  Exception? jobError;

  @override
  Future<EscrowJob?> escrowJob(int jobId) async {
    if (jobError != null) throw jobError!;
    return jobs[jobId];
  }

  @override
  Future<Payment?> findPayment(TransactionHash transaction) =>
      throw UnimplementedError('the hire flow does not read payments');

  @override
  Future<StellarAddress?> agentWallet(AgentId agent) async {
    if (walletError != null) throw walletError!;
    return wallets[agent.value];
  }

  @override
  Future<Uint8List?> agentMetadata(AgentId id, String key) async {
    if (metadataError != null) throw metadataError!;
    return metadata[id.value]?[key];
  }

  @override
  Future<int> totalAgents() async {
    if (wallets.isEmpty && metadata.isEmpty) return 0;
    final maxWallet = wallets.isEmpty
        ? 0
        : wallets.keys.reduce((a, b) => a > b ? a : b);
    final maxMeta = metadata.isEmpty
        ? 0
        : metadata.keys.reduce((a, b) => a > b ? a : b);
    return (maxWallet > maxMeta ? maxWallet : maxMeta) + 1;
  }
}
