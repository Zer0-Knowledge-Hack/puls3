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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Durable server-side record of one relay or server-signed submission.
/// Polled through the resource that owns it; the client sees only the
/// fields without `scope=serverOnly`. Serverpod requires serverOnly fields to
/// be nullable; ChainSubmissionStore always sets them.
abstract class ChainSubmission
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ChainSubmission._({
    this.id,
    this.preparationId,
    required this.purpose,
    required this.transaction,
    required this.state,
    this.errorCode,
    this.explorerUrl,
    required this.updatedAt,
  });

  factory ChainSubmission({
    int? id,
    String? preparationId,
    required String purpose,
    required String transaction,
    required String state,
    String? errorCode,
    String? explorerUrl,
    required DateTime updatedAt,
  }) = _ChainSubmissionImpl;

  factory ChainSubmission.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChainSubmission(
      id: jsonSerialization['id'] as int?,
      preparationId: jsonSerialization['preparationId'] as String?,
      purpose: jsonSerialization['purpose'] as String,
      transaction: jsonSerialization['transaction'] as String,
      state: jsonSerialization['state'] as String,
      errorCode: jsonSerialization['errorCode'] as String?,
      explorerUrl: jsonSerialization['explorerUrl'] as String?,
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// The PreparedTransaction this submission came from. Null for
  /// server-signed purposes (submit, release, claimRefund).
  String? preparationId;

  /// One of registerFull, setAgentWallet, createJob, fund, complete, reject,
  /// giveFeedback (wallet-signed), or submit, release, claimRefund
  /// (server-signed).
  String purpose;

  /// Domain TransactionHash of the one envelope this record ever sends,
  /// persisted before it is submitted.
  String transaction;

  /// One of submitted, confirmed, failed.
  String state;

  /// Puls3ApiException code when state is failed, for example JobMismatch.
  /// Chain outcomes are reported here, never thrown by submit methods.
  String? errorCode;

  String? explorerUrl;

  DateTime updatedAt;

  /// Returns a shallow copy of this [ChainSubmission]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ChainSubmission copyWith({
    int? id,
    String? preparationId,
    String? purpose,
    String? transaction,
    String? state,
    String? errorCode,
    String? explorerUrl,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChainSubmission',
      if (id != null) 'id': id,
      if (preparationId != null) 'preparationId': preparationId,
      'purpose': purpose,
      'transaction': transaction,
      'state': state,
      if (errorCode != null) 'errorCode': errorCode,
      if (explorerUrl != null) 'explorerUrl': explorerUrl,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChainSubmission',
      if (id != null) 'id': id,
      if (preparationId != null) 'preparationId': preparationId,
      'purpose': purpose,
      'transaction': transaction,
      'state': state,
      if (errorCode != null) 'errorCode': errorCode,
      if (explorerUrl != null) 'explorerUrl': explorerUrl,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChainSubmissionImpl extends ChainSubmission {
  _ChainSubmissionImpl({
    int? id,
    String? preparationId,
    required String purpose,
    required String transaction,
    required String state,
    String? errorCode,
    String? explorerUrl,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         preparationId: preparationId,
         purpose: purpose,
         transaction: transaction,
         state: state,
         errorCode: errorCode,
         explorerUrl: explorerUrl,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [ChainSubmission]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ChainSubmission copyWith({
    Object? id = _Undefined,
    Object? preparationId = _Undefined,
    String? purpose,
    String? transaction,
    String? state,
    Object? errorCode = _Undefined,
    Object? explorerUrl = _Undefined,
    DateTime? updatedAt,
  }) {
    return ChainSubmission(
      id: id is int? ? id : this.id,
      preparationId: preparationId is String?
          ? preparationId
          : this.preparationId,
      purpose: purpose ?? this.purpose,
      transaction: transaction ?? this.transaction,
      state: state ?? this.state,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      explorerUrl: explorerUrl is String? ? explorerUrl : this.explorerUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
