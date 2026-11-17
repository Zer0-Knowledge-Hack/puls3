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

/// One row of the consumer's hire list (`HireEndpoint.listMyHires`).
abstract class HireSummary
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  HireSummary._({
    required this.id,
    required this.agentId,
    required this.agentName,
    this.status,
    required this.priceUsdcStroops,
    required this.inputPreview,
    this.approvalDeadline,
    required this.needsAction,
    this.paidByAgentId,
    this.paidByAgentName,
  });

  factory HireSummary({
    required int id,
    required int agentId,
    required String agentName,
    String? status,
    required int priceUsdcStroops,
    required String inputPreview,
    DateTime? approvalDeadline,
    required bool needsAction,
    int? paidByAgentId,
    String? paidByAgentName,
  }) = _HireSummaryImpl;

  factory HireSummary.fromJson(Map<String, dynamic> jsonSerialization) {
    return HireSummary(
      id: jsonSerialization['id'] as int,
      agentId: jsonSerialization['agentId'] as int,
      agentName: jsonSerialization['agentName'] as String,
      status: jsonSerialization['status'] as String?,
      priceUsdcStroops: jsonSerialization['priceUsdcStroops'] as int,
      inputPreview: jsonSerialization['inputPreview'] as String,
      approvalDeadline: jsonSerialization['approvalDeadline'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['approvalDeadline'],
            ),
      needsAction: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['needsAction'],
      ),
      paidByAgentId: jsonSerialization['paidByAgentId'] as int?,
      paidByAgentName: jsonSerialization['paidByAgentName'] as String?,
    );
  }

  int id;

  /// The on-chain registry id of the hired agent.
  int agentId;

  String agentName;

  /// `HireStatus` name; null until the create_job is confirmed.
  String? status;

  int priceUsdcStroops;

  /// The first characters of the hire input.
  String inputPreview;

  /// The job's approval_deadline, set once the agent submitted.
  DateTime? approvalDeadline;

  /// The consumer must act: approve or reject a submitted hire before its
  /// deadline, or reject a funded hire whose run failed to get a refund.
  bool needsAction;

  /// The registry id of the user's Studio agent that hired and paid from its
  /// own wallet; null for the session wallet's own hires.
  int? paidByAgentId;

  /// That agent's name, for "Paid by your agent X".
  String? paidByAgentName;

  /// Returns a shallow copy of this [HireSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  HireSummary copyWith({
    int? id,
    int? agentId,
    String? agentName,
    String? status,
    int? priceUsdcStroops,
    String? inputPreview,
    DateTime? approvalDeadline,
    bool? needsAction,
    int? paidByAgentId,
    String? paidByAgentName,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireSummary',
      'id': id,
      'agentId': agentId,
      'agentName': agentName,
      if (status != null) 'status': status,
      'priceUsdcStroops': priceUsdcStroops,
      'inputPreview': inputPreview,
      if (approvalDeadline != null)
        'approvalDeadline': approvalDeadline?.toJson(),
      'needsAction': needsAction,
      if (paidByAgentId != null) 'paidByAgentId': paidByAgentId,
      if (paidByAgentName != null) 'paidByAgentName': paidByAgentName,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HireSummary',
      'id': id,
      'agentId': agentId,
      'agentName': agentName,
      if (status != null) 'status': status,
      'priceUsdcStroops': priceUsdcStroops,
      'inputPreview': inputPreview,
      if (approvalDeadline != null)
        'approvalDeadline': approvalDeadline?.toJson(),
      'needsAction': needsAction,
      if (paidByAgentId != null) 'paidByAgentId': paidByAgentId,
      if (paidByAgentName != null) 'paidByAgentName': paidByAgentName,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HireSummaryImpl extends HireSummary {
  _HireSummaryImpl({
    required int id,
    required int agentId,
    required String agentName,
    String? status,
    required int priceUsdcStroops,
    required String inputPreview,
    DateTime? approvalDeadline,
    required bool needsAction,
    int? paidByAgentId,
    String? paidByAgentName,
  }) : super._(
         id: id,
         agentId: agentId,
         agentName: agentName,
         status: status,
         priceUsdcStroops: priceUsdcStroops,
         inputPreview: inputPreview,
         approvalDeadline: approvalDeadline,
         needsAction: needsAction,
         paidByAgentId: paidByAgentId,
         paidByAgentName: paidByAgentName,
       );

  /// Returns a shallow copy of this [HireSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  HireSummary copyWith({
    int? id,
    int? agentId,
    String? agentName,
    Object? status = _Undefined,
    int? priceUsdcStroops,
    String? inputPreview,
    Object? approvalDeadline = _Undefined,
    bool? needsAction,
    Object? paidByAgentId = _Undefined,
    Object? paidByAgentName = _Undefined,
  }) {
    return HireSummary(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      status: status is String? ? status : this.status,
      priceUsdcStroops: priceUsdcStroops ?? this.priceUsdcStroops,
      inputPreview: inputPreview ?? this.inputPreview,
      approvalDeadline: approvalDeadline is DateTime?
          ? approvalDeadline
          : this.approvalDeadline,
      needsAction: needsAction ?? this.needsAction,
      paidByAgentId: paidByAgentId is int? ? paidByAgentId : this.paidByAgentId,
      paidByAgentName: paidByAgentName is String?
          ? paidByAgentName
          : this.paidByAgentName,
    );
  }
}
