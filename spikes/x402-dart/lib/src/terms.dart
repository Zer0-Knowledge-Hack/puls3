import 'dart:convert';

/// One entry of `accepts` in an x402 v2 `PAYMENT-REQUIRED` header.
final class PaymentRequirements {
  PaymentRequirements(this.json);

  /// The entry as the server sent it. It is echoed back as `accepted`.
  final Map<String, Object?> json;

  String get scheme => _string('scheme');
  String get network => _string('network');
  String get asset => _string('asset');
  String get payTo => _string('payTo');
  String get amountText => _string('amount');

  /// The amount in the asset's smallest unit (stroops for USDC).
  BigInt get amount {
    final value = BigInt.tryParse(amountText);
    if (value == null ||
        value <= BigInt.zero ||
        amountText.trim() != amountText) {
      throw FormatException('amount is not a positive integer: $amountText');
    }
    return value;
  }

  int get maxTimeoutSeconds {
    final value = json['maxTimeoutSeconds'];
    if (value is int && value > 0) return value;
    throw FormatException(
      'maxTimeoutSeconds is not a positive integer: $value',
    );
  }

  bool get feesSponsored {
    final extra = json['extra'];
    return extra is Map && extra['areFeesSponsored'] == true;
  }

  String _string(String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('$key is missing or not a string');
  }
}

/// The decoded `PAYMENT-REQUIRED` header of a 402 response.
final class PaymentRequired {
  PaymentRequired._(this.x402Version, this.resource, this.accepts);

  final int x402Version;
  final Map<String, Object?>? resource;
  final List<PaymentRequirements> accepts;

  /// Decodes the base64 JSON header value. Throws [FormatException].
  factory PaymentRequired.decodeHeader(String header) {
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(base64.decode(header.trim())));
    } on Object {
      throw const FormatException('PAYMENT-REQUIRED is not base64 JSON');
    }
    if (body is! Map<String, Object?>) {
      throw const FormatException('PAYMENT-REQUIRED is not a JSON object');
    }
    final version = body['x402Version'];
    final accepts = body['accepts'];
    final resource = body['resource'];
    if (version is! int) {
      throw const FormatException('x402Version is missing');
    }
    if (accepts is! List) {
      throw const FormatException('accepts is missing');
    }
    return PaymentRequired._(
      version,
      resource is Map<String, Object?> ? resource : null,
      [
        for (final entry in accepts)
          if (entry is Map<String, Object?>) PaymentRequirements(entry),
      ],
    );
  }
}

/// Thrown when no offered terms pass the [PaymentPolicy]. Nothing was signed.
final class TermsRejected implements Exception {
  TermsRejected(this.reasons);

  /// One reason per offered entry, in the server's order.
  final List<String> reasons;

  @override
  String toString() => 'TermsRejected: ${reasons.join('; ')}';
}

/// What the client agrees to pay, checked before any signature.
final class PaymentPolicy {
  PaymentPolicy({
    required this.network,
    required this.assets,
    required this.payTo,
    required this.maxAmount,
    this.maxTimeoutSeconds = 600,
  });

  /// The CAIP-2 network, for example `stellar:testnet`.
  final String network;

  /// Allowed SAC contract ids (`C…`).
  final Set<String> assets;

  /// Allowed recipients (`G…`).
  final Set<String> payTo;

  /// The largest amount accepted for one call, in stroops.
  final BigInt maxAmount;

  /// The longest signature lifetime accepted.
  final int maxTimeoutSeconds;

  /// The first entry of [required] that passes, or throws [TermsRejected].
  PaymentRequirements choose(PaymentRequired required) {
    final reasons = <String>[];
    if (required.x402Version != 2) {
      throw TermsRejected(['unsupported x402Version ${required.x402Version}']);
    }
    for (final terms in required.accepts) {
      final reason = _reject(terms);
      if (reason == null) return terms;
      reasons.add(reason);
    }
    if (reasons.isEmpty) reasons.add('no payment terms offered');
    throw TermsRejected(reasons);
  }

  String? _reject(PaymentRequirements terms) {
    try {
      if (terms.scheme != 'exact') return 'scheme ${terms.scheme} is not exact';
      if (terms.network != network) {
        return 'network ${terms.network} is not $network';
      }
      if (!assets.contains(terms.asset)) {
        return 'asset ${terms.asset} is not allowed';
      }
      if (!payTo.contains(terms.payTo)) {
        return 'payTo ${terms.payTo} is not allowed';
      }
      if (terms.amount > maxAmount) {
        return 'amount ${terms.amount} is above the maximum $maxAmount';
      }
      if (terms.maxTimeoutSeconds > maxTimeoutSeconds) {
        return 'maxTimeoutSeconds ${terms.maxTimeoutSeconds} is above '
            '$maxTimeoutSeconds';
      }
      if (!terms.feesSponsored) return 'fees are not sponsored';
      return null;
    } on FormatException catch (e) {
      return 'malformed terms: ${e.message}';
    }
  }
}
