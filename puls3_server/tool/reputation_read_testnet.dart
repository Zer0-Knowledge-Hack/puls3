// ignore_for_file: avoid_print
// Reads the Reputation Registry on testnet through the same adapter the server
// uses and prints the #11 reputation of an agent. Read-only: simulations only.
//
//   dart run tool/reputation_read_testnet.dart [agentId]
import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/feedback/reputation_wiring.dart';
import 'package:puls3_server/src/ledger/contract_reader.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';

Future<void> main(List<String> args) async {
  final agent = AgentId(args.isEmpty ? 7 : int.parse(args.first));
  final config = StellarConfig.testnet;
  final client = http.Client();
  try {
    final rpc = SorobanRpcClient(
      httpClient: client,
      url: config.rpcUrl,
      timeout: const Duration(seconds: 20),
    );
    final registry = reputationRegistryFor(
      config,
      ContractReader(rpc, source: config.simulationSource),
    );
    final feedback = await registry.feedbacksOf(agent);
    print('registry  = ${config.reputationRegistry?.value}');
    print('agent     = ${agent.value}');
    print('scores    = ${[for (final f in feedback) f.score]}');
    print('reputation= ${reputationOf(feedback)}');
  } finally {
    client.close();
  }
}
