import 'errors.dart';

/// An amount of USDC in stroops: 1 USDC = 10,000,000 stroops (7 decimals).
///
/// Always an integer, never a floating-point number. The upper bound is 2^53 - 1 so the
/// same value is exact when the domain runs on the web.
final class UsdcAmount implements Comparable<UsdcAmount> {
  const UsdcAmount._(this.stroops);

  factory UsdcAmount.stroops(int stroops) {
    if (stroops < 0 || stroops > maxStroops) throw InvalidAmount(stroops);
    return UsdcAmount._(stroops);
  }

  static const stroopsPerUsdc = 10000000;
  static const maxStroops = 9007199254740991;
  static const zero = UsdcAmount._(0);

  final int stroops;

  bool get isPositive => stroops > 0;

  @override
  int compareTo(UsdcAmount other) => stroops.compareTo(other.stroops);

  @override
  bool operator ==(Object other) =>
      other is UsdcAmount && other.stroops == stroops;

  @override
  int get hashCode => stroops.hashCode;

  @override
  String toString() => '$stroops stroops';
}

/// The on-chain id of an agent in the Identity Registry: a `u32` (ADR-0002).
final class AgentId {
  AgentId(this.value) {
    if (value < 0 || value > 4294967295) throw InvalidAgentId(value);
  }

  final int value;

  @override
  bool operator ==(Object other) => other is AgentId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'agent $value';
}

/// The id of a hire. It travels as the muxed id of the payment (ADR-0003),
/// capped at 2^53 - 1 so it is exact on the web.
final class HireId {
  HireId(this.value) {
    if (value < 1 || value > 9007199254740991) throw InvalidHireId(value);
  }

  final int value;

  @override
  bool operator ==(Object other) => other is HireId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'hire $value';
}

/// A Stellar transaction hash: 64 lowercase hexadecimal characters.
final class TransactionHash {
  const TransactionHash._(this.value);

  factory TransactionHash.parse(String input) {
    if (!_hex64.hasMatch(input)) throw const InvalidTransactionHash();
    return TransactionHash._(input);
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      other is TransactionHash && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final _hex64 = RegExp(r'^[0-9a-f]{64}$');
