import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/feedback/reputation_calls.dart';
import 'package:puls3_server/src/feedback/reputation_wiring.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show HireConfigurationMissing;
import 'package:puls3_server/src/ledger/contract_reader.dart';
import 'package:puls3_server/src/ledger/soroban_reputation_registry.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

final _client = StellarConfig.testnet.simulationSource;

final _configured = StellarConfig.fromEnvironment({
  'PULS3_STELLAR_REPUTATION_REGISTRY':
      StellarConfig.testnet.identityRegistry.value,
});

ContractReader _reader(StellarConfig config) => ContractReader(
  SorobanRpcClient(
    httpClient: MockClient((_) async => http.Response('{}', 200)),
    url: config.rpcUrl,
    timeout: const Duration(seconds: 1),
  ),
  source: config.simulationSource,
);

Feedback _feedback() => Feedback(
  hireId: HireId(1),
  agentId: AgentId(7),
  client: _client,
  score: 5,
);

void main() {
  group('reputationCallsFor', () {
    test('builds the real call once the registry is configured', () {
      final calls = reputationCallsFor(_configured);

      expect(calls, isA<SorobanReputationCalls>());
      final call = calls.giveFeedback(
        client: _client,
        agent: AgentId(7),
        feedback: _feedback(),
      );
      expect(call.contract, StellarConfig.testnet.identityRegistry);
      expect(call.function, 'give_feedback');
    });

    test('stays unwired, failing closed, while the registry is unset', () {
      final calls = reputationCallsFor(_withoutRegistry());

      expect(calls, isA<UnwiredReputationCalls>());
      expect(
        () => calls.giveFeedback(
          client: _client,
          agent: AgentId(7),
          feedback: _feedback(),
        ),
        throwsA(isA<HireConfigurationMissing>()),
      );
    });
  });

  group('reputationRegistryFor', () {
    test('reads the configured registry on chain', () {
      expect(
        reputationRegistryFor(_configured, _reader(_configured)),
        isA<SorobanReputationRegistry>(),
      );
    });

    test('has no feedback to read while the registry is unset', () async {
      final config = _withoutRegistry();
      final registry = reputationRegistryFor(config, _reader(config));

      expect(registry, isA<UnwiredReputationRegistry>());
      expect(await registry.feedbacksOf(AgentId(7)), isEmpty);
    });
  });
}

/// The testnet config with no Reputation Registry configured.
StellarConfig _withoutRegistry() => StellarConfig(
  rpcUrl: StellarConfig.testnet.rpcUrl,
  networkPassphrase: StellarConfig.testnet.networkPassphrase,
  usdcSac: StellarConfig.testnet.usdcSac,
  identityRegistry: StellarConfig.testnet.identityRegistry,
  escrow: StellarConfig.testnet.escrow,
  simulationSource: StellarConfig.testnet.simulationSource,
);
