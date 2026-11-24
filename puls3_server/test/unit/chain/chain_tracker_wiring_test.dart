import 'package:http/http.dart' as http;
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/ledger/soroban_ledger.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

void main() {
  test('the tracker effects carry the child job effects, so a child '
      'submission is applied instead of failing for lack of them', () async {
    final stellar = StellarConfig.testnet;
    final effects = hireEscrowEffects(
      openSession: () async => throw StateError('no database in this test'),
      reader: SorobanLedger(
        SorobanRpcClient(
          httpClient: http.Client(),
          url: stellar.rpcUrl,
          timeout: stellar.rpcTimeout,
        ),
        stellar,
      ),
      stellar: stellar,
    );
    final at = DateTime.utc(2026, 10, 5, 12);

    // A create_child_job with no hire is a terminal mismatch of the child
    // effects; without them the effects throw a StateError.
    final result = await effects.onChildJobCreated(
      StoredSubmission(
        id: 1,
        preparationId: 'prep-1',
        purpose: SubmissionPurpose.createChildJob,
        transactionHash:
            '43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437',
        state: SubmissionState.submitted,
        errorCode: null,
        explorerUrl: null,
        hireId: null,
        signedEnvelopeXdr: 'AAAA',
        validUntil: at,
        lastSentAt: null,
        sendAttempts: 0,
        createdAt: at,
        updatedAt: at,
        lastCheckedAt: at,
      ),
      const [],
      created: const [],
      funded: const [],
    );

    expect(result, isNotNull);
  });
}
