/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

/// A draft price. [asset] is USDC and [amount] is stroops.
abstract class ManifestPrice
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ManifestPrice._({
    required this.asset,
    required this.amount,
  });

  factory ManifestPrice({
    required String asset,
    required int amount,
  }) = _ManifestPriceImpl;

  factory ManifestPrice.fromJson(Map<String, dynamic> jsonSerialization) {
    return ManifestPrice(
      asset: jsonSerialization['asset'] as String,
      amount: jsonSerialization['amount'] as int,
    );
  }

  String asset;

  int amount;

  /// Returns a shallow copy of this [ManifestPrice]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ManifestPrice copyWith({
    String? asset,
    int? amount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ManifestPrice',
      'asset': asset,
      'amount': amount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ManifestPrice',
      'asset': asset,
      'amount': amount,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _ManifestPriceImpl extends ManifestPrice {
  _ManifestPriceImpl({
    required String asset,
    required int amount,
  }) : super._(
         asset: asset,
         amount: amount,
       );

  /// Returns a shallow copy of this [ManifestPrice]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ManifestPrice copyWith({
    String? asset,
    int? amount,
  }) {
    return ManifestPrice(
      asset: asset ?? this.asset,
      amount: amount ?? this.amount,
    );
  }
}
