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

import 'package:serverpod_client/serverpod_client.dart' as _i1;

/// Draft transport mirror of the domain Payment entity.
/// Built by the server only after the funded escrow job passes every
/// funding verification check (docs/architecture/api.md, ADR-0005).
abstract class Payment implements _i1.SerializableModel {
  Payment._({
    required this.transaction,
    required this.hireId,
    required this.payer,
    required this.payee,
    required this.amount,
  });

  factory Payment({
    required String transaction,
    required int hireId,
    required String payer,
    required String payee,
    required int amount,
  }) = _PaymentImpl;

  factory Payment.fromJson(Map<String, dynamic> jsonSerialization) {
    return Payment(
      transaction: jsonSerialization['transaction'] as String,
      hireId: jsonSerialization['hireId'] as int,
      payer: jsonSerialization['payer'] as String,
      payee: jsonSerialization['payee'] as String,
      amount: jsonSerialization['amount'] as int,
    );
  }

  /// Domain TransactionHash of the `fund` transaction, lowercase hexadecimal.
  String transaction;

  /// Domain HireId encoded as an integer.
  int hireId;

  /// Domain StellarAddress encoded as a StrKey string. The job's client.
  String payer;

  /// Domain StellarAddress encoded as a StrKey string. The job's provider
  /// (agent wallet); the escrow pays it on complete.
  String payee;

  /// Domain UsdcAmount encoded as integer USDC stroops. The job's budget.
  int amount;

  /// Returns a shallow copy of this [Payment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Payment copyWith({
    String? transaction,
    int? hireId,
    String? payer,
    String? payee,
    int? amount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Payment',
      'transaction': transaction,
      'hireId': hireId,
      'payer': payer,
      'payee': payee,
      'amount': amount,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _PaymentImpl extends Payment {
  _PaymentImpl({
    required String transaction,
    required int hireId,
    required String payer,
    required String payee,
    required int amount,
  }) : super._(
         transaction: transaction,
         hireId: hireId,
         payer: payer,
         payee: payee,
         amount: amount,
       );

  /// Returns a shallow copy of this [Payment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Payment copyWith({
    String? transaction,
    int? hireId,
    String? payer,
    String? payee,
    int? amount,
  }) {
    return Payment(
      transaction: transaction ?? this.transaction,
      hireId: hireId ?? this.hireId,
      payer: payer ?? this.payer,
      payee: payee ?? this.payee,
      amount: amount ?? this.amount,
    );
  }
}
