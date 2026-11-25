import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

/// A Testnet wallet that records its prompts.
class _Wallet implements WalletPort {
  String? _address;

  /// When set, the next sign-in challenge fails with it once.
  WalletException? failNextChallenge;
  final challenges = <String>[];

  /// When set, a sign-in prompt stays open until it completes.
  Completer<void>? challengeGate;

  @override
  String? get address => _address;

  @override
  String? get network => _address == null ? null : stellarTestnetPassphrase;

  @override
  String get name => 'Test wallet';

  @override
  Uri? get installUrl => null;

  @override
  Future<String> connect() async => _address = 'GUSER123';

  @override
  Future<void> disconnect() async => _address = null;

  @override
  Future<String> signAuthEntry(String entryXdr) async => entryXdr;

  @override
  Future<String> signTransaction(String unsignedXdr) async => unsignedXdr;

  @override
  Future<String> signChallenge(SignInChallenge challenge) async {
    final failure = failNextChallenge;
    if (failure != null) {
      failNextChallenge = null;
      throw failure;
    }
    await challengeGate?.future;
    challenges.add(challenge.transactionXdr);
    return 'signed:${challenge.transactionXdr}';
  }
}

/// A session that signs in through the wallet and records what it saw.
class _SignIn implements WalletSignIn {
  _SignIn(this.controller);

  WalletController Function() controller;
  String? signedInAs;
  final statusDuringPrompt = <WalletStatus>[];

  /// When set, the server refuses the next sign-in with it.
  Object? serverFailure;

  @override
  Future<bool> isSignedInAs(String wallet) async => signedInAs == wallet;

  @override
  Future<void> ensureSignedIn(
    String wallet,
    Future<String> Function(SignInChallenge challenge) sign,
  ) async {
    if (signedInAs == wallet) return;
    final failure = serverFailure;
    if (failure != null) throw failure;
    final pending = sign(
      const SignInChallenge(
        transactionXdr: 'challenge',
        networkPassphrase: stellarTestnetPassphrase,
      ),
    );
    statusDuringPrompt.add(controller().status);
    await pending;
    signedInAs = wallet;
  }
}

void main() {
  late _Wallet wallet;
  late WalletController controller;
  late _SignIn signIn;

  setUp(() {
    wallet = _Wallet();
    signIn = _SignIn(() => controller);
    controller = WalletController(wallet, signIn: signIn);
  });

  test('connecting signs in once and the prompt shows as a sign-in', () async {
    final address = await controller.connect();

    expect(address, 'GUSER123');
    expect(wallet.challenges, ['challenge']);
    expect(signIn.statusDuringPrompt, [WalletStatus.signingIn]);
    expect(controller.status, WalletStatus.connected);
    expect(await controller.hasSession(), isTrue);

    await controller.ensureSession();
    expect(wallet.challenges, ['challenge']);
  });

  test('without a session store, connecting never prompts', () async {
    final plain = WalletController(wallet);

    await plain.connect();

    expect(wallet.challenges, isEmpty);
    expect(await plain.hasSession(), isTrue);
  });

  test('a declined sign-in fails the connect but keeps the wallet '
      'connected, and connecting again asks again', () async {
    wallet.failNextChallenge = const WalletSignatureRejected();

    await expectLater(
      controller.connect(),
      throwsA(isA<WalletSignatureRejected>()),
    );

    expect(controller.address, 'GUSER123');
    expect(controller.status, WalletStatus.rejected);
    expect(await controller.hasSession(), isFalse);

    expect(await controller.tryConnect(), isTrue);
    expect(wallet.challenges, ['challenge']);
    expect(await controller.hasSession(), isTrue);
  });

  test('a server failure during the sign-in still connects', () async {
    signIn.serverFailure = StateError('server down');

    expect(await controller.connect(), 'GUSER123');

    expect(wallet.challenges, isEmpty);
    expect(await controller.hasSession(), isFalse);
  });

  test('a transaction prompt still shows as signing', () async {
    await controller.connect();
    final pending = controller.signTransaction('AAAA');

    expect(controller.status, WalletStatus.signing);
    await pending;
  });
  test('a new session bumps sessionEpoch and notifies, so screens waiting '
      'for it reload', () async {
    var notified = 0;
    final epochs = <int>[];
    controller.addListener(() {
      notified++;
      epochs.add(controller.sessionEpoch);
    });
    final before = controller.sessionEpoch;

    await controller.connect();

    expect(controller.sessionEpoch, before + 1);
    expect(epochs.last, before + 1);
    final afterConnect = notified;

    await controller.ensureSession();
    expect(controller.sessionEpoch, before + 1);
    expect(notified, afterConnect);
  });

  test('a disconnect while the sign-in prompt is open drops the session it '
      'stored, and the connect fails', () async {
    var forgets = 0;
    controller = WalletController(
      wallet,
      signIn: signIn,
      onDisconnect: () async {
        forgets++;
        signIn.signedInAs = null;
      },
    );
    wallet.challengeGate = Completer<void>();

    final connecting = controller.connect();
    await pumpEventQueue();
    expect(controller.status, WalletStatus.signingIn);

    await controller.disconnect();
    wallet.challengeGate!.complete();

    await expectLater(connecting, throwsA(isA<WalletSignatureRejected>()));
    expect(signIn.signedInAs, isNull);
    expect(forgets, 2);
    expect(controller.address, isNull);
    expect(await controller.hasSession(), isFalse);
  });
}
