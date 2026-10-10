// Account authority for SEP-10: master weight, medium threshold and the
// ed25519 signers of a ledger account entry.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show Puls3ApiException;
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

final _recorded = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);

/// Sequence inside test/fixtures/escrow_relay/get_ledger_entries_account.json.
const _recordedSequence = 20602318168784916;

StellarAddress _accountOf(stellar.StellarPrivateKey key) =>
    StellarAddress.parse(
      key.toPublicKey().toAddress().address,
    );

SorobanRpcClient _client(Map<String, Object?> body) => SorobanRpcClient(
  httpClient: MockClient(
    (_) async => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    ),
  ),
  url: Uri.parse('https://rpc.example.test'),
  timeout: const Duration(milliseconds: 50),
);

Map<String, Object?> _entries(String xdr) => {
  'jsonrpc': '2.0',
  'id': 1,
  'result': {
    'entries': [
      {'xdr': xdr},
    ],
    'latestLedger': 1,
  },
};

/// An account whose master weight is 1, medium threshold is 2, and whose
/// signers are one ed25519 key (weight 3) plus a pre-auth tx the decoder
/// must ignore.
({StellarAddress account, StellarAddress signer, String xdr}) _fixture() {
  final master = stellar.StellarPrivateKey.fromBytes(List<int>.filled(32, 7));
  final extra = stellar.StellarPrivateKey.fromBytes(List<int>.filled(32, 9));
  final entry = stellar.AccountEntry(
    accountId: master.toPublicKey(),
    balance: BigInt.from(100),
    seqNum: BigInt.from(42),
    numSubEntries: 1,
    flags: 0,
    homeDomain: '',
    thresholds: const [1, 0, 2, 1],
    signers: [
      stellar.Signer(
        key: stellar.SignerKeyEd25519(extra.toPublicKey().toBytes()),
        weight: 3,
      ),
      stellar.Signer(
        key: stellar.SignerKeyPreAuthTx(List<int>.filled(32, 3)),
        weight: 5,
      ),
    ],
    ext: const stellar.AccountEntryExt(),
  );
  return (
    account: _accountOf(master),
    signer: _accountOf(extra),
    xdr: base64Encode(entry.toVariantXDR()),
  );
}

void main() {
  test(
    'a fixture account entry decodes master weight, medium threshold and ed25519 signers',
    () async {
      final fixture = _fixture();
      final accounts = RpcChainAccounts(_client(_entries(fixture.xdr)));

      final authority = await accounts.authorityOf(fixture.account);

      expect(authority, isNotNull);
      expect(authority!.masterWeight, 1);
      expect(authority.mediumThreshold, 2);
      expect(authority.signers, {fixture.signer: 3});
    },
  );

  test(
    'a real testnet account entry, with its ledger extensions, decodes too',
    () async {
      // Recorded from testnet: a funded account whose entry carries the
      // liabilities and sponsorship extensions every real account has.
      final accounts = RpcChainAccounts(
        _client(
          jsonDecode(
                File(
                  'test/fixtures/escrow_relay/get_ledger_entries_account.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>,
        ),
      );

      final authority = await accounts.authorityOf(_recorded);

      expect(authority, isNotNull);
      expect(authority!.masterWeight, 1);
      expect(authority.mediumThreshold, 0);
      expect(authority.signers, isEmpty);
    },
  );

  test(
    'a truncated or foreign entry is unreadable, never a master key',
    () async {
      final recorded =
          jsonDecode(
                File(
                  'test/fixtures/escrow_relay/get_ledger_entries_account.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final xdr = base64Decode(
        ((recorded['result'] as Map)['entries'] as List).first['xdr'] as String,
      );

      for (final broken in [
        xdr.sublist(0, 60), // cut inside the account id and balance
        xdr.sublist(0, 78), // cut inside the signer count
        Uint8List.fromList([0, 0, 0, 9, ...xdr.sublist(4)]), // not an account
      ]) {
        final accounts = RpcChainAccounts(
          _client(_entries(base64Encode(broken))),
        );

        await expectLater(
          accounts.authorityOf(_recorded),
          throwsA(
            isA<Puls3ApiException>().having(
              (error) => error.code,
              'code',
              'ChainUnavailable',
            ),
          ),
        );
      }
    },
  );

  test('an account that is not on the ledger has no authority', () async {
    final accounts = RpcChainAccounts(
      _client(
        jsonDecode(
              File(
                'test/fixtures/escrow_relay/get_ledger_entries_missing_account.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>,
      ),
    );

    expect(await accounts.authorityOf(_recorded), isNull);
  });

  test(
    'accountSequence still returns the sequence of the recorded entry',
    () async {
      final client = _client(
        jsonDecode(
              File(
                'test/fixtures/escrow_relay/get_ledger_entries_account.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>,
      );

      expect(await client.accountSequence(_recorded), _recordedSequence);
    },
  );

  test('an unreachable node is ChainUnavailable', () {
    final accounts = RpcChainAccounts(
      SorobanRpcClient(
        httpClient: MockClient((_) async => http.Response('down', 503)),
        url: Uri.parse('https://rpc.example.test'),
        timeout: const Duration(milliseconds: 50),
      ),
    );

    expect(
      accounts.authorityOf(_recorded),
      throwsA(
        isA<Puls3ApiException>()
            .having((error) => error.code, 'code', 'ChainUnavailable')
            .having(
              (error) => error.details,
              'details',
              {'reason': 'simulationFailed'},
            ),
      ),
    );
  });
}
