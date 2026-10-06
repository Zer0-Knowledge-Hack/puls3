import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final usdc = StellarAddress.parse(
  'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA',
);
final client = StellarAddress.parse(
  'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV',
);
final provider = StellarAddress.parse(
  'GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK',
);
final stranger = StellarAddress.parse(
  'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R',
);
final fundTx = TransactionHash.parse(
  '43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437',
);

const preparedExpiry = 1800000000;

final hire = Hire(
  id: HireId(7),
  agentId: AgentId(3),
  consumer: client,
  price: UsdcAmount.stroops(5000000),
  manifestVersion: 1,
);

FundedJob job({
  int jobId = 3,
  StellarAddress? token,
  StellarAddress? jobClient,
  StellarAddress? jobEvaluator,
  StellarAddress? jobProvider,
  int agent = 3,
  BigInt? budget,
  int expiredAt = preparedExpiry,
  JobState state = JobState.funded,
}) => FundedJob(
  jobId: jobId,
  client: jobClient ?? client,
  evaluator: jobEvaluator ?? client,
  provider: jobProvider ?? provider,
  token: token ?? usdc,
  agentId: AgentId(agent),
  budget: budget ?? BigInt.from(5000000),
  expiredAt: expiredAt,
  state: state,
);

FundingVerdict verify(FundedJob funded) => verifyFunding(
  hire,
  funded,
  transaction: fundTx,
  usdc: usdc,
  agentWallet: provider,
  expiredAt: preparedExpiry,
);

FundingRejection rejected(FundedJob funded) => switch (verify(funded)) {
  FundingRejected(:final reason) => reason,
  FundingAccepted() => fail('expected a rejection'),
};

void main() {
  group('accepted verdict', () {
    test('builds the payment from the job', () {
      final verdict = verify(job(jobId: 3));

      expect(verdict, isA<FundingAccepted>());
      final payment = (verdict as FundingAccepted).payment;
      expect(payment.transaction, fundTx);
      expect(payment.hireId, hire.id);
      expect(payment.payer, client);
      expect(payment.payee, provider);
      expect(payment.amount, UsdcAmount.stroops(5000000));
    });

    test('the payment settles the hire through Hire.pay', () {
      final accepted = verify(job()) as FundingAccepted;

      final paid = hire.pay(accepted.payment, agentWallet: provider);

      expect(paid.status, HireStatus.paid);
    });
  });

  group('one rejection per mismatching job field', () {
    test('jobNotFunded (state): every state but Funded', () {
      for (final state in JobState.values.where((s) => s != JobState.funded)) {
        expect(
          rejected(job(state: state)),
          FundingRejection.jobNotFunded,
          reason: state.name,
        );
      }
    });

    test('clientMismatch: the job client is not the hire consumer', () {
      expect(
        rejected(job(jobClient: stranger)),
        FundingRejection.clientMismatch,
      );
    });

    test('evaluatorMismatch: the job evaluator is not the hire consumer', () {
      expect(
        rejected(job(jobEvaluator: stranger)),
        FundingRejection.evaluatorMismatch,
      );
    });

    test('wrongDestination: the job provider is not the agent wallet', () {
      expect(
        rejected(job(jobProvider: stranger)),
        FundingRejection.wrongDestination,
      );
    });

    test('agentMismatch: the job is for another agent', () {
      expect(rejected(job(agent: 4)), FundingRejection.agentMismatch);
    });

    test('wrongAsset: the job token is not the configured USDC', () {
      expect(rejected(job(token: stranger)), FundingRejection.wrongAsset);
    });

    test('expiryMismatch: expired_at is not the prepared one', () {
      expect(
        rejected(job(expiredAt: preparedExpiry + 1)),
        FundingRejection.expiryMismatch,
      );
      expect(
        rejected(job(expiredAt: preparedExpiry - 1)),
        FundingRejection.expiryMismatch,
      );
    });

    group('amountMismatch', () {
      final budgets = <String, BigInt>{
        'below the price': BigInt.from(4999999),
        'above the price': BigInt.from(5000001),
        'zero': BigInt.zero,
        'negative': BigInt.from(-1),
        'over the maximum amount':
            BigInt.from(UsdcAmount.maxStroops) + BigInt.one,
      };
      for (final entry in budgets.entries) {
        test('${entry.key} is rejected and builds no payment', () {
          expect(
            rejected(job(budget: entry.value)),
            FundingRejection.amountMismatch,
          );
        });
      }
    });
  });

  group('job state', () {
    test('only Funded is accepted: submitted and completed are not', () {
      expect(verify(job(state: JobState.funded)), isA<FundingAccepted>());
      for (final state in [JobState.submitted, JobState.completed]) {
        expect(
          rejected(job(state: state)),
          FundingRejection.jobNotFunded,
          reason: state.name,
        );
      }
    });
  });

  group('check order (api.md): state, client, evaluator, provider, ...', () {
    final everythingWrong = job(
      jobClient: stranger,
      jobEvaluator: stranger,
      jobProvider: stranger,
      agent: 4,
      token: stranger,
      budget: BigInt.one,
      expiredAt: 1,
      state: JobState.open,
    );

    test('state wins over every other mismatch', () {
      expect(rejected(everythingWrong), FundingRejection.jobNotFunded);
    });

    test('client, evaluator, provider, agent, token, budget, expiry', () {
      final expected = [
        FundingRejection.clientMismatch,
        FundingRejection.evaluatorMismatch,
        FundingRejection.wrongDestination,
        FundingRejection.agentMismatch,
        FundingRejection.wrongAsset,
        FundingRejection.amountMismatch,
        FundingRejection.expiryMismatch,
      ];
      final fixes = <FundedJob Function(FundedJob)>[
        (j) => job(
          jobEvaluator: j.evaluator,
          jobProvider: j.provider,
          agent: j.agentId.value,
          token: j.token,
          budget: j.budget,
          expiredAt: j.expiredAt,
        ),
        (j) => job(
          jobProvider: j.provider,
          agent: j.agentId.value,
          token: j.token,
          budget: j.budget,
          expiredAt: j.expiredAt,
        ),
        (j) => job(
          agent: j.agentId.value,
          token: j.token,
          budget: j.budget,
          expiredAt: j.expiredAt,
        ),
        (j) => job(token: j.token, budget: j.budget, expiredAt: j.expiredAt),
        (j) => job(budget: j.budget, expiredAt: j.expiredAt),
        (j) => job(expiredAt: j.expiredAt),
      ];
      var current = job(
        jobClient: stranger,
        jobEvaluator: stranger,
        jobProvider: stranger,
        agent: 4,
        token: stranger,
        budget: BigInt.one,
        expiredAt: 1,
      );
      for (var i = 0; i < expected.length; i++) {
        expect(rejected(current), expected[i]);
        if (i < fixes.length) current = fixes[i](current);
      }
    });
  });

  group('FundingRejection', () {
    test('names the mismatching job field, as the escrow stores it', () {
      expect({for (final r in FundingRejection.values) r.name: r.field}, {
        'jobNotFunded': 'state',
        'clientMismatch': 'client',
        'evaluatorMismatch': 'evaluator',
        'wrongDestination': 'provider',
        'agentMismatch': 'agent_id',
        'wrongAsset': 'token',
        'amountMismatch': 'budget',
        'expiryMismatch': 'expired_at',
      });
    });
  });
}
