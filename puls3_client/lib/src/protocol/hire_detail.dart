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
import 'package:puls3_client/src/protocol/protocol.dart' as _ihzwmcdm;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'agent/agent_summary.dart' as _ipe500bk;
import 'chain/chain_submission.dart' as _iz6hnyrm;
import 'hire.dart' as _ibbrviw7;
import 'payment.dart' as _ikmm2vup;

/// Everything the app shows about one hire (docs/architecture/api.md,
/// "Response shapes not copied from the domain").
abstract class HireDetail
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  HireDetail._({
    required this.hire,
    required this.agent,
    required this.input,
    this.result,
    this.payment,
    this.jobId,
    this.expiresAt,
    this.approvalDeadline,
    this.rejectReason,
    this.escrowSubmission,
    this.feedbackSubmission,
    this.paymentExplorerUrl,
  });

  factory HireDetail({
    required _ibbrviw7.Hire hire,
    required _ipe500bk.AgentSummary agent,
    required String input,
    String? result,
    _ikmm2vup.Payment? payment,
    int? jobId,
    DateTime? expiresAt,
    DateTime? approvalDeadline,
    String? rejectReason,
    _iz6hnyrm.ChainSubmission? escrowSubmission,
    _iz6hnyrm.ChainSubmission? feedbackSubmission,
    String? paymentExplorerUrl,
  }) = _HireDetailImpl;

  factory HireDetail.fromJson(Map<String, dynamic> jsonSerialization) {
    return HireDetail(
      hire: _ihzwmcdm.Protocol().deserialize<_ibbrviw7.Hire>(
        jsonSerialization['hire'],
      ),
      agent: _ihzwmcdm.Protocol().deserialize<_ipe500bk.AgentSummary>(
        jsonSerialization['agent'],
      ),
      input: jsonSerialization['input'] as String,
      result: jsonSerialization['result'] as String?,
      payment: jsonSerialization['payment'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<_ikmm2vup.Payment>(
              jsonSerialization['payment'],
            ),
      jobId: jsonSerialization['jobId'] as int?,
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
      approvalDeadline: jsonSerialization['approvalDeadline'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['approvalDeadline'],
            ),
      rejectReason: jsonSerialization['rejectReason'] as String?,
      escrowSubmission: jsonSerialization['escrowSubmission'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<_iz6hnyrm.ChainSubmission>(
              jsonSerialization['escrowSubmission'],
            ),
      feedbackSubmission: jsonSerialization['feedbackSubmission'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<_iz6hnyrm.ChainSubmission>(
              jsonSerialization['feedbackSubmission'],
            ),
      paymentExplorerUrl: jsonSerialization['paymentExplorerUrl'] as String?,
    );
  }

  _ibbrviw7.Hire hire;

  /// The catalog entry whose registryId is hire.agentId.
  _ipe500bk.AgentSummary agent;

  String input;

  String? result;

  _ikmm2vup.Payment? payment;

  /// Escrow job id, set once the create_job is confirmed.
  int? jobId;

  /// The job's expired_at.
  DateTime? expiresAt;

  /// The job's approval_deadline, set once the job is submitted.
  DateTime? approvalDeadline;

  String? rejectReason;

  /// The hire's latest escrow submission, any purpose.
  _iz6hnyrm.ChainSubmission? escrowSubmission;

  _iz6hnyrm.ChainSubmission? feedbackSubmission;

  String? paymentExplorerUrl;

  /// Returns a shallow copy of this [HireDetail]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  HireDetail copyWith({
    _ibbrviw7.Hire? hire,
    _ipe500bk.AgentSummary? agent,
    String? input,
    String? result,
    _ikmm2vup.Payment? payment,
    int? jobId,
    DateTime? expiresAt,
    DateTime? approvalDeadline,
    String? rejectReason,
    _iz6hnyrm.ChainSubmission? escrowSubmission,
    _iz6hnyrm.ChainSubmission? feedbackSubmission,
    String? paymentExplorerUrl,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireDetail',
      'hire': hire.toJson(),
      'agent': agent.toJson(),
      'input': input,
      if (result != null) 'result': result,
      if (payment != null) 'payment': payment?.toJson(),
      if (jobId != null) 'jobId': jobId,
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      if (approvalDeadline != null)
        'approvalDeadline': approvalDeadline?.toJson(),
      if (rejectReason != null) 'rejectReason': rejectReason,
      if (escrowSubmission != null)
        'escrowSubmission': escrowSubmission?.toJson(),
      if (feedbackSubmission != null)
        'feedbackSubmission': feedbackSubmission?.toJson(),
      if (paymentExplorerUrl != null) 'paymentExplorerUrl': paymentExplorerUrl,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HireDetail',
      'hire': hire.toJsonForProtocol(),
      'agent': agent.toJsonForProtocol(),
      'input': input,
      if (result != null) 'result': result,
      if (payment != null) 'payment': payment?.toJsonForProtocol(),
      if (jobId != null) 'jobId': jobId,
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      if (approvalDeadline != null)
        'approvalDeadline': approvalDeadline?.toJson(),
      if (rejectReason != null) 'rejectReason': rejectReason,
      if (escrowSubmission != null)
        'escrowSubmission': escrowSubmission?.toJsonForProtocol(),
      if (feedbackSubmission != null)
        'feedbackSubmission': feedbackSubmission?.toJsonForProtocol(),
      if (paymentExplorerUrl != null) 'paymentExplorerUrl': paymentExplorerUrl,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HireDetailImpl extends HireDetail {
  _HireDetailImpl({
    required _ibbrviw7.Hire hire,
    required _ipe500bk.AgentSummary agent,
    required String input,
    String? result,
    _ikmm2vup.Payment? payment,
    int? jobId,
    DateTime? expiresAt,
    DateTime? approvalDeadline,
    String? rejectReason,
    _iz6hnyrm.ChainSubmission? escrowSubmission,
    _iz6hnyrm.ChainSubmission? feedbackSubmission,
    String? paymentExplorerUrl,
  }) : super._(
         hire: hire,
         agent: agent,
         input: input,
         result: result,
         payment: payment,
         jobId: jobId,
         expiresAt: expiresAt,
         approvalDeadline: approvalDeadline,
         rejectReason: rejectReason,
         escrowSubmission: escrowSubmission,
         feedbackSubmission: feedbackSubmission,
         paymentExplorerUrl: paymentExplorerUrl,
       );

  /// Returns a shallow copy of this [HireDetail]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  HireDetail copyWith({
    _ibbrviw7.Hire? hire,
    _ipe500bk.AgentSummary? agent,
    String? input,
    Object? result = _Undefined,
    Object? payment = _Undefined,
    Object? jobId = _Undefined,
    Object? expiresAt = _Undefined,
    Object? approvalDeadline = _Undefined,
    Object? rejectReason = _Undefined,
    Object? escrowSubmission = _Undefined,
    Object? feedbackSubmission = _Undefined,
    Object? paymentExplorerUrl = _Undefined,
  }) {
    return HireDetail(
      hire: hire ?? this.hire.copyWith(),
      agent: agent ?? this.agent.copyWith(),
      input: input ?? this.input,
      result: result is String? ? result : this.result,
      payment: payment is _ikmm2vup.Payment?
          ? payment
          : this.payment?.copyWith(),
      jobId: jobId is int? ? jobId : this.jobId,
      expiresAt: expiresAt is DateTime? ? expiresAt : this.expiresAt,
      approvalDeadline: approvalDeadline is DateTime?
          ? approvalDeadline
          : this.approvalDeadline,
      rejectReason: rejectReason is String? ? rejectReason : this.rejectReason,
      escrowSubmission: escrowSubmission is _iz6hnyrm.ChainSubmission?
          ? escrowSubmission
          : this.escrowSubmission?.copyWith(),
      feedbackSubmission: feedbackSubmission is _iz6hnyrm.ChainSubmission?
          ? feedbackSubmission
          : this.feedbackSubmission?.copyWith(),
      paymentExplorerUrl: paymentExplorerUrl is String?
          ? paymentExplorerUrl
          : this.paymentExplorerUrl,
    );
  }
}
