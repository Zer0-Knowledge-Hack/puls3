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

/// One CLI session of the signed-in wallet (#259). It never carries a secret.
abstract class CliSession
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  CliSession._({
    required this.id,
    required this.createdAt,
    required this.lastUsedAt,
    required this.expiresAt,
  });

  factory CliSession({
    required String id,
    required DateTime createdAt,
    required DateTime lastUsedAt,
    required DateTime expiresAt,
  }) = _CliSessionImpl;

  factory CliSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return CliSession(
      id: jsonSerialization['id'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      lastUsedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['lastUsedAt'],
      ),
      expiresAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  /// The session's refresh token id, used to revoke it.
  String id;

  /// When the app created it.
  DateTime createdAt;

  /// The last time a program refreshed it.
  DateTime lastUsedAt;

  /// When it stops refreshing, however often it is used: createdAt plus the
  /// CLI lifetime.
  DateTime expiresAt;

  /// Returns a shallow copy of this [CliSession]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  CliSession copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CliSession',
      'id': id,
      'createdAt': createdAt.toJson(),
      'lastUsedAt': lastUsedAt.toJson(),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CliSession',
      'id': id,
      'createdAt': createdAt.toJson(),
      'lastUsedAt': lastUsedAt.toJson(),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _CliSessionImpl extends CliSession {
  _CliSessionImpl({
    required String id,
    required DateTime createdAt,
    required DateTime lastUsedAt,
    required DateTime expiresAt,
  }) : super._(
         id: id,
         createdAt: createdAt,
         lastUsedAt: lastUsedAt,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [CliSession]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  CliSession copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    DateTime? expiresAt,
  }) {
    return CliSession(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
