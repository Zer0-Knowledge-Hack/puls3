import 'dart:io';

import 'package:test/test.dart';
import 'package:x402_dart_spike/x402_dart.dart';

import '../bin/pay.dart' as cli;
import 'support.dart';

void main() {
  late Directory dir;
  late String secret;
  late File keyFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('x402-cli-');
    secret = testSecret();
    keyFile = File('${dir.path}/payer.secret')..writeAsStringSync('$secret\n');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<(int, String)> run(List<String> args, {FakeRpc? rpc}) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final payer = SecretKeySigner.fromSecret(secret).address;
    final code = await cli.run(
      args,
      out,
      err,
      httpClient: FakeResourceServer([terms()]).client,
      rpc: rpc ?? FakeRpc(payer: payer, invocation: tiaInvocation(payer)),
    );
    return (code, '$out$err');
  }

  test('a paid call prints the receipt and never the secret', () async {
    final (code, output) = await run([
      '--secret-file',
      keyFile.path,
      'https://tia.test/v1/quote?amount=100',
    ]);
    expect(code, 0);
    expect(output, contains('settled true'));
    expect(output, contains('stellar.expert/explorer/testnet/tx/'));
    expect(output, isNot(contains(secret)));
  });

  test('a refused payment never prints the secret', () async {
    final (code, output) = await run([
      '--secret-file',
      keyFile.path,
      '--max-amount',
      '1',
      'https://tia.test/v1/quote?amount=100',
    ]);
    expect(code, 2);
    expect(output, contains('refused to pay'));
    expect(output, isNot(contains(secret)));
  });

  test('a malformed key file is not echoed', () async {
    final bogus = '${secret.substring(0, 50)}XXXXXX';
    keyFile.writeAsStringSync(bogus);
    final (code, output) = await run([
      '--secret-file',
      keyFile.path,
      'https://tia.test/v1/quote',
    ]);
    expect(code, 65);
    expect(output, isNot(contains(bogus)));
    expect(output, isNot(contains(secret.substring(0, 20))));
  });
}
