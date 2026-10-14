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

/// Whether the caller may rate a hire, and why not (docs/architecture/api.md,
/// `FeedbackEndpoint.getFeedbackEligibility`).
abstract class FeedbackEligibility
    implements _is.SerializableModel, _is.ProtocolSerialization {
  FeedbackEligibility._({
    required this.hireId,
    required this.eligible,
    this.reason,
  });

  factory FeedbackEligibility({
    required int hireId,
    required bool eligible,
    String? reason,
  }) = _FeedbackEligibilityImpl;

  factory FeedbackEligibility.fromJson(Map<String, dynamic> jsonSerialization) {
    return FeedbackEligibility(
      hireId: jsonSerialization['hireId'] as int,
      eligible: _is.BoolJsonExtension.fromJson(jsonSerialization['eligible']),
      reason: jsonSerialization['reason'] as String?,
    );
  }

  int hireId;

  bool eligible;

  /// The `Puls3ApiException` code naming the broken rule when eligible is
  /// false: HireNotCompleted, HireAlreadyRated or FeedbackFromAgentOwner.
  /// Null when eligible is true.
  String? reason;

  /// Returns a shallow copy of this [FeedbackEligibility]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FeedbackEligibility copyWith({
    int? hireId,
    bool? eligible,
    String? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FeedbackEligibility',
      'hireId': hireId,
      'eligible': eligible,
      if (reason != null) 'reason': reason,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FeedbackEligibility',
      'hireId': hireId,
      'eligible': eligible,
      if (reason != null) 'reason': reason,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FeedbackEligibilityImpl extends FeedbackEligibility {
  _FeedbackEligibilityImpl({
    required int hireId,
    required bool eligible,
    String? reason,
  }) : super._(
         hireId: hireId,
         eligible: eligible,
         reason: reason,
       );

  /// Returns a shallow copy of this [FeedbackEligibility]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FeedbackEligibility copyWith({
    int? hireId,
    bool? eligible,
    Object? reason = _Undefined,
  }) {
    return FeedbackEligibility(
      hireId: hireId ?? this.hireId,
      eligible: eligible ?? this.eligible,
      reason: reason is String? ? reason : this.reason,
    );
  }
}
