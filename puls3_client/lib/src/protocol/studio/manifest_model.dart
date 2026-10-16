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

/// The model a draft names. Never a credential (ADR-0004).
abstract class ManifestModel
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ManifestModel._({
    required this.id,
    required this.provider,
  });

  factory ManifestModel({
    required String id,
    required String provider,
  }) = _ManifestModelImpl;

  factory ManifestModel.fromJson(Map<String, dynamic> jsonSerialization) {
    return ManifestModel(
      id: jsonSerialization['id'] as String,
      provider: jsonSerialization['provider'] as String,
    );
  }

  String provider;

  String id;

  /// Returns a shallow copy of this [ManifestModel]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ManifestModel copyWith({
    String? id,
    String? provider,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ManifestModel',
      'id': id,
      'provider': provider,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ManifestModel',
      'id': id,
      'provider': provider,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ManifestModelImpl extends ManifestModel {
  _ManifestModelImpl({
    required String id,
    required String provider,
  }) : super._(
         id: id,
         provider: provider,
       );

  /// Returns a shallow copy of this [ManifestModel]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ManifestModel copyWith({
    String? id,
    String? provider,
  }) {
    return ManifestModel(
      id: id ?? this.id,
      provider: provider ?? this.provider,
    );
  }
}
