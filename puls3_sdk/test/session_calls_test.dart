import 'package:puls3_client/puls3_client.dart' show Hire;
import 'package:puls3_sdk/puls3_sdk.dart';
import 'package:test/test.dart';

const _wallet = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

final class _NoCatalog implements CatalogApi {
  @override
  Future<List<AgentSummary>> list() async => const [];

  @override
  Future<AgentSummary?> get(String id) async => null;
}

final _agent = AgentSummary(
  id: 'agt-001',
  registryId: 7,
  name: 'Ledger Scout',
  description: 'Reads ledgers.',
  skills: const ['read'],
  priceUsdcStroops: 5000000,
  wallet: null,
  model: null,
);

PreparedTransaction _prepared(String purpose) => PreparedTransaction(
  preparationId: 'prep-1',
  purpose: purpose,
  signer: _wallet,
  networkPassphrase: 'Test SDF Network ; September 2015',
  unsignedTransactionXdr: 'AAAA',
  expiresAt: DateTime.utc(2026, 11, 11, 12),
);

/// Records each hire call and answers it, or throws [error].
final class _FakeHire implements HireApi {
  _FakeHire({this.error});

  final Object? error;
  final calls = <String>[];
  final _envelopes = <String, PreparedTransaction>{};

  /// The one envelope this fake hands out per purpose, so a test can tell the
  /// SDK returned it untouched.
  PreparedTransaction envelope(String purpose) =>
      _envelopes.putIfAbsent(purpose, () => _prepared(purpose));

  @override
  Future<CreateHireResult> createHire(
    int agentId,
    String consumer,
    String input,
    String requestId,
  ) async {
    calls.add('create $agentId $consumer $input $requestId');
    if (error != null) throw error!;
    return CreateHireResult(
      hire: Hire(
        id: 21,
        agentId: agentId,
        consumer: consumer,
        price: 5000000,
        manifestVersion: 1,
        status: 'open',
      ),
      preparedCreateJob: envelope('createJob'),
    );
  }

  @override
  Future<HireDetail> get(int hireId, String consumer) async {
    calls.add('get $hireId $consumer');
    if (error != null) throw error!;
    return HireDetail(
      hire: Hire(
        id: hireId,
        agentId: 7,
        consumer: consumer,
        price: 5000000,
        manifestVersion: 1,
        status: 'submitted',
      ),
      agent: _agent,
      input: 'summarise this',
    );
  }

  @override
  Future<PreparedTransaction> prepareCreateJob(int hireId) async {
    calls.add('createJob $hireId');
    if (error != null) throw error!;
    return envelope('createJob');
  }

  @override
  Future<PreparedTransaction> prepareFund(int hireId) async {
    calls.add('fund $hireId');
    if (error != null) throw error!;
    return envelope('fund');
  }

  @override
  Future<PreparedTransaction> prepareComplete(int hireId) async {
    calls.add('complete $hireId');
    if (error != null) throw error!;
    return _prepared('complete');
  }

  @override
  Future<PreparedTransaction> prepareReject(int hireId, String reason) async {
    calls.add('reject $hireId $reason');
    if (error != null) throw error!;
    return _prepared('reject');
  }
}

final class _FakeStudio implements StudioApi {
  final calls = <String>[];

  @override
  Future<TestRunResult> testRun(int draftId, String input) async {
    calls.add('$draftId $input');
    return TestRunResult(output: 'ok: $input', remainingDailyRuns: 4);
  }

  @override
  Future<AgentHireStarted> hireAgentAs(
    int hiringAgentId,
    int agentId,
    String input,
    int budgetUsdcStroops,
  ) async {
    calls.add('hire $hiringAgentId $agentId $input $budgetUsdcStroops');
    return AgentHireStarted(hireId: 5, hiringWallet: 'GA', state: 'started');
  }
}

void main() {
  group('with a session', () {
    late _FakeHire hire;
    late _FakeStudio studio;
    late Puls3Sdk sdk;

    setUp(() {
      hire = _FakeHire();
      studio = _FakeStudio();
      sdk = Puls3Sdk.withApi(catalog: _NoCatalog(), hire: hire, studio: studio);
    });

    test('hasSession is true', () {
      expect(sdk.hasSession, isTrue);
    });

    test(
      'createHire starts a hire and returns its unsigned create_job',
      () async {
        final started = await sdk.createHire(
          7,
          ' $_wallet ',
          'hello',
          ' req-1 ',
        );
        expect(started.hire.id, 21);
        expect(started.hire.agentId, 7);
        expect(started.hire.consumer, _wallet);
        expect(started.preparedCreateJob?.purpose, 'createJob');
        expect(started.preparedCreateJob?.unsignedTransactionXdr, 'AAAA');
        expect(hire.calls, ['create 7 $_wallet hello  req-1 ']);
      },
    );

    test('createHire sends the requestId exactly as given', () async {
      await sdk.createHire(7, _wallet, 'hello', ' req-1 ');
      await sdk.createHire(7, _wallet, 'hello', 'req-1');
      expect(hire.calls, [
        'create 7 $_wallet hello  req-1 ',
        'create 7 $_wallet hello req-1',
      ]);
    });

    test('the envelopes come back unsigned and untouched', () async {
      final started = await sdk.createHire(7, _wallet, 'hello', 'req-1');
      final createJob = await sdk.prepareCreateJob(12);
      final fund = await sdk.prepareFund(12);
      // The SDK hands back the very envelope the server returned: it neither
      // signs it nor rebuilds it, so the wallet is the only signer (ADR-0007).
      expect(
        identical(started.preparedCreateJob, hire.envelope('createJob')),
        isTrue,
      );
      expect(identical(createJob, hire.envelope('createJob')), isTrue);
      expect(identical(fund, hire.envelope('fund')), isTrue);
      for (final envelope in [started.preparedCreateJob!, createJob, fund]) {
        expect(envelope.signer, _wallet);
        expect(envelope.unsignedTransactionXdr, 'AAAA');
      }
    });

    test(
      'prepareCreateJob and prepareFund return unsigned envelopes',
      () async {
        final createJob = await sdk.prepareCreateJob(12);
        final fund = await sdk.prepareFund(12);
        expect(createJob.purpose, 'createJob');
        expect(createJob.unsignedTransactionXdr, 'AAAA');
        expect(fund.purpose, 'fund');
        expect(fund.unsignedTransactionXdr, 'AAAA');
        expect(hire.calls, ['createJob 12', 'fund 12']);
      },
    );

    test('getHire asks for the hire of the given wallet', () async {
      final detail = await sdk.getHire(12, ' $_wallet ');
      expect(detail.hire.id, 12);
      expect(hire.calls, ['get 12 $_wallet']);
    });

    test('prepareComplete returns the unsigned envelope', () async {
      final prepared = await sdk.prepareComplete(12);
      expect(prepared.purpose, 'complete');
      expect(prepared.unsignedTransactionXdr, 'AAAA');
      expect(hire.calls, ['complete 12']);
    });

    test('prepareReject passes the reason, trimmed like the wallet', () async {
      final prepared = await sdk.prepareReject(12, '  wrong language \n');
      expect(prepared.purpose, 'reject');
      expect(hire.calls, ['reject 12 wrong language']);
    });

    test('testRun runs the draft on the input', () async {
      final run = await sdk.testRun(3, 'hello');
      expect(run.output, 'ok: hello');
      expect(run.remainingDailyRuns, 4);
      expect(studio.calls, ['3 hello']);
    });

    test('hireAgentAs passes the hiring agent, agent, input and budget, '
        'and accepts registry id 0', () async {
      final started = await sdk.hireAgentAs(0, 4, 'hello', 2000000);
      expect(started.hireId, 5);
      expect(studio.calls, ['hire 0 4 hello 2000000']);
    });

    test('a server error code passes through unchanged', () async {
      final error = Puls3ApiException(code: 'HireNotOwned', message: 'x');
      final failing = Puls3Sdk.withApi(
        catalog: _NoCatalog(),
        hire: _FakeHire(error: error),
        studio: studio,
      );
      await expectLater(failing.prepareComplete(12), throwsA(same(error)));
    });

    test('bad arguments are refused without calling the server', () {
      expect(
        () => sdk.createHire(-1, _wallet, 'hi', 'req'),
        throwsArgumentError,
      );
      expect(() => sdk.createHire(1, ' ', 'hi', 'req'), throwsArgumentError);
      expect(() => sdk.createHire(1, _wallet, ' ', 'req'), throwsArgumentError);
      expect(() => sdk.createHire(1, _wallet, 'hi', ' '), throwsArgumentError);
      expect(() => sdk.prepareCreateJob(0), throwsArgumentError);
      expect(() => sdk.prepareFund(0), throwsArgumentError);
      expect(() => sdk.getHire(0, _wallet), throwsArgumentError);
      expect(() => sdk.getHire(1, '  '), throwsArgumentError);
      expect(() => sdk.prepareComplete(-1), throwsArgumentError);
      expect(() => sdk.prepareReject(1, ' '), throwsArgumentError);
      expect(() => sdk.testRun(0, 'hello'), throwsArgumentError);
      expect(() => sdk.testRun(1, ''), throwsArgumentError);
      expect(() => sdk.hireAgentAs(-1, 4, 'hi', 1), throwsArgumentError);
      expect(() => sdk.hireAgentAs(1, 4, ' ', 1), throwsArgumentError);
      expect(() => sdk.hireAgentAs(1, 4, 'hi', 0), throwsArgumentError);
      expect(hire.calls, isEmpty);
      expect(studio.calls, isEmpty);
    });
  });

  group('without a session', () {
    final sdk = Puls3Sdk.withApi(catalog: _NoCatalog());

    test('hasSession is false and the catalog still works', () async {
      expect(sdk.hasSession, isFalse);
      expect(await sdk.listAgents(), isEmpty);
    });

    test('every hire and Studio call is SessionRequired', () async {
      Matcher sessionRequired(String operation) => throwsA(
        isA<SessionRequired>().having(
          (e) => e.operation,
          'operation',
          operation,
        ),
      );
      expect(() => sdk.getHire(1, _wallet), sessionRequired('getHire'));
      expect(
        () => sdk.createHire(1, _wallet, 'hi', 'req'),
        sessionRequired('createHire'),
      );
      expect(
        () => sdk.prepareCreateJob(1),
        sessionRequired('prepareCreateJob'),
      );
      expect(() => sdk.prepareFund(1), sessionRequired('prepareFund'));
      expect(() => sdk.prepareComplete(1), sessionRequired('prepareComplete'));
      expect(
        () => sdk.prepareReject(1, 'no'),
        sessionRequired('prepareReject'),
      );
      expect(() => sdk.testRun(1, 'hi'), sessionRequired('testRun'));
      expect(
        () => sdk.hireAgentAs(1, 2, 'hi', 1),
        sessionRequired('hireAgentAs'),
      );
    });

    test('SessionRequired names the operation and never a secret', () {
      expect(
        const SessionRequired('getHire').toString(),
        'SessionRequired: getHire needs a wallet session (see #259)',
      );
    });
  });
}
