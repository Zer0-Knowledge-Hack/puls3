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

/// Server-prepared payload that the session wallet signs unchanged and
/// returns to the matching `submit…` method (server relay, Decision A).
abstract class PreparedTransaction implements _i1.SerializableModel {
  PreparedTransaction._({
    required this.preparationId,
    required this.purpose,
    required this.signer,
    required this.networkPassphrase,
    this.unsignedTransactionXdr,
    this.authorizationEntryXdr,
    this.transaction,
    this.signatureExpirationLedger,
    required this.expiresAt,
  });

  factory PreparedTransaction({
    required String preparationId,
    required String purpose,
    required String signer,
    required String networkPassphrase,
    String? unsignedTransactionXdr,
    String? authorizationEntryXdr,
    String? transaction,
    int? signatureExpirationLedger,
    required DateTime expiresAt,
  }) = _PreparedTransactionImpl;

  factory PreparedTransaction.fromJson(Map<String, dynamic> jsonSerialization) {
    return PreparedTransaction(
      preparationId: jsonSerialization['preparationId'] as String,
      purpose: jsonSerialization['purpose'] as String,
      signer: jsonSerialization['signer'] as String,
      networkPassphrase: jsonSerialization['networkPassphrase'] as String,
      unsignedTransactionXdr:
          jsonSerialization['unsignedTransactionXdr'] as String?,
      authorizationEntryXdr:
          jsonSerialization['authorizationEntryXdr'] as String?,
      transaction: jsonSerialization['transaction'] as String?,
      signatureExpirationLedger:
          jsonSerialization['signatureExpirationLedger'] as int?,
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  /// Opaque id the client echoes back when submitting the signed XDR.
  String preparationId;

  /// One of registerFull, setAgentWallet, createJob, fund, complete, reject,
  /// giveFeedback.
  String purpose;

  /// StellarAddress (StrKey) of the session wallet that must sign.
  String signer;

  /// Network passphrase the signature must cover.
  String networkPassphrase;

  /// Base64 unsigned TransactionEnvelope XDR, with the signer as source.
  /// Set for every purpose except setAgentWallet.
  String? unsignedTransactionXdr;

  /// Base64 SorobanAuthorizationEntry XDR with ADDRESS_V2 credentials for
  /// the signer. Set for setAgentWallet only.
  String? authorizationEntryXdr;

  /// Domain TransactionHash of the prepared envelope, when it is known at
  /// preparation time (every purpose except setAgentWallet, whose final hash
  /// also depends on the entry signature; the server fixes the rest of that
  /// envelope at preparation).
  String? transaction;

  /// Server-set, non-zero expiration ledger of the authorization entry.
  /// Set for setAgentWallet only.
  int? signatureExpirationLedger;

  /// After this instant the preparation can no longer be submitted.
  DateTime expiresAt;

  /// Returns a shallow copy of this [PreparedTransaction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  PreparedTransaction copyWith({
    String? preparationId,
    String? purpose,
    String? signer,
    String? networkPassphrase,
    String? unsignedTransactionXdr,
    String? authorizationEntryXdr,
    String? transaction,
    int? signatureExpirationLedger,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PreparedTransaction',
      'preparationId': preparationId,
      'purpose': purpose,
      'signer': signer,
      'networkPassphrase': networkPassphrase,
      if (unsignedTransactionXdr != null)
        'unsignedTransactionXdr': unsignedTransactionXdr,
      if (authorizationEntryXdr != null)
        'authorizationEntryXdr': authorizationEntryXdr,
      if (transaction != null) 'transaction': transaction,
      if (signatureExpirationLedger != null)
        'signatureExpirationLedger': signatureExpirationLedger,
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PreparedTransactionImpl extends PreparedTransaction {
  _PreparedTransactionImpl({
    required String preparationId,
    required String purpose,
    required String signer,
    required String networkPassphrase,
    String? unsignedTransactionXdr,
    String? authorizationEntryXdr,
    String? transaction,
    int? signatureExpirationLedger,
    required DateTime expiresAt,
  }) : super._(
         preparationId: preparationId,
         purpose: purpose,
         signer: signer,
         networkPassphrase: networkPassphrase,
         unsignedTransactionXdr: unsignedTransactionXdr,
         authorizationEntryXdr: authorizationEntryXdr,
         transaction: transaction,
         signatureExpirationLedger: signatureExpirationLedger,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [PreparedTransaction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  PreparedTransaction copyWith({
    String? preparationId,
    String? purpose,
    String? signer,
    String? networkPassphrase,
    Object? unsignedTransactionXdr = _Undefined,
    Object? authorizationEntryXdr = _Undefined,
    Object? transaction = _Undefined,
    Object? signatureExpirationLedger = _Undefined,
    DateTime? expiresAt,
  }) {
    return PreparedTransaction(
      preparationId: preparationId ?? this.preparationId,
      purpose: purpose ?? this.purpose,
      signer: signer ?? this.signer,
      networkPassphrase: networkPassphrase ?? this.networkPassphrase,
      unsignedTransactionXdr: unsignedTransactionXdr is String?
          ? unsignedTransactionXdr
          : this.unsignedTransactionXdr,
      authorizationEntryXdr: authorizationEntryXdr is String?
          ? authorizationEntryXdr
          : this.authorizationEntryXdr,
      transaction: transaction is String? ? transaction : this.transaction,
      signatureExpirationLedger: signatureExpirationLedger is int?
          ? signatureExpirationLedger
          : this.signatureExpirationLedger,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
