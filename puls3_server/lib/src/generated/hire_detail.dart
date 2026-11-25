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
import 'package:puls3_server/src/generated/protocol.dart' as _i7k47pdw;
import 'package:serverpod/serverpod.dart' as _is;
import 'agent/agent_summary.dart' as _ipe500bk;
import 'chain/chain_submission.dart' as _iz6hnyrm;
import 'hire.dart' as _ibbrviw7;
import 'hire_receipt_line_view.dart' as _i404ykkm;
import 'payment.dart' as _ikmm2vup;

/// Everything the app shows about one hire (docs/architecture/api.md,
/// "Response shapes not copied from the domain").
abstract class HireDetail
    implements _is.SerializableModel, _is.ProtocolSerialization {
  HireDetail._({
    required this.hire,
    required this.agent,
    required this.input,
    this.result,
    this.payment,
    this.jobId,
    this.expiresAt,
    this.approvalDeadline,
    bool? runFinished,
    this.submitErrorCode,
    this.rejectReason,
    this.escrowSubmission,
    this.feedbackSubmission,
    this.feedbackScore,
    this.paymentExplorerUrl,
    this.receipt,
  }) : runFinished = runFinished ?? false;

  factory HireDetail({
    required _ibbrviw7.Hire hire,
    required _ipe500bk.AgentSummary agent,
    required String input,
    String? result,
    _ikmm2vup.Payment? payment,
    int? jobId,
    DateTime? expiresAt,
    DateTime? approvalDeadline,
    bool? runFinished,
    String? submitErrorCode,
    String? rejectReason,
    _iz6hnyrm.ChainSubmission? escrowSubmission,
    _iz6hnyrm.ChainSubmission? feedbackSubmission,
    int? feedbackScore,
    String? paymentExplorerUrl,
    List<_i404ykkm.HireReceiptLine>? receipt,
  }) = _HireDetailImpl;

  factory HireDetail.fromJson(Map<String, dynamic> jsonSerialization) {
    return HireDetail(
      hire: _i7k47pdw.Protocol().deserialize<_ibbrviw7.Hire>(
        jsonSerialization['hire'],
      ),
      agent: _i7k47pdw.Protocol().deserialize<_ipe500bk.AgentSummary>(
        jsonSerialization['agent'],
      ),
      input: jsonSerialization['input'] as String,
      result: jsonSerialization['result'] as String?,
      payment: jsonSerialization['payment'] == null
          ? null
          : _i7k47pdw.Protocol().deserialize<_ikmm2vup.Payment>(
              jsonSerialization['payment'],
            ),
      jobId: jsonSerialization['jobId'] as int?,
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
      approvalDeadline: jsonSerialization['approvalDeadline'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['approvalDeadline'],
            ),
      runFinished: jsonSerialization['runFinished'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['runFinished']),
      submitErrorCode: jsonSerialization['submitErrorCode'] as String?,
      rejectReason: jsonSerialization['rejectReason'] as String?,
      escrowSubmission: jsonSerialization['escrowSubmission'] == null
          ? null
          : _i7k47pdw.Protocol().deserialize<_iz6hnyrm.ChainSubmission>(
              jsonSerialization['escrowSubmission'],
            ),
      feedbackSubmission: jsonSerialization['feedbackSubmission'] == null
          ? null
          : _i7k47pdw.Protocol().deserialize<_iz6hnyrm.ChainSubmission>(
              jsonSerialization['feedbackSubmission'],
            ),
      feedbackScore: jsonSerialization['feedbackScore'] as int?,
      paymentExplorerUrl: jsonSerialization['paymentExplorerUrl'] as String?,
      receipt: jsonSerialization['receipt'] == null
          ? null
          : _i7k47pdw.Protocol().deserialize<List<_i404ykkm.HireReceiptLine>>(
              jsonSerialization['receipt'],
            ),
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

  /// Whether the agent run succeeded, even while its result is still hidden
  /// before the escrow `submit`. The app uses it to say the agent finished
  /// while the result is being recorded (#277).
  bool runFinished;

  /// While the hire is funded, why the agent's `submit` cannot happen:
  /// `AgentCannotDeliver` (payee not custodied), `SubmitSimulationRejected`,
  /// `EscrowCallFailed` or `OutcomeUnknown`. Null when no submit is needed or
  /// one may still land. The result stays hidden until `submit` confirms.
  String? submitErrorCode;

  String? rejectReason;

  /// The hire's latest escrow submission, any purpose.
  _iz6hnyrm.ChainSubmission? escrowSubmission;

  _iz6hnyrm.ChainSubmission? feedbackSubmission;

  /// The score of a relayed giveFeedback, so a reload shows its stars (#242).
  /// Null when the rating failed or was never prepared.
  int? feedbackScore;

  String? paymentExplorerUrl;

  /// The hire's itemized subcontract receipt (ADR-0011 D6), oldest first;
  /// empty when the hire opened no child job. Only the hire's consumer
  /// reads it, through the same ownership check as the rest of the detail.
  List<_i404ykkm.HireReceiptLine>? receipt;

  /// Returns a shallow copy of this [HireDetail]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  HireDetail copyWith({
    _ibbrviw7.Hire? hire,
    _ipe500bk.AgentSummary? agent,
    String? input,
    String? result,
    _ikmm2vup.Payment? payment = const _UndefinedHireDetail$payment(),
    int? jobId,
    DateTime? expiresAt = const _is.$UndefinedDateTime(),
    DateTime? approvalDeadline = const _is.$UndefinedDateTime(),
    bool? runFinished,
    String? submitErrorCode,
    String? rejectReason,
    _iz6hnyrm.ChainSubmission? escrowSubmission =
        const _UndefinedHireDetail$escrowSubmission(),
    _iz6hnyrm.ChainSubmission? feedbackSubmission =
        const _UndefinedHireDetail$escrowSubmission(),
    int? feedbackScore,
    String? paymentExplorerUrl,
    List<_i404ykkm.HireReceiptLine>? receipt =
        const _is.$UndefinedList<_i404ykkm.HireReceiptLine>(),
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
      'runFinished': runFinished,
      if (submitErrorCode != null) 'submitErrorCode': submitErrorCode,
      if (rejectReason != null) 'rejectReason': rejectReason,
      if (escrowSubmission != null)
        'escrowSubmission': escrowSubmission?.toJson(),
      if (feedbackSubmission != null)
        'feedbackSubmission': feedbackSubmission?.toJson(),
      if (feedbackScore != null) 'feedbackScore': feedbackScore,
      if (paymentExplorerUrl != null) 'paymentExplorerUrl': paymentExplorerUrl,
      if (receipt != null)
        'receipt': receipt?.toJson(valueToJson: (v) => v.toJson()),
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
      'runFinished': runFinished,
      if (submitErrorCode != null) 'submitErrorCode': submitErrorCode,
      if (rejectReason != null) 'rejectReason': rejectReason,
      if (escrowSubmission != null)
        'escrowSubmission': escrowSubmission?.toJsonForProtocol(),
      if (feedbackSubmission != null)
        'feedbackSubmission': feedbackSubmission?.toJsonForProtocol(),
      if (feedbackScore != null) 'feedbackScore': feedbackScore,
      if (paymentExplorerUrl != null) 'paymentExplorerUrl': paymentExplorerUrl,
      if (receipt != null)
        'receipt': receipt?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedHireDetail$payment extends _is.UndefinedSentinel
    implements _ikmm2vup.Payment {
  const _UndefinedHireDetail$payment();
}

class _UndefinedHireDetail$escrowSubmission extends _is.UndefinedSentinel
    implements _iz6hnyrm.ChainSubmission {
  const _UndefinedHireDetail$escrowSubmission();
}

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
    bool? runFinished,
    String? submitErrorCode,
    String? rejectReason,
    _iz6hnyrm.ChainSubmission? escrowSubmission,
    _iz6hnyrm.ChainSubmission? feedbackSubmission,
    int? feedbackScore,
    String? paymentExplorerUrl,
    List<_i404ykkm.HireReceiptLine>? receipt,
  }) : super._(
         hire: hire,
         agent: agent,
         input: input,
         result: result,
         payment: payment,
         jobId: jobId,
         expiresAt: expiresAt,
         approvalDeadline: approvalDeadline,
         runFinished: runFinished,
         submitErrorCode: submitErrorCode,
         rejectReason: rejectReason,
         escrowSubmission: escrowSubmission,
         feedbackSubmission: feedbackSubmission,
         feedbackScore: feedbackScore,
         paymentExplorerUrl: paymentExplorerUrl,
         receipt: receipt,
       );

  /// Returns a shallow copy of this [HireDetail]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  HireDetail copyWith({
    _ibbrviw7.Hire? hire,
    _ipe500bk.AgentSummary? agent,
    String? input,
    Object? result = _Undefined,
    _ikmm2vup.Payment? payment = const _UndefinedHireDetail$payment(),
    Object? jobId = _Undefined,
    DateTime? expiresAt = const _is.$UndefinedDateTime(),
    DateTime? approvalDeadline = const _is.$UndefinedDateTime(),
    bool? runFinished,
    Object? submitErrorCode = _Undefined,
    Object? rejectReason = _Undefined,
    _iz6hnyrm.ChainSubmission? escrowSubmission =
        const _UndefinedHireDetail$escrowSubmission(),
    _iz6hnyrm.ChainSubmission? feedbackSubmission =
        const _UndefinedHireDetail$escrowSubmission(),
    Object? feedbackScore = _Undefined,
    Object? paymentExplorerUrl = _Undefined,
    List<_i404ykkm.HireReceiptLine>? receipt =
        const _is.$UndefinedList<_i404ykkm.HireReceiptLine>(),
  }) {
    return HireDetail(
      hire: hire ?? this.hire.copyWith(),
      agent: agent ?? this.agent.copyWith(),
      input: input ?? this.input,
      result: result is String? ? result : this.result,
      payment: payment is _is.UndefinedSentinel
          ? this.payment?.copyWith()
          : payment,
      jobId: jobId is int? ? jobId : this.jobId,
      expiresAt: expiresAt is _is.UndefinedSentinel
          ? this.expiresAt
          : expiresAt,
      approvalDeadline: approvalDeadline is _is.UndefinedSentinel
          ? this.approvalDeadline
          : approvalDeadline,
      runFinished: runFinished ?? this.runFinished,
      submitErrorCode: submitErrorCode is String?
          ? submitErrorCode
          : this.submitErrorCode,
      rejectReason: rejectReason is String? ? rejectReason : this.rejectReason,
      escrowSubmission: escrowSubmission is _is.UndefinedSentinel
          ? this.escrowSubmission?.copyWith()
          : escrowSubmission,
      feedbackSubmission: feedbackSubmission is _is.UndefinedSentinel
          ? this.feedbackSubmission?.copyWith()
          : feedbackSubmission,
      feedbackScore: feedbackScore is int? ? feedbackScore : this.feedbackScore,
      paymentExplorerUrl: paymentExplorerUrl is String?
          ? paymentExplorerUrl
          : this.paymentExplorerUrl,
      receipt: receipt is _is.UndefinedSentinel
          ? this.receipt?.map((e0) => e0.copyWith()).toList()
          : receipt,
    );
  }
}
