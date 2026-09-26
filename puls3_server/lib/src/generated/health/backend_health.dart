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

import 'package:serverpod/serverpod.dart' as _i1;

/// Basic backend health information exposed to generated clients.
abstract class BackendHealth
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  BackendHealth._({required this.version});

  factory BackendHealth({required String version}) = _BackendHealthImpl;

  factory BackendHealth.fromJson(Map<String, dynamic> jsonSerialization) {
    return BackendHealth(version: jsonSerialization['version'] as String);
  }

  /// The running puls3 application version.
  String version;

  /// Returns a shallow copy of this [BackendHealth]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  BackendHealth copyWith({String? version});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BackendHealth',
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BackendHealth',
      'version': version,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _BackendHealthImpl extends BackendHealth {
  _BackendHealthImpl({required String version}) : super._(version: version);

  /// Returns a shallow copy of this [BackendHealth]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  BackendHealth copyWith({String? version}) {
    return BackendHealth(version: version ?? this.version);
  }
}
