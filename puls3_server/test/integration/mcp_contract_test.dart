@Tags(['integration'])
library;

import 'dart:convert';

import 'package:dart_mcp/client.dart';
import 'package:puls3_mcp/puls3_mcp.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
// The test server is built without `run`, so it has no auth handler; this is
// Serverpod's own hook for setting one in tests.
// ignore: implementation_imports
import 'package:serverpod/src/server/server.dart' show ServerInternalMethods;
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'sdk_contract/sdk_world.dart';
import 'test_tools/serverpod_test_tools.dart';

/// The `puls3_mcp` tools against this server over HTTP (#375).
///
/// The same world as `sdk_contract_test.dart`: real HTTP, a CLI session from
/// the real wallet sign-in, the real endpoints and database, a faked chain.
/// The MCP server is the real `Puls3McpServer`, reached by an in-memory MCP
/// client, so each tool's arguments, its SDK call and its error text are
/// checked against what the server stores and answers.
void main() {
  withServerpod(
    'Given the puls3_mcp tools over HTTP (#375)',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      late SdkWorld world;
      late ServerConnection client;

      setUpAll(() async {
        AuthServices.set(tokenManagerBuilders: [JwtConfigFromPasswords()]);
        Serverpod.instance.server.setAuthenticationHandlerForTesting(
          AuthServices.instance.authenticationHandler,
        );
        world = await SdkWorld.start(sessionBuilder);
        // One sign-in for the group: the challenge endpoint is rate limited.
        final sdk = await world.signedInSdk();

        final channels = StreamChannelController<String>();
        Puls3McpServer(
          channels.local,
          sdk: sdk,
          apiUrl: world.apiUrl.toString(),
          wallet: world.wallet,
        );
        client = MCPClient(
          Implementation(name: 'contract test', version: '0.0.1'),
        ).connectServer(channels.foreign);
        await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'contract test', version: '0.0.1'),
          ),
        );
        client.notifyInitialized();
      });

      tearDownAll(() async {
        await client.shutdown();
        await world.close();
      });

      Future<CallToolResult> call(String tool, [Map<String, Object?>? args]) =>
          client.callTool(CallToolRequest(name: tool, arguments: args));

      String text(CallToolResult result) =>
          result.content.map((c) => (c as TextContent).text).join('\n');

      /// The JSON a successful tool returned.
      Future<Map<String, Object?>> ok(
        String tool, [
        Map<String, Object?>? args,
      ]) async {
        final result = await call(tool, args);
        expect(result.isError, isNot(true), reason: text(result));
        return jsonDecode(text(result)) as Map<String, Object?>;
      }

      /// A hire of the session wallet with its `create_job` confirmed.
      Future<HireRecord> openHire(String requestId) async {
        final created = await world.createHire(requestId: requestId);
        return HireRecord.db.updateRow(
          world.db,
          (await HireRecord.db.findById(world.db, created.hire.id))!.copyWith(
            jobId: 9000 + created.hire.id,
          ),
        );
      }

      Future<EscrowPreparation> currentPreparation(int hireId) async =>
          (await EscrowPreparation.db.findFirstRow(
            world.db,
            where: (t) => t.hireId.equals(hireId) & t.supersededAt.equals(null),
            orderByList: (t) => [t.id.desc()],
          ))!;

      test('catalog_list lists what the server lists', () async {
        final result = await call('catalog_list');

        expect(result.isError, isNot(true), reason: text(result));
        final agents = jsonDecode(text(result)) as List<Object?>;
        expect(agents, hasLength(1));
        final agent = agents.single! as Map<String, Object?>;
        expect(agent['id'], 'agt-001');
        expect(agent['registryId'], agentRegistryId);
      });

      test('hire_get returns the stored hire for the session wallet', () async {
        final created = await world.createHire(requestId: 'mcp-get');

        final hire = await ok('hire_get', {'hireId': created.hire.id});

        final row = (await HireRecord.db.findById(world.db, created.hire.id))!;
        expect(hire['id'], row.id);
        expect(hire['consumer'], row.consumer);
        expect(hire['priceUsdcStroops'], row.price);
        expect(hire['agentId'], 'agt-001');
        expect(hire['input'], row.input);
      });

      test('hire_prepare_reject stores the reject and sends nothing', () async {
        final hire = await openHire('mcp-reject');

        final prepared = await ok('hire_prepare_reject', {
          'hireId': hire.id,
          'reason': '  wrong agent  ',
        });

        final stored = await currentPreparation(hire.id!);
        expect(prepared['purpose'], 'reject');
        expect(prepared['submitted'], isFalse);
        expect(prepared['preparationId'], stored.preparationId);
        expect(prepared['unsignedTransactionXdr'], stored.unsignedEnvelopeXdr);
        expect(stored.rejectReason, 'wrong agent');
        expect(
          await ChainSubmission.db.count(
            world.db,
            where: (t) => t.hireId.equals(hire.id!),
          ),
          0,
        );
      });

      test(
        'a typed server error with details keeps its code (#390)',
        () async {
          final hire = await openHire('mcp-complete-open');

          final result = await call('hire_prepare_complete', {
            'hireId': hire.id,
          });

          // Before #390 the client could not read this error and the tool
          // answered `Unreachable`.
          expect(result.isError, isTrue);
          expect(text(result), 'error: InvalidHireTransition: ');
        },
      );

      test("another wallet's hire is refused by the server", () async {
        final created = await world.createHire(requestId: 'mcp-other');

        final result = await call('hire_get', {
          'hireId': created.hire.id,
          'wallet': 'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R',
        });

        expect(result.isError, isTrue);
        expect(text(result), 'error: WalletMismatch: ');
      });

      test(
        'studio_test_run runs the stored draft on the input as given',
        () async {
          final draftId = await world.saveDraft();
          world.studioTasks.clear();

          final run = await ok('studio_test_run', {
            'draftId': draftId,
            'input': '  A long note.  ',
          });

          expect(world.studioTasks.single.input, '  A long note.  ');
          expect(run['output'], 'echo:   A long note.  ');
        },
      );
    },
  );
}
