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

/// The agent catalog cannot be read from the chain and no cached copy exists.
abstract class AgentCatalogUnavailable
    implements
        _i1.SerializableException,
        _i1.SerializableModel,
        _i1.ProtocolSerialization {
  AgentCatalogUnavailable._({required this.message});

  factory AgentCatalogUnavailable({required String message}) =
      _AgentCatalogUnavailableImpl;

  factory AgentCatalogUnavailable.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AgentCatalogUnavailable(
      message: jsonSerialization['message'] as String,
    );
  }

  /// What went wrong, safe to show to a client.
  String message;

  /// Returns a shallow copy of this [AgentCatalogUnavailable]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentCatalogUnavailable copyWith({String? message});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentCatalogUnavailable',
      'message': message,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentCatalogUnavailable',
      'message': message,
    };
  }

  @override
  String toString() {
    return 'AgentCatalogUnavailable(message: $message)';
  }
}

class _AgentCatalogUnavailableImpl extends AgentCatalogUnavailable {
  _AgentCatalogUnavailableImpl({required String message})
    : super._(message: message);

  /// Returns a shallow copy of this [AgentCatalogUnavailable]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentCatalogUnavailable copyWith({String? message}) {
    return AgentCatalogUnavailable(message: message ?? this.message);
  }
}
