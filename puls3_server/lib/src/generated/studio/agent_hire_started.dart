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

/// An agent-to-agent hire started by the hiring agent's owner (#312). The
/// rest of the hire runs on the server; its tx hashes are in the server log.
abstract class AgentHireStarted
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AgentHireStarted._({
    required this.hireId,
    required this.hiringWallet,
    required this.state,
  });

  factory AgentHireStarted({
    required int hireId,
    required String hiringWallet,
    required String state,
  }) = _AgentHireStartedImpl;

  factory AgentHireStarted.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentHireStarted(
      hireId: jsonSerialization['hireId'] as int,
      hiringWallet: jsonSerialization['hiringWallet'] as String,
      state: jsonSerialization['state'] as String,
    );
  }

  int hireId;

  /// The hiring agent's custodied wallet: client and evaluator of the hire.
  String hiringWallet;

  /// `started`: create_job, fund, the hired agent's submit and complete follow.
  String state;

  /// Returns a shallow copy of this [AgentHireStarted]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AgentHireStarted copyWith({
    int? hireId,
    String? hiringWallet,
    String? state,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentHireStarted',
      'hireId': hireId,
      'hiringWallet': hiringWallet,
      'state': state,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentHireStarted',
      'hireId': hireId,
      'hiringWallet': hiringWallet,
      'state': state,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _AgentHireStartedImpl extends AgentHireStarted {
  _AgentHireStartedImpl({
    required int hireId,
    required String hiringWallet,
    required String state,
  }) : super._(
         hireId: hireId,
         hiringWallet: hiringWallet,
         state: state,
       );

  /// Returns a shallow copy of this [AgentHireStarted]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AgentHireStarted copyWith({
    int? hireId,
    String? hiringWallet,
    String? state,
  }) {
    return AgentHireStarted(
      hireId: hireId ?? this.hireId,
      hiringWallet: hiringWallet ?? this.hiringWallet,
      state: state ?? this.state,
    );
  }
}
