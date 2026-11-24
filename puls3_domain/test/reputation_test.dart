import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final owner = StellarAddress.parse(
  'GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK',
);
final consumer = StellarAddress.parse(
  'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV',
);
final txHash = TransactionHash.parse(
  '17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f',
);
final feedbackTx = TransactionHash.parse(
  '05724ac7d1e9a5f3b2c4d6e8f0a1b3c5d7e9f1a3b5c7d9e1f3a5b7c9d1e3f5a7',
);
final price = UsdcAmount.stroops(3000000);

Feedback feedback({
  StellarAddress? client,
  int score = 5,
  int hireId = 7,
  int agentId = 0,
}) => Feedback(
  hireId: HireId(hireId),
  agentId: AgentId(agentId),
  client: client ?? consumer,
  score: score,
);

/// A valid account address (G...) whose key bytes encode [n]: a distinct
/// client per [n].
StellarAddress clientNumber(int n) {
  final payload = [
    6 << 3,
    ...List<int>.filled(29, 0),
    n >> 16,
    n >> 8 & 255,
    n & 255,
  ];
  var crc = 0;
  for (final byte in payload) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = crc & 0x8000 != 0
          ? (crc << 1 ^ 0x1021) & 0xffff
          : crc << 1 & 0xffff;
    }
  }
  final bytes = [...payload, crc & 255, crc >> 8];
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in bytes) {
    buffer = buffer << 8 | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(alphabet[buffer >> bits & 31]);
    }
  }
  return StellarAddress.parse('$out');
}

/// One feedback per score, each from its own client.
List<Feedback> scores(List<int> values) => [
  for (var i = 0; i < values.length; i++)
    feedback(client: clientNumber(i + 1), score: values[i]),
];

/// Every score from the same client, as from one wallet hiring again and
/// again.
List<Feedback> fromOneClient(List<int> values) => [
  for (final value in values) feedback(client: consumer, score: value),
];

/// A hire that reached `completed` only through valid transitions.
Hire completedHire() {
  final hire = Hire(
    id: HireId(7),
    agentId: AgentId(0),
    consumer: consumer,
    price: price,
    manifestVersion: 1,
  );
  final payment = Payment(
    transaction: txHash,
    hireId: HireId(7),
    payer: consumer,
    payee: owner,
    amount: price,
  );
  return hire.fund(payment, agentWallet: owner).submit().complete();
}

/// The worked examples of docs/domain/reputation.md, with the same inputs and
/// outputs (acceptance criterion of #11).
final workedExamples = <(String, List<int>, double)>[
  ('new agent, no reviews', <int>[], 4.00),
  ('one 5-star review', <int>[5], 4.17),
  (
    '100 reviews averaging 4.80',
    [...List.filled(80, 5), ...List.filled(20, 4)],
    4.76,
  ),
];

void main() {
  test('the prior parameters are the documented ones (m = 4.0, C = 5)', () {
    expect(reputationPriorMean, 4.0);
    expect(reputationPriorWeight, 5.0);
  });

  group('Bayesian average matches the worked examples', () {
    for (final (label, values, expected) in workedExamples) {
      test('$label -> $expected', () {
        expect(reputationOf(scores(values)), expected);
      });
    }
  });

  group('Bayesian average, further cases', () {
    test('no feedback gives the prior mean', () {
      expect(reputationOf(const <Feedback>[]), reputationPriorMean);
    });

    test('two 5-stars -> 4.29', () {
      expect(reputationOf(scores([5, 5])), 4.29);
    });

    test('a single 1-star -> 3.50', () {
      expect(reputationOf(scores([1])), 3.50);
    });

    test('five 3-stars (a below-prior mean) -> 3.50', () {
      expect(reputationOf(scores([3, 3, 3, 3, 3])), 3.50);
    });
  });

  group('one client is one rating (ADR-0012, #324)', () {
    test('twenty 5-stars from one wallet count as one -> 4.17', () {
      // The same as a single 5-star, not the 4.80 that twenty separate
      // ratings would give.
      expect(reputationOf(fromOneClient(List.filled(20, 5))), 4.17);
      expect(reputationOf(scores(List.filled(20, 5))), 4.80);
    });

    test('a client with several ratings counts with their mean', () {
      // One client gave 5 and 3 (mean 4), another gave 5:
      // (5 * 4.0 + 4 + 5) / (5 + 2) = 4.14.
      final feedback = [
        ...fromOneClient([5, 3]),
        ...scores([5]),
      ];
      expect(reputationOf(feedback), 4.14);
    });

    test('the order of the feedback does not change the rating', () {
      final feedback = [
        ...scores([4, 2]),
        ...fromOneClient([5, 1, 3]),
      ];
      expect(
        reputationOf(feedback.reversed),
        reputationOf(feedback),
      );
    });
  });

  group('anti-gaming: a single review cannot buy the top spot', () {
    test('one 5-star ranks below a long 4.80 record', () {
      final fresh = reputationOf(scores([5]));
      final established = reputationOf(scores(workedExamples[2].$2));
      expect(fresh, 4.17);
      expect(established, 4.76);
      expect(fresh, lessThan(established));
    });
  });

  group('self-rating is rejected (#11)', () {
    test('isSelfRating is true when the client is the agent owner', () {
      expect(isSelfRating(feedback(client: owner), owner: owner), isTrue);
    });

    test('isSelfRating is false for any other client', () {
      expect(isSelfRating(feedback(client: consumer), owner: owner), isFalse);
    });

    test('rejectSelfRating throws FeedbackFromAgentOwner', () {
      expect(
        () => rejectSelfRating(feedback(client: owner), owner: owner),
        throwsA(isA<FeedbackFromAgentOwner>()),
      );
    });

    test('rejectSelfRating allows the consumer', () {
      expect(
        () => rejectSelfRating(feedback(client: consumer), owner: owner),
        returnsNormally,
      );
    });
  });

  group('one feedback per hire', () {
    test('a second feedback on the same hire is rejected', () {
      final rated = completedHire().recordFeedback(
        feedback(),
        reference: feedbackTx,
      );
      expect(
        () => rated.recordFeedback(feedback(), reference: feedbackTx),
        throwsA(isA<HireAlreadyRated>()),
      );
    });
  });
}
