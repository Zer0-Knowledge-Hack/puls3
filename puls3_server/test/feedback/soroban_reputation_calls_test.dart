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
final _escrow = StellarConfig.testnet.escrow;

/// The escrow job of the hire being rated.
const _jobId = 8;

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

Uint8List _hex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

void main() {
  group('SorobanReputationCalls.giveFeedback', () {
    final calls = SorobanReputationCalls(
      registry: fakeReputationRegistry,
      escrow: _escrow,
    );

    ContractCall build({
      StellarAddress? client,
      int score = 5,
      String comment = '',
      int jobId = _jobId,
    }) => calls.giveFeedback(
      client: client ?? _client,
      agent: AgentId(7),
      feedback: _feedback(score: score, comment: comment),
      jobId: jobId,
    );

    test('targets the Reputation Registry `give_feedback`', () {
      final call = build();

      expect(call.contract, fakeReputationRegistry);
      expect(call.function, 'give_feedback');
    });

    test('sends the arguments in the order of the #14 signature', () {
      // give_feedback(caller: Address, agent_id: u32, value: i128,
      //   value_decimals: u32, tag1: String, tag2: String, endpoint: String,
      //   feedback_uri: String, feedback_hash: BytesN<32>)
      final call = build(score: 4);
      const reference =
          'puls3:job:v1:CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2:8';

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
              const ScArg.string(reference),
              const ScArg.string(''),
              const ScArg.string(reference),
              // SHA-256 of feedbackCommitment(job 8, agent 7, client, 4),
              // computed independently of the code under test.
              ScArg.bytes32(
                _hex(
                  '3f157e2851d9abe3598437695029fe79'
                  'e273eb62337ba21ac8a94d6836523fb0',
                ),
              ),
            ],
          ),
        ),
      );
    });

    test('tag2 and feedback_uri carry the job reference (#201)', () {
      final reference = PaidJobReference(escrow: _escrow, jobId: _jobId).text;
      final withReference = build();

      expect(
        _xdr(withReference),
        isNot(_xdr(build(jobId: _jobId + 1))),
        reason: 'another job is another call',
      );
      expect(
        PaidJobReference.tryParse(reference),
        PaidJobReference(escrow: _escrow, jobId: _jobId),
      );
    });

    test('the score is the value with no decimals, for every score', () {
      final reference = PaidJobReference(escrow: _escrow, jobId: _jobId);
      for (final score in [1, 2, 3, 4, 5]) {
        final call = build(score: score);

        expect(call.args, hasLength(9));
        expect(
          _xdr(
            ContractCall(
              contract: call.contract,
              function: call.function,
              args: call.args.sublist(0, 8),
            ),
          ),
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
                ScArg.string(reference.text),
                const ScArg.string(''),
                ScArg.string(reference.text),
              ],
            ),
          ),
          reason: 'score $score',
        );
      }
    });

    test('the hash binds the score: two scores are two hashes', () {
      expect(_xdr(build(score: 4)), isNot(_xdr(build(score: 5))));
    });

    test('the caller is the client, not the feedback of another wallet', () {
      final other = StellarConfig.testnet.usdcSac;

      expect(_xdr(build(client: other)), isNot(_xdr(build())));
    });

    test('the comment is not an argument: the contract stores no text', () {
      expect(_xdr(build(comment: 'Fast and accurate')), _xdr(build()));
    });
  });

  group('UnwiredReputationCalls', () {
    test('still fails closed until a registry is configured', () {
      expect(
        () => const UnwiredReputationCalls().giveFeedback(
          client: _client,
          agent: AgentId(7),
          feedback: _feedback(),
          jobId: _jobId,
        ),
        throwsA(isA<HireConfigurationMissing>()),
      );
    });
  });
}
