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
import 'prepared_transaction.dart' as _i83uy5s0;

/// One deploy, as the Studio client polls it (api.md, Deploy session).
abstract class DeploySession
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DeploySession._({
    required this.state,
    this.preparation,
    this.agentId,
    this.agentWallet,
    this.failureCode,
    this.retryFromStep,
  });

  factory DeploySession({
    required String state,
    _i83uy5s0.PreparedTransaction? preparation,
    int? agentId,
    String? agentWallet,
    String? failureCode,
    int? retryFromStep,
  }) = _DeploySessionImpl;

  factory DeploySession.fromJson(Map<String, dynamic> jsonSerialization) {
    return DeploySession(
      state: jsonSerialization['state'] as String,
      preparation: jsonSerialization['preparation'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<_i83uy5s0.PreparedTransaction>(
              jsonSerialization['preparation'],
            ),
      agentId: jsonSerialization['agentId'] as int?,
      agentWallet: jsonSerialization['agentWallet'] as String?,
      failureCode: jsonSerialization['failureCode'] as String?,
      retryFromStep: jsonSerialization['retryFromStep'] as int?,
    );
  }

  /// awaitingRegistrationSignature, registrationSubmitted,
  /// awaitingWalletAuthorization, walletAuthorizationSubmitted, publishing,
  /// active, or failed.
  String state;

  _i83uy5s0.PreparedTransaction? preparation;

  /// Identity Registry id, set once register_full is confirmed.
  int? agentId;

  /// Custodied payment wallet, a G… address.
  String? agentWallet;

  /// ChainSubmission error code, or PublicationFailed.
  String? failureCode;

  int? retryFromStep;

  /// Returns a shallow copy of this [DeploySession]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DeploySession copyWith({
    String? state,
    _i83uy5s0.PreparedTransaction? preparation,
    int? agentId,
    String? agentWallet,
    String? failureCode,
    int? retryFromStep,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DeploySession',
      'state': state,
      if (preparation != null) 'preparation': preparation?.toJson(),
      if (agentId != null) 'agentId': agentId,
      if (agentWallet != null) 'agentWallet': agentWallet,
      if (failureCode != null) 'failureCode': failureCode,
      if (retryFromStep != null) 'retryFromStep': retryFromStep,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DeploySession',
      'state': state,
      if (preparation != null) 'preparation': preparation?.toJsonForProtocol(),
      if (agentId != null) 'agentId': agentId,
      if (agentWallet != null) 'agentWallet': agentWallet,
      if (failureCode != null) 'failureCode': failureCode,
      if (retryFromStep != null) 'retryFromStep': retryFromStep,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeploySessionImpl extends DeploySession {
  _DeploySessionImpl({
    required String state,
    _i83uy5s0.PreparedTransaction? preparation,
    int? agentId,
    String? agentWallet,
    String? failureCode,
    int? retryFromStep,
  }) : super._(
         state: state,
         preparation: preparation,
         agentId: agentId,
         agentWallet: agentWallet,
         failureCode: failureCode,
         retryFromStep: retryFromStep,
       );

  /// Returns a shallow copy of this [DeploySession]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DeploySession copyWith({
    String? state,
    Object? preparation = _Undefined,
    Object? agentId = _Undefined,
    Object? agentWallet = _Undefined,
    Object? failureCode = _Undefined,
    Object? retryFromStep = _Undefined,
  }) {
    return DeploySession(
      state: state ?? this.state,
      preparation: preparation is _i83uy5s0.PreparedTransaction?
          ? preparation
          : this.preparation?.copyWith(),
      agentId: agentId is int? ? agentId : this.agentId,
      agentWallet: agentWallet is String? ? agentWallet : this.agentWallet,
      failureCode: failureCode is String? ? failureCode : this.failureCode,
      retryFromStep: retryFromStep is int? ? retryFromStep : this.retryFromStep,
    );
  }
}
