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
import '../studio/manifest_model.dart' as _it5558gr;
import '../studio/manifest_price.dart' as _ic3zks5j;
import '../studio/manifest_skill.dart' as _igiu5xyp;
import '../studio/manifest_subcontract.dart' as _i655sd6t;

/// An editable agent manifest (ADR-0004). No version: a draft has none.
/// Fields are flat camelCase. The domain wire document, which is what gets
/// hashed, is nested snake_case and is not this model.
abstract class AgentManifestDraft
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AgentManifestDraft._({
    this.name,
    this.description,
    this.skills,
    this.model,
    this.systemPrompt,
    this.inputType,
    this.inputMaxChars,
    this.outputType,
    this.outputMaxChars,
    this.price,
    this.subcontract,
  });

  factory AgentManifestDraft({
    String? name,
    String? description,
    List<_igiu5xyp.ManifestSkill>? skills,
    _it5558gr.ManifestModel? model,
    String? systemPrompt,
    String? inputType,
    int? inputMaxChars,
    String? outputType,
    int? outputMaxChars,
    _ic3zks5j.ManifestPrice? price,
    _i655sd6t.ManifestSubcontract? subcontract,
  }) = _AgentManifestDraftImpl;

  factory AgentManifestDraft.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentManifestDraft(
      name: jsonSerialization['name'] as String?,
      description: jsonSerialization['description'] as String?,
      skills: jsonSerialization['skills'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<List<_igiu5xyp.ManifestSkill>>(
              jsonSerialization['skills'],
            ),
      model: jsonSerialization['model'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<_it5558gr.ManifestModel>(
              jsonSerialization['model'],
            ),
      systemPrompt: jsonSerialization['systemPrompt'] as String?,
      inputType: jsonSerialization['inputType'] as String?,
      inputMaxChars: jsonSerialization['inputMaxChars'] as int?,
      outputType: jsonSerialization['outputType'] as String?,
      outputMaxChars: jsonSerialization['outputMaxChars'] as int?,
      price: jsonSerialization['price'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<_ic3zks5j.ManifestPrice>(
              jsonSerialization['price'],
            ),
      subcontract: jsonSerialization['subcontract'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<_i655sd6t.ManifestSubcontract>(
              jsonSerialization['subcontract'],
            ),
    );
  }

  String? name;

  String? description;

  List<_igiu5xyp.ManifestSkill>? skills;

  _it5558gr.ManifestModel? model;

  String? systemPrompt;

  String? inputType;

  int? inputMaxChars;

  String? outputType;

  int? outputMaxChars;

  _ic3zks5j.ManifestPrice? price;

  /// The opt-in to subcontract; null for an agent that never does.
  _i655sd6t.ManifestSubcontract? subcontract;

  /// Returns a shallow copy of this [AgentManifestDraft]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AgentManifestDraft copyWith({
    String? name,
    String? description,
    List<_igiu5xyp.ManifestSkill>? skills,
    _it5558gr.ManifestModel? model,
    String? systemPrompt,
    String? inputType,
    int? inputMaxChars,
    String? outputType,
    int? outputMaxChars,
    _ic3zks5j.ManifestPrice? price,
    _i655sd6t.ManifestSubcontract? subcontract,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentManifestDraft',
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (skills != null)
        'skills': skills?.toJson(valueToJson: (v) => v.toJson()),
      if (model != null) 'model': model?.toJson(),
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
      if (inputType != null) 'inputType': inputType,
      if (inputMaxChars != null) 'inputMaxChars': inputMaxChars,
      if (outputType != null) 'outputType': outputType,
      if (outputMaxChars != null) 'outputMaxChars': outputMaxChars,
      if (price != null) 'price': price?.toJson(),
      if (subcontract != null) 'subcontract': subcontract?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentManifestDraft',
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (skills != null)
        'skills': skills?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (model != null) 'model': model?.toJsonForProtocol(),
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
      if (inputType != null) 'inputType': inputType,
      if (inputMaxChars != null) 'inputMaxChars': inputMaxChars,
      if (outputType != null) 'outputType': outputType,
      if (outputMaxChars != null) 'outputMaxChars': outputMaxChars,
      if (price != null) 'price': price?.toJsonForProtocol(),
      if (subcontract != null) 'subcontract': subcontract?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentManifestDraftImpl extends AgentManifestDraft {
  _AgentManifestDraftImpl({
    String? name,
    String? description,
    List<_igiu5xyp.ManifestSkill>? skills,
    _it5558gr.ManifestModel? model,
    String? systemPrompt,
    String? inputType,
    int? inputMaxChars,
    String? outputType,
    int? outputMaxChars,
    _ic3zks5j.ManifestPrice? price,
    _i655sd6t.ManifestSubcontract? subcontract,
  }) : super._(
         name: name,
         description: description,
         skills: skills,
         model: model,
         systemPrompt: systemPrompt,
         inputType: inputType,
         inputMaxChars: inputMaxChars,
         outputType: outputType,
         outputMaxChars: outputMaxChars,
         price: price,
         subcontract: subcontract,
       );

  /// Returns a shallow copy of this [AgentManifestDraft]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AgentManifestDraft copyWith({
    Object? name = _Undefined,
    Object? description = _Undefined,
    Object? skills = _Undefined,
    Object? model = _Undefined,
    Object? systemPrompt = _Undefined,
    Object? inputType = _Undefined,
    Object? inputMaxChars = _Undefined,
    Object? outputType = _Undefined,
    Object? outputMaxChars = _Undefined,
    Object? price = _Undefined,
    Object? subcontract = _Undefined,
  }) {
    return AgentManifestDraft(
      name: name is String? ? name : this.name,
      description: description is String? ? description : this.description,
      skills: skills is List<_igiu5xyp.ManifestSkill>?
          ? skills
          : this.skills?.map((e0) => e0.copyWith()).toList(),
      model: model is _it5558gr.ManifestModel? ? model : this.model?.copyWith(),
      systemPrompt: systemPrompt is String? ? systemPrompt : this.systemPrompt,
      inputType: inputType is String? ? inputType : this.inputType,
      inputMaxChars: inputMaxChars is int? ? inputMaxChars : this.inputMaxChars,
      outputType: outputType is String? ? outputType : this.outputType,
      outputMaxChars: outputMaxChars is int?
          ? outputMaxChars
          : this.outputMaxChars,
      price: price is _ic3zks5j.ManifestPrice? ? price : this.price?.copyWith(),
      subcontract: subcontract is _i655sd6t.ManifestSubcontract?
          ? subcontract
          : this.subcontract?.copyWith(),
    );
  }
}
