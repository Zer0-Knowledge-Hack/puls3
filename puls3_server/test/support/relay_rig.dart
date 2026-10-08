import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/escrow_relay_service.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import '../unit/hire/hire_test_fakes.dart';
import 'fake_chain_accounts.dart';
import 'fake_envelope_codec.dart';
import 'fake_submission_ledger.dart';
import 'in_memory_chain_submission_store.dart';
import 'in_memory_escrow_preparation_store.dart';
import 'in_memory_hire_lifecycle_store.dart';

const alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const agentWallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const stranger = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';

/// Price of every hire the rig creates, in USDC stroops.
const price = 5000000;

/// Seconds of the preparation window, the job duration and the fee the rig
/// configures.
const validitySeconds = 300;
const jobDurationSeconds = 86400;
const platformFeeBps = 250;
const inclusionFee = 100;

/// The environment of a fully configured relay.
Map<String, String> relayEnvironment() => {
  'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS': '$validitySeconds',
  'PULS3_STELLAR_INCLUSION_FEE_STROOPS': '$inclusionFee',
  'PULS3_PLATFORM_FEE_BPS': '$platformFeeBps',
  'PULS3_HIRE_JOB_DURATION_SECONDS': '$jobDurationSeconds',
};

/// An [EscrowRelayService] on in-memory stores and fake chain ports, with a
/// clock the test moves.
final class RelayRig {
  RelayRig({
    Map<String, String>? environment,
    InMemoryHireLifecycleStore? hires,
  }) : _environment = environment ?? relayEnvironment(),
       hires = hires ?? InMemoryHireLifecycleStore() {
    ledger.wallets[7] = StellarAddress.parse(agentWallet);
    service = build();
  }

  final Map<String, String> _environment;

  /// A service over the rig's stores and fakes. [submissions] and [sender]
  /// replace the rig's own to inject a fault, and [codec] and [agents] to
  /// compose the real codec or a failing catalog.
  EscrowRelayService build({
    ChainSubmissionStore? submissions,
    SubmissionLedger? sender,
    EnvelopeCodec? codec,
    AgentSummaryLookup? agents,
  }) => EscrowRelayService(
    preparations: preparations,
    submissions: submissions ?? this.submissions,
    hires: hires,
    accounts: accounts,
    codec: codec ?? this.codec,
    sender: sender ?? this.sender,
    agentWallets: ledger,
    agents: agents ?? (id) async => id == 7 ? agentSummary : null,
    stellar: StellarConfig.testnet,
    config: HireRelayConfig(_environment),
    now: () => clock,
    newPreparationId: () => 'prep-${++_serial}',
  );

  /// The service clock; tests assign to move time.
  DateTime clock = DateTime.utc(2026, 10, 7, 12);

  final preparations = InMemoryEscrowPreparationStore();
  late final ChainSubmissionStore submissions = InMemoryChainSubmissionStore(
    now: () => clock,
  );
  final InMemoryHireLifecycleStore hires;
  final accounts = FakeChainAccounts();
  final codec = FakeEnvelopeCodec();
  final sender = FakeSubmissionLedger();
  final ledger = FakeLedger();
  late final EscrowRelayService service;
  var _serial = 0;
  var _requests = 0;
  var _records = 0;

  final wallet = StellarAddress.parse(alice);
  final other = StellarAddress.parse(stranger);

  /// A stored hire of [consumer] (the session wallet by default) in
  /// [status]: null has no job, any other status has job `id + 2` (3 for
  /// the first hire).
  Future<HireRow> hire({HireStatus? status, String consumer = alice}) async {
    final row = await hires.insertHire(
      NewHire(
        consumer: consumer,
        agentId: 7,
        price: price,
        manifestVersion: 1,
        expiredAt: 1800000000,
        requestId: 'request-${++_requests}',
        input: 'summarise this',
      ),
    );
    if (status == null) return row;
    await hires.bindJob(row.id, row.id + 2, expiredAt: 1800000000);
    hires.statusOverride[row.id] = status;
    return (await hires.findHire(row.id))!;
  }

  /// A `submitted` record for [hireId], as a relayed call leaves it.
  Future<StoredSubmission> record(
    int hireId,
    SubmissionPurpose purpose, {
    String? failedWith,
  }) async {
    final stored = await submissions.insertSubmitted(
      purpose: purpose,
      transactionHash: (++_records).toRadixString(16).padLeft(64, '0'),
      signedEnvelopeXdr: 'AAAA',
      validUntil: clock.add(const Duration(minutes: 5)),
      preparationId: 'old-${purpose.name}-$hireId-${failedWith ?? 'open'}',
      hireId: hireId,
    );
    if (failedWith != null) await submissions.markFailed(stored.id, failedWith);
    return stored;
  }

  /// The unix seconds the first preparation of this clock ends at.
  int get validUntilSeconds =>
      clock.millisecondsSinceEpoch ~/ 1000 + validitySeconds;
}

final agentSummary = AgentSummary(
  id: 'agt-001',
  registryId: 7,
  name: 'Test Agent',
  description: 'A helpful test agent for verification.',
  skills: ['coding'],
  priceUsdcStroops: price,
  wallet: agentWallet,
);

/// Matches a `Puls3ApiException` with [code] and, when given, [details].
Matcher api(String code, {Map<String, String>? details}) =>
    isA<Puls3ApiException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.details, 'details', details ?? anything);
