import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/feedback/reputation_calls.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show HireConfigurationMissing;
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

import '../support/fake_feedback_ports.dart';

final _client = StellarConfig.testnet.simulationSource;

Feedback _feedback({int score = 5, String comment = ''}) => Feedback(
  hireId: HireId(8),
  agentId: AgentId(7),
  client: _client,
  score: score,
  comment: comment,
);

/// The XDR of a call, so two calls compare by what they would send.
Uint8List _xdr(ContractCall call) => encodeInvokeHostFunction(
  contract: call.contract,
  function: call.function,
  args: call.args,
);

void main() {
  group('SorobanReputationCalls.giveFeedback', () {
    final calls = SorobanReputationCalls(registry: fakeReputationRegistry);

    test('targets the Reputation Registry `give_feedback`', () {
      final call = calls.giveFeedback(
        client: _client,
        agent: AgentId(7),
        feedback: _feedback(),
      );

      expect(call.contract, fakeReputationRegistry);
      expect(call.function, 'give_feedback');
    });

    test('sends the arguments in the order of the #14 signature', () {
      // give_feedback(caller: Address, agent_id: u32, value: i128,
      //   value_decimals: u32, tag1: String, tag2: String, endpoint: String,
      //   feedback_uri: String, feedback_hash: BytesN<32>)
      final call = calls.giveFeedback(
        client: _client,
        agent: AgentId(7),
        feedback: _feedback(score: 4),
      );

      expect(call.args, hasLength(9));
      expect(
        _xdr(call),
        _xdr(
          ContractCall(
            contract: fakeReputationRegistry,
            function: 'give_feedback',
            args: [
              ScArg.address(_client),
              const ScArg.u32(7),
              const ScArg.i128(4),
              const ScArg.u32(0),
              const ScArg.string(''),
              const ScArg.string(''),
              const ScArg.string(''),
              const ScArg.string(''),
              ScArg.bytes32(Uint8List(32)),
            ],
          ),
        ),
      );
    });

    test('the score is the value with no decimals, for every score', () {
      for (final score in [1, 2, 3, 4, 5]) {
        final call = calls.giveFeedback(
          client: _client,
          agent: AgentId(7),
          feedback: _feedback(score: score),
        );

        expect(
          _xdr(call),
          _xdr(
            ContractCall(
              contract: fakeReputationRegistry,
              function: 'give_feedback',
              args: [
                ScArg.address(_client),
                const ScArg.u32(7),
                ScArg.i128(score),
                const ScArg.u32(0),
                const ScArg.string(''),
                const ScArg.string(''),
                const ScArg.string(''),
                const ScArg.string(''),
                ScArg.bytes32(Uint8List(32)),
              ],
            ),
          ),
          reason: 'score $score',
        );
      }
    });

    test('the caller is the client, not the feedback of another wallet', () {
      final other = StellarConfig.testnet.escrow;
      final call = calls.giveFeedback(
        client: other,
        agent: AgentId(7),
        feedback: _feedback(),
      );

      expect(
        _xdr(call),
        isNot(
          _xdr(
            calls.giveFeedback(
              client: _client,
              agent: AgentId(7),
              feedback: _feedback(),
            ),
          ),
        ),
      );
    });

    test('the comment is not an argument: the contract stores no text', () {
      final plain = calls.giveFeedback(
        client: _client,
        agent: AgentId(7),
        feedback: _feedback(),
      );
      final withComment = calls.giveFeedback(
        client: _client,
        agent: AgentId(7),
        feedback: _feedback(comment: 'Fast and accurate'),
      );

      expect(_xdr(withComment), _xdr(plain));
    });
  });

  group('UnwiredReputationCalls', () {
    test('still fails closed until a registry is configured', () {
      expect(
        () => const UnwiredReputationCalls().giveFeedback(
          client: _client,
          agent: AgentId(7),
          feedback: _feedback(),
        ),
        throwsA(isA<HireConfigurationMissing>()),
      );
    });
  });
}
