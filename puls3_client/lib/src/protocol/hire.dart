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

/// Draft transport mirror of the domain Hire entity (ADR-0005 D6, #73).
abstract class Hire
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Hire._({
    required this.id,
    required this.agentId,
    required this.consumer,
    required this.price,
    required this.manifestVersion,
    this.status,
    this.paymentTransaction,
    this.runtimeStatus,
    this.failureReason,
    this.rejectedFrom,
    this.feedbackReference,
  });

  factory Hire({
    required int id,
    required int agentId,
    required String consumer,
    required int price,
    required int manifestVersion,
    String? status,
    String? paymentTransaction,
    String? runtimeStatus,
    String? failureReason,
    String? rejectedFrom,
    String? feedbackReference,
  }) = _HireImpl;

  factory Hire.fromJson(Map<String, dynamic> jsonSerialization) {
    return Hire(
      id: jsonSerialization['id'] as int,
      agentId: jsonSerialization['agentId'] as int,
      consumer: jsonSerialization['consumer'] as String,
      price: jsonSerialization['price'] as int,
      manifestVersion: jsonSerialization['manifestVersion'] as int,
      status: jsonSerialization['status'] as String?,
      paymentTransaction: jsonSerialization['paymentTransaction'] as String?,
      runtimeStatus: jsonSerialization['runtimeStatus'] as String?,
      failureReason: jsonSerialization['failureReason'] as String?,
      rejectedFrom: jsonSerialization['rejectedFrom'] as String?,
      feedbackReference: jsonSerialization['feedbackReference'] as String?,
    );
  }

  /// Domain HireId encoded as an integer.
  int id;

  /// Domain AgentId encoded as an integer.
  int agentId;

  /// Domain StellarAddress encoded as a StrKey string.
  String consumer;

  /// Domain UsdcAmount encoded as integer USDC stroops.
  int price;

  int manifestVersion;

  /// HireStatus enum name: open, funded, submitted, completed, rejected,
  /// expired. Mirrors the ERC-8183 escrow job state. Null until create_job is
  /// confirmed (no on-chain job yet). expired is also derived for an unfunded
  /// open job past expired_at.
  String? status;

  /// Domain TransactionHash of the confirmed `fund` transaction, lowercase hex.
  String? paymentTransaction;

  /// RuntimeStatus enum name: queued, running, failed. Runtime progress while
  /// the hire is funded; not a hire state.
  String? runtimeStatus;

  /// Safe runtime failure reason when runtimeStatus is failed.
  String? failureReason;

  /// HireStatus the reject came from (open, funded, submitted) when status is
  /// rejected. The app labels a reject from open as "Cancelled".
  String? rejectedFrom;

  /// Reference to the confirmed ERC-8004 feedback for this hire, for example
  /// the give_feedback transaction hash. Replaces the former rated state.
  String? feedbackReference;

  /// Returns a shallow copy of this [Hire]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Hire copyWith({
    int? id,
    int? agentId,
    String? consumer,
    int? price,
    int? manifestVersion,
    String? status,
    String? paymentTransaction,
    String? runtimeStatus,
    String? failureReason,
    String? rejectedFrom,
    String? feedbackReference,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Hire',
      'id': id,
      'agentId': agentId,
      'consumer': consumer,
      'price': price,
      'manifestVersion': manifestVersion,
      if (status != null) 'status': status,
      if (paymentTransaction != null) 'paymentTransaction': paymentTransaction,
      if (runtimeStatus != null) 'runtimeStatus': runtimeStatus,
      if (failureReason != null) 'failureReason': failureReason,
      if (rejectedFrom != null) 'rejectedFrom': rejectedFrom,
      if (feedbackReference != null) 'feedbackReference': feedbackReference,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Hire',
      'id': id,
      'agentId': agentId,
      'consumer': consumer,
      'price': price,
      'manifestVersion': manifestVersion,
      if (status != null) 'status': status,
      if (paymentTransaction != null) 'paymentTransaction': paymentTransaction,
      if (runtimeStatus != null) 'runtimeStatus': runtimeStatus,
      if (failureReason != null) 'failureReason': failureReason,
      if (rejectedFrom != null) 'rejectedFrom': rejectedFrom,
      if (feedbackReference != null) 'feedbackReference': feedbackReference,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HireImpl extends Hire {
  _HireImpl({
    required int id,
    required int agentId,
    required String consumer,
    required int price,
    required int manifestVersion,
    String? status,
    String? paymentTransaction,
    String? runtimeStatus,
    String? failureReason,
    String? rejectedFrom,
    String? feedbackReference,
  }) : super._(
         id: id,
         agentId: agentId,
         consumer: consumer,
         price: price,
         manifestVersion: manifestVersion,
         status: status,
         paymentTransaction: paymentTransaction,
         runtimeStatus: runtimeStatus,
         failureReason: failureReason,
         rejectedFrom: rejectedFrom,
         feedbackReference: feedbackReference,
       );

  /// Returns a shallow copy of this [Hire]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Hire copyWith({
    int? id,
    int? agentId,
    String? consumer,
    int? price,
    int? manifestVersion,
    Object? status = _Undefined,
    Object? paymentTransaction = _Undefined,
    Object? runtimeStatus = _Undefined,
    Object? failureReason = _Undefined,
    Object? rejectedFrom = _Undefined,
    Object? feedbackReference = _Undefined,
  }) {
    return Hire(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      consumer: consumer ?? this.consumer,
      price: price ?? this.price,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      status: status is String? ? status : this.status,
      paymentTransaction: paymentTransaction is String?
          ? paymentTransaction
          : this.paymentTransaction,
      runtimeStatus: runtimeStatus is String?
          ? runtimeStatus
          : this.runtimeStatus,
      failureReason: failureReason is String?
          ? failureReason
          : this.failureReason,
      rejectedFrom: rejectedFrom is String? ? rejectedFrom : this.rejectedFrom,
      feedbackReference: feedbackReference is String?
          ? feedbackReference
          : this.feedbackReference,
    );
  }
}
