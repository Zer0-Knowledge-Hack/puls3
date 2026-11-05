import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:x402_dart_spike/x402_dart.dart';

const _usage = '''
Pays one x402 `exact` call on Stellar Testnet from Dart.

Usage: dart run bin/pay.dart --secret-file <file> [options] <url>

  --secret-file <file>   A file that holds the payer's testnet S… key.
  --max-amount <stroops> The most one call may cost (default 2500000 = 0.25 USDC).
  --pay-to <G…>          An allowed recipient (default: TIA's testnet payTo).
  --asset <C…>           An allowed asset (default: testnet USDC SAC).
  --rpc <url>            Soroban RPC (default: https://soroban-testnet.stellar.org).
''';

const _tiaPayTo = 'GB6GCGWLKAMGQI2D7VIO2VLZFREBJBGCAP7E7ZGXHWWNZIXWLPX5YO7Q';
const _testnetUsdc = 'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA';

Future<void> main(List<String> args) async {
  exitCode = await run(args, stdout, stderr);
}

/// Runs the command, writing to [out] and [err]. Returns the exit code.
///
/// Tests pass [httpClient] and [rpc] to run without the network.
Future<int> run(
  List<String> args,
  StringSink out,
  StringSink err, {
  http.Client? httpClient,
  SorobanRpc? rpc,
}) async {
  final options = <String, String>{};
  String? url;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--')) {
      if (i + 1 >= args.length) {
        err.writeln('$arg needs a value\n\n$_usage');
        return 64;
      }
      options[arg.substring(2)] = args[++i];
    } else {
      url = arg;
    }
  }
  final secretFile = options['secret-file'];
  if (url == null || secretFile == null) {
    err.write(_usage);
    return 64;
  }

  final AuthSigner signer;
  try {
    signer = SecretKeySigner.fromSecret(File(secretFile).readAsStringSync());
  } on FileSystemException {
    err.writeln('cannot read the secret key file');
    return 66;
  } on FormatException catch (e) {
    err.writeln(e.message);
    return 65;
  }

  final client = X402Client(
    signer: signer,
    policy: PaymentPolicy(
      network: 'stellar:testnet',
      assets: {options['asset'] ?? _testnetUsdc},
      payTo: {options['pay-to'] ?? _tiaPayTo},
      maxAmount: BigInt.parse(options['max-amount'] ?? '2500000'),
    ),
    rpc:
        rpc ??
        HttpSorobanRpc(
          Uri.parse(options['rpc'] ?? 'https://soroban-testnet.stellar.org'),
        ),
    httpClient: httpClient,
  );

  out.writeln('payer   ${signer.address}');
  try {
    final result = await client.get(Uri.parse(url));
    final terms = result.terms;
    if (terms != null) {
      out
        ..writeln('paid    ${terms.amount} stroops of ${terms.asset}')
        ..writeln('to      ${terms.payTo} on ${terms.network}')
        ..writeln(
          'ledger  ${result.ledgerAtSigning}, signature expires at '
          '${result.expirationLedger}',
        );
    }
    out.writeln('status  ${result.response.statusCode}');
    final payment = result.payment;
    if (payment != null) {
      out.writeln('settled ${payment.success} tx ${payment.transaction}');
      if (payment.transaction case final hash? when hash.isNotEmpty) {
        out.writeln(
          'explorer https://stellar.expert/explorer/testnet/tx/$hash',
        );
      }
    }
    out.writeln(result.response.body);
    return result.response.statusCode == 200 ? 0 : 1;
  } on TermsRejected catch (e) {
    err.writeln('refused to pay: ${e.reasons.join('; ')}');
    return 2;
  } on UnexpectedAuthorization catch (e) {
    err.writeln('refused to sign: ${e.message}');
    return 2;
  } on SimulationFailed catch (e) {
    err.writeln('simulation failed: ${e.message}');
    return 1;
  } on Object catch (e) {
    err.writeln('failed: $e');
    return 1;
  }
}
