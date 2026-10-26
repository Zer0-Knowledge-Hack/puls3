import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/demo_wallet_rebinder.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart'
    show AgentEnvelopeSigner;
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/strkey.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:puls3_server/src/studio/deploy_chain.dart';
import 'package:test/test.dart';

import '../../support/fake_envelope_codec.dart';

const _owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _admin = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _agent = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
const _uri = 'puls3://demo/agt-001';

void main() {
  late _Registry registry;
  late _Wallets wallets;
  late _Funder funder;
  late _Accounts accounts;
  late FakeEnvelopeCodec codec;
  late _Assembler assembler;
  late _Sender sender;
  late _Transactions transactions;
  late DemoWalletRebinder rebinder;

  setUp(() {
    registry = _Registry();
    wallets = _Wallets();
    funder = _Funder();
    accounts = _Accounts();
    codec = FakeEnvelopeCodec();
    assembler = _Assembler(codec);
    sender = _Sender();
    transactions = _Transactions();
    rebinder = DemoWalletRebinder(
      registry: registry,
      custody: wallets,
      funder: funder,
      accounts: accounts,
      assembler: assembler,
      signer: _Signer(),
      signOwnerEntry: (entry) => Future.value(_signedAddressEntry()),
      send: sender.send,
      transactions: transactions,
      owner: StellarAddress.parse(_owner),
      adminWallet: StellarAddress.parse(_admin),
      identityRegistry: StellarConfig.testnet.identityRegistry,
      seedUris: const {_uri},
      inclusionFee: 100,
      validitySeconds: 600,
      now: () => DateTime.utc(2026, 10, 26),
    );
  });

  test('creates a custodied wallet and rebinds a GAFUY seed agent', () async {
    registry.walletById[7] = StellarAddress.parse(_admin);
    accounts.simulation = SimulationData(
      transactionData: base64Encode(const [1, 2, 3, 4]),
      minResourceFee: 50,
      auth: [_addressEntry()],
    );

    final results = await rebinder.rebindAll();

    expect(results, hasLength(1));
    expect(results.single.agentId, 7);
    expect(results.single.uri, _uri);
    expect(results.single.wallet.value, _agent);
    expect(results.single.outcome, DemoRebindOutcome.rebound);
    expect(results.single.transactionHash, isNotEmpty);
    expect(funder.funded, [StellarAddress.parse(_agent)]);
    expect(wallets.createdKeys, ['seed:$_uri']);
    expect(accounts.simulated.single.function, 'set_agent_wallet');
    expect(accounts.simulated.single.source.value, _agent);
    expect(sender.sent, hasLength(1));
  });

  test('skips a seed agent already bound to its custodied wallet', () async {
    registry.walletById[7] = StellarAddress.parse(_agent);

    final results = await rebinder.rebindAll();

    expect(results.single.outcome, DemoRebindOutcome.alreadyBound);
    expect(funder.funded, isEmpty);
    expect(sender.sent, isEmpty);
  });

  test('skips a wallet this process does not hold', () async {
    registry.walletById[7] = StellarAddress.parse(
      'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R',
    );

    final results = await rebinder.rebindAll();

    expect(results.single.outcome, DemoRebindOutcome.foreignWallet);
    expect(sender.sent, isEmpty);
  });

  test('ignores registry ids that are not seed URIs', () async {
    registry.uriById
      ..clear()
      ..[1] = 'puls3://studio/other';
    registry.walletById[1] = StellarAddress.parse(_admin);

    final results = await rebinder.rebindAll();

    expect(results, isEmpty);
  });
}

String _addressEntry() {
  final account = StellarAddress.parse(_owner);
  final out = XdrWriter()
    ..uint32(1)
    ..uint32(0)
    ..uint32(0)
    ..opaque(rawKey(account))
    ..int64(9)
    ..uint32(100)
    ..uint32(1)
    ..uint32(0x10);
  return base64Encode(out.bytes);
}

String _signedAddressEntry() {
  final account = StellarAddress.parse(_owner);
  final out = XdrWriter()
    ..uint32(1)
    ..uint32(0)
    ..uint32(0)
    ..opaque(rawKey(account))
    ..int64(9)
    ..uint32(100)
    ..uint32(3)
    ..uint32(1)
    ..uint32(0x10);
  return base64Encode(out.bytes);
}

final class _Registry implements DemoAgentRegistry {
  final uriById = <int, String>{7: _uri};
  final walletById = <int, StellarAddress>{};

  @override
  Future<int> totalAgents() async => 8;

  @override
  Future<String?> uriOf(int agentId) async => uriById[agentId];

  @override
  Future<StellarAddress?> walletOf(int agentId) async => walletById[agentId];
}

final class _Wallets implements AgentWalletCustody {
  final createdKeys = <String>[];

  @override
  Future<StellarAddress> create({
    required StellarAddress owner,
    required String idempotencyKey,
  }) async {
    createdKeys.add(idempotencyKey);
    return StellarAddress.parse(_agent);
  }
}

final class _Funder implements AccountFunder {
  final funded = <StellarAddress>[];

  @override
  Future<void> fund(StellarAddress account) async {
    funded.add(account);
  }
}

final class _Accounts implements ChainAccounts {
  SimulationData simulation = const SimulationData(
    transactionData: 'AQIDBA==',
    minResourceFee: 20,
  );
  final simulated = <EnvelopeSpec>[];

  @override
  Future<int> sequenceOf(StellarAddress account) async => 10;

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) async {
    simulated.add(spec);
    return simulation;
  }

  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async => null;
}

final class _Assembler implements AddressAuthAssembler {
  _Assembler(this.codec);

  final FakeEnvelopeCodec codec;

  @override
  PreparedEnvelope assembleAllowingAddressAuth(
    EnvelopeSpec spec,
    SimulationData sim,
  ) => codec.build(spec, sim);
}

final class _Signer implements AgentEnvelopeSigner {
  @override
  Future<String> sign(
    PreparedEnvelope envelope,
    StellarAddress address,
  ) async => FakeEnvelopeCodec.sign(envelope.envelopeXdr);
}

final class _Sender {
  final sent = <String>[];

  Future<SendTransactionResult> send(
    String envelopeXdr,
    String expectedHash,
  ) async {
    sent.add(expectedHash);
    return SendTransactionResult(
      status: SendTransactionStatus.pending,
      hash: expectedHash,
    );
  }
}

final class _Transactions implements ChainTxReader {
  @override
  Future<ChainTx> read(String hash) async =>
      const ChainTx(ChainTxStatus.success);
}
