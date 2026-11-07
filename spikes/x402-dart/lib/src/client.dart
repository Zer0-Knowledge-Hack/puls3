import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'rpc.dart';
import 'signer.dart';
import 'soroban.dart';
import 'terms.dart';

const _networkPassphrases = {
  'stellar:testnet': 'Test SDF Network ; September 2015',
  'stellar:pubnet': 'Public Global Stellar Network ; September 2015',
};

/// The inclusion fee of the payload transaction. The facilitator rebuilds
/// the transaction and pays its own fee, so this only has to simulate.
const _baseFee = 100;

/// The decoded `PAYMENT-RESPONSE` header.
final class PaymentResponse {
  PaymentResponse(this.json);

  final Map<String, Object?> json;

  bool get success => json['success'] == true;
  String? get transaction => json['transaction'] as String?;
  String? get network => json['network'] as String?;
  String? get payer => json['payer'] as String?;
}

/// What one paid call returned.
final class PaidResult {
  PaidResult({
    required this.response,
    required this.terms,
    required this.expirationLedger,
    required this.ledgerAtSigning,
    this.payment,
  });

  final http.Response response;

  /// The terms that were paid, or null when the server did not ask for
  /// payment.
  final PaymentRequirements? terms;
  final int? expirationLedger;
  final int? ledgerAtSigning;
  final PaymentResponse? payment;
}

/// A Dart x402 v2 client for the Stellar `exact` scheme.
///
/// It reads the 402 terms, checks them against [policy], simulates the SAC
/// `transfer`, signs the payer's authorization entry and retries with
/// `PAYMENT-SIGNATURE`. A facilitator on the server side settles.
final class X402Client {
  X402Client({
    required this.signer,
    required this.policy,
    required this.rpc,
    http.Client? httpClient,
    DateTime Function()? clock,
  }) : _http = httpClient ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final AuthSigner signer;
  final PaymentPolicy policy;
  final SorobanRpc rpc;
  final http.Client _http;
  final DateTime Function() _clock;

  Future<PaidResult> get(Uri url) async {
    final first = await _http.get(url);
    if (first.statusCode != 402) {
      return PaidResult(
        response: first,
        terms: null,
        expirationLedger: null,
        ledgerAtSigning: null,
      );
    }
    final header = first.headers['payment-required'];
    if (header == null) {
      throw const FormatException('402 without a PAYMENT-REQUIRED header');
    }
    final required = PaymentRequired.decodeHeader(header);
    final terms = policy.choose(required);

    final signed = await _buildPayment(terms);
    final payload = {
      'x402Version': required.x402Version,
      'resource': ?required.resource,
      'accepted': terms.json,
      'payload': {'transaction': base64.encode(signed.envelope)},
    };
    final paid = await _http.get(
      url,
      headers: {
        'PAYMENT-SIGNATURE': base64.encode(utf8.encode(jsonEncode(payload))),
      },
    );
    final receipt = paid.headers['payment-response'];
    return PaidResult(
      response: paid,
      terms: terms,
      expirationLedger: signed.expirationLedger,
      ledgerAtSigning: signed.ledgerAtSigning,
      payment: receipt == null
          ? null
          : PaymentResponse(
              jsonDecode(utf8.decode(base64.decode(receipt)))
                  as Map<String, Object?>,
            ),
    );
  }

  Future<_SignedPayment> _buildPayment(PaymentRequirements terms) async {
    final passphrase = _networkPassphrases[terms.network];
    if (passphrase == null) {
      throw TermsRejected(['unknown network ${terms.network}']);
    }
    final transfer = SacTransfer(
      asset: terms.asset,
      from: signer.address,
      to: terms.payTo,
      amount: terms.amount,
    );
    final maxTime =
        _clock().millisecondsSinceEpoch ~/ 1000 + terms.maxTimeoutSeconds;

    final recorded = await rpc.simulate(
      transfer.envelope(fee: _baseFee, maxTime: maxTime),
    );
    final entry = _onlyExpectedEntry(recorded.auth, transfer);

    final ledger = await rpc.latestLedger();
    final closeSeconds = await rpc.ledgerCloseSeconds();
    // Rounded down, so the signature never outlives maxTimeoutSeconds.
    final expiration = ledger + terms.maxTimeoutSeconds ~/ closeSeconds;
    final signedEntry = entry.sign(signer, networkId(passphrase), expiration);

    // Re-simulate with the signature: verifying it costs resources the
    // recording run did not count.
    final enforced = await rpc.simulate(
      transfer.envelope(
        fee: _baseFee + recorded.minResourceFee,
        maxTime: maxTime,
        auth: [signedEntry],
        sorobanData: recorded.transactionData,
      ),
    );
    final envelope = transfer.envelope(
      fee: _baseFee + enforced.minResourceFee,
      maxTime: maxTime,
      auth: [signedEntry],
      sorobanData: enforced.transactionData,
    );
    return _SignedPayment(envelope, expiration, ledger);
  }

  /// The one entry the payer must sign, checked before signing: it must be
  /// for the payer's account and authorize exactly [transfer].
  AuthEntry _onlyExpectedEntry(List<Uint8List> auth, SacTransfer transfer) {
    if (auth.length != 1) {
      throw UnexpectedAuthorization('${auth.length} auth entries, expected 1');
    }
    final entry = AuthEntry.parse(auth.single);
    if (!sameBytes(entry.address, signer.publicKey)) {
      throw UnexpectedAuthorization('the entry is not for the payer');
    }
    if (!sameBytes(entry.invocation, transfer.expectedInvocation())) {
      throw UnexpectedAuthorization(
        'the entry authorizes something other than the transfer',
      );
    }
    return entry;
  }
}

final class _SignedPayment {
  _SignedPayment(this.envelope, this.expirationLedger, this.ledgerAtSigning);

  final Uint8List envelope;
  final int expirationLedger;
  final int ledgerAtSigning;
}
