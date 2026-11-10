import 'dart:convert';

import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/runtime/agent_runner.dart';
import 'package:puls3_server/src/runtime/run_execution.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:puls3_server/src/studio/builder_credential.dart';
import 'package:puls3_server/src/studio/serverpod_builder_credential_store.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _builder = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
const _other = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _token = 'builder-cloudflare-token-0123456789';
const _account = 'builderaccount0001';

final _key1 = List<int>.generate(32, (i) => i);
final _key2 = List<int>.generate(32, (i) => 255 - i);

AesGcmSecretCipher _cipher({
  Map<int, List<int>>? keys,
  int writeKeyVersion = 1,
}) => AesGcmSecretCipher(
  keys: keys ?? {1: _key1},
  writeKeyVersion: writeKeyVersion,
);

const _credential = BuilderProviderCredential(
  provider: 'workers-ai',
  secret: _token,
  accountId: _account,
);

final class _TeamModel implements ModelRuntime {
  final tasks = <RuntimeTask>[];

  @override
  Future<String> complete(
    RuntimeTask task, {
    Future<void>? abortTrigger,
  }) async {
    tasks.add(task);
    return 'team';
  }
}

void main() {
  withServerpod('builder credential persistence (#235)', (sessionBuilder, _) {
    ServerpodBuilderCredentialStore store({AesGcmSecretCipher? cipher}) =>
        ServerpodBuilderCredentialStore(
          sessionBuilder.build(),
          cipher: cipher ?? _cipher(),
          now: () => DateTime.utc(2026, 11, 7, 12),
        );

    Future<List<BuilderCredentialRecord>> rows() =>
        BuilderCredentialRecord.db.find(sessionBuilder.build());

    test('a saved credential is read back by a new store, as after a '
        'restart', () async {
      await store().save(owner: _builder, credential: _credential);

      final found = await store().find(
        owner: _builder,
        provider: 'workers-ai',
      );

      expect(found, isNotNull);
      expect(found!.secret, _token);
      expect(found.accountId, _account);
      expect(found.provider, 'workers-ai');
    });

    test('the database holds ciphertext, never the token', () async {
      await store().save(owner: _builder, credential: _credential);

      final row = (await rows()).single;

      expect(row.owner, _builder);
      expect(row.keyVersion, 1);
      expect(row.accountId, _account);
      expect(row.ciphertext, isNot(contains(_token)));
      expect(
        row.ciphertext,
        isNot(contains(base64.encode(utf8.encode(_token)))),
      );
      expect(row.nonce, isNotEmpty);
      expect(row.mac, isNotEmpty);
      expect(row.toJson().toString(), isNot(contains(_token)));
    });

    test('saving again replaces the credential: one row per owner and '
        'provider', () async {
      await store().save(owner: _builder, credential: _credential);
      await store().save(
        owner: _builder,
        credential: const BuilderProviderCredential(
          provider: 'workers-ai',
          secret: 'rotated-token',
          accountId: 'newaccount',
        ),
      );

      final found = await store().find(
        owner: _builder,
        provider: 'workers-ai',
      );

      expect(found!.secret, 'rotated-token');
      expect(found.accountId, 'newaccount');
      expect(await rows(), hasLength(1));
    });

    test('another owner or another provider finds nothing', () async {
      await store().save(owner: _builder, credential: _credential);

      expect(await store().find(owner: _other, provider: 'workers-ai'), isNull);
      expect(
        await store().find(owner: _builder, provider: 'anthropic'),
        isNull,
      );
    });

    test('a row moved to another owner no longer decrypts', () async {
      await store().save(owner: _builder, credential: _credential);
      final row = (await rows()).single;
      await BuilderCredentialRecord.db.updateRow(
        sessionBuilder.build(),
        row.copyWith(owner: _other),
      );

      expect(await store().find(owner: _other, provider: 'workers-ai'), isNull);
    });

    test('after a key rotation an old row still decrypts and a new save uses '
        'the new key', () async {
      await store().save(owner: _builder, credential: _credential);
      final rotated = _cipher(keys: {1: _key1, 2: _key2}, writeKeyVersion: 2);

      final old = await store(
        cipher: rotated,
      ).find(owner: _builder, provider: 'workers-ai');
      expect(old!.secret, _token);

      await store(
        cipher: rotated,
      ).save(owner: _builder, credential: _credential);
      expect((await rows()).single.keyVersion, 2);
      expect(
        (await store(
          cipher: rotated,
        ).find(owner: _builder, provider: 'workers-ai'))!.secret,
        _token,
      );
    });

    test('a wrong or unknown key reads as no credential', () async {
      await store().save(owner: _builder, credential: _credential);

      final wrongKey = _cipher(keys: {1: _key2});
      final unknownVersion = _cipher(keys: {3: _key1}, writeKeyVersion: 3);

      expect(
        await store(
          cipher: wrongKey,
        ).find(owner: _builder, provider: 'workers-ai'),
        isNull,
      );
      expect(
        await store(
          cipher: unknownVersion,
        ).find(owner: _builder, provider: 'workers-ai'),
        isNull,
      );
    });

    test(
      'a Studio run reads the persisted credential, not the team token',
      () async {
        await store().save(owner: _builder, credential: _credential);
        final team = _TeamModel();
        final builderCalls = <BuilderProviderCredential>[];
        final execute = runExecutor(
          team: AgentRunner(runtime: team, timeout: const Duration(seconds: 1)),
          credentials: store().find,
          builder: (task, credential) async {
            builderCalls.add(credential);
            return 'builder';
          },
        );

        final output = await execute(
          const OwnedRunManifest(
            owner: _builder,
            provider: 'workers-ai',
            modelId: '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
            systemPrompt: 'You rewrite one paragraph in a calmer voice.',
            inputMaxChars: 1000,
            outputMaxChars: 1000,
          ),
          'Make this calmer',
        );

        expect(output, 'builder');
        expect(builderCalls.single.secret, _token);
        expect(builderCalls.single.accountId, _account);
        expect(team.tasks, isEmpty);
      },
    );
  });
}
