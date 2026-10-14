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
import '../studio/agent_manifest_draft.dart' as _ihx3y7jf;

/// A saved draft as its owner sees it (api.md, StudioDraft).
abstract class StudioDraft
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StudioDraft._({
    required this.draftId,
    required this.manifest,
    required this.revision,
    required this.deployState,
    this.liveVersion,
    this.agentId,
    this.retryFromStep,
  });

  factory StudioDraft({
    required int draftId,
    required _ihx3y7jf.AgentManifestDraft manifest,
    required int revision,
    required String deployState,
    int? liveVersion,
    String? agentId,
    int? retryFromStep,
  }) = _StudioDraftImpl;

  factory StudioDraft.fromJson(Map<String, dynamic> jsonSerialization) {
    return StudioDraft(
      draftId: jsonSerialization['draftId'] as int,
      manifest: _ihzwmcdm.Protocol().deserialize<_ihx3y7jf.AgentManifestDraft>(
        jsonSerialization['manifest'],
      ),
      revision: jsonSerialization['revision'] as int,
      deployState: jsonSerialization['deployState'] as String,
      liveVersion: jsonSerialization['liveVersion'] as int?,
      agentId: jsonSerialization['agentId'] as String?,
      retryFromStep: jsonSerialization['retryFromStep'] as int?,
    );
  }

  int draftId;

  _ihx3y7jf.AgentManifestDraft manifest;

  int revision;

  /// draft, deploying, failed, or live.
  String deployState;

  int? liveVersion;

  String? agentId;

  int? retryFromStep;

  /// Returns a shallow copy of this [StudioDraft]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StudioDraft copyWith({
    int? draftId,
    _ihx3y7jf.AgentManifestDraft? manifest,
    int? revision,
    String? deployState,
    int? liveVersion,
    String? agentId,
    int? retryFromStep,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StudioDraft',
      'draftId': draftId,
      'manifest': manifest.toJson(),
      'revision': revision,
      'deployState': deployState,
      if (liveVersion != null) 'liveVersion': liveVersion,
      if (agentId != null) 'agentId': agentId,
      if (retryFromStep != null) 'retryFromStep': retryFromStep,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StudioDraft',
      'draftId': draftId,
      'manifest': manifest.toJsonForProtocol(),
      'revision': revision,
      'deployState': deployState,
      if (liveVersion != null) 'liveVersion': liveVersion,
      if (agentId != null) 'agentId': agentId,
      if (retryFromStep != null) 'retryFromStep': retryFromStep,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StudioDraftImpl extends StudioDraft {
  _StudioDraftImpl({
    required int draftId,
    required _ihx3y7jf.AgentManifestDraft manifest,
    required int revision,
    required String deployState,
    int? liveVersion,
    String? agentId,
    int? retryFromStep,
  }) : super._(
         draftId: draftId,
         manifest: manifest,
         revision: revision,
         deployState: deployState,
         liveVersion: liveVersion,
         agentId: agentId,
         retryFromStep: retryFromStep,
       );

  /// Returns a shallow copy of this [StudioDraft]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StudioDraft copyWith({
    int? draftId,
    _ihx3y7jf.AgentManifestDraft? manifest,
    int? revision,
    String? deployState,
    Object? liveVersion = _Undefined,
    Object? agentId = _Undefined,
    Object? retryFromStep = _Undefined,
  }) {
    return StudioDraft(
      draftId: draftId ?? this.draftId,
      manifest: manifest ?? this.manifest.copyWith(),
      revision: revision ?? this.revision,
      deployState: deployState ?? this.deployState,
      liveVersion: liveVersion is int? ? liveVersion : this.liveVersion,
      agentId: agentId is String? ? agentId : this.agentId,
      retryFromStep: retryFromStep is int? ? retryFromStep : this.retryFromStep,
    );
  }
}
