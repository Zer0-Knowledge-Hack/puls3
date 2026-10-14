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

/// One skill on an agent manifest draft (ADR-0004). Transport only.
abstract class ManifestSkill
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ManifestSkill._({
    required this.id,
    required this.name,
    this.description,
    this.tags,
  });

  factory ManifestSkill({
    required String id,
    required String name,
    String? description,
    List<String>? tags,
  }) = _ManifestSkillImpl;

  factory ManifestSkill.fromJson(Map<String, dynamic> jsonSerialization) {
    return ManifestSkill(
      id: jsonSerialization['id'] as String,
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String?,
      tags: jsonSerialization['tags'] == null
          ? null
          : _ihzwmcdm.Protocol().deserialize<List<String>>(
              jsonSerialization['tags'],
            ),
    );
  }

  String id;

  String name;

  String? description;

  List<String>? tags;

  /// Returns a shallow copy of this [ManifestSkill]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ManifestSkill copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? tags,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ManifestSkill',
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ManifestSkill',
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ManifestSkillImpl extends ManifestSkill {
  _ManifestSkillImpl({
    required String id,
    required String name,
    String? description,
    List<String>? tags,
  }) : super._(
         id: id,
         name: name,
         description: description,
         tags: tags,
       );

  /// Returns a shallow copy of this [ManifestSkill]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ManifestSkill copyWith({
    String? id,
    String? name,
    Object? description = _Undefined,
    Object? tags = _Undefined,
  }) {
    return ManifestSkill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description is String? ? description : this.description,
      tags: tags is List<String>? ? tags : this.tags?.map((e0) => e0).toList(),
    );
  }
}
