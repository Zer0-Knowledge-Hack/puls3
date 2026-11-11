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

/// A new CLI session (#259). The refresh token is a bearer secret: the app
/// shows it once and never stores or logs it.
abstract class CliSessionGrant
    implements _is.SerializableModel, _is.ProtocolSerialization {
  CliSessionGrant._({
    required this.id,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory CliSessionGrant({
    required String id,
    required String refreshToken,
    required DateTime expiresAt,
  }) = _CliSessionGrantImpl;

  factory CliSessionGrant.fromJson(Map<String, dynamic> jsonSerialization) {
    return CliSessionGrant(
      id: jsonSerialization['id'] as String,
      refreshToken: jsonSerialization['refreshToken'] as String,
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  /// The session id, for listing and revoking it.
  String id;

  /// The refresh token a program seeds its session with
  /// (PULS3_REFRESH_TOKEN).
  String refreshToken;

  /// When it stops refreshing: the CLI lifetime is absolute.
  DateTime expiresAt;

  /// Returns a shallow copy of this [CliSessionGrant]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CliSessionGrant copyWith({
    String? id,
    String? refreshToken,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CliSessionGrant',
      'id': id,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CliSessionGrant',
      'id': id,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _CliSessionGrantImpl extends CliSessionGrant {
  _CliSessionGrantImpl({
    required String id,
    required String refreshToken,
    required DateTime expiresAt,
  }) : super._(
         id: id,
         refreshToken: refreshToken,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [CliSessionGrant]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CliSessionGrant copyWith({
    String? id,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return CliSessionGrant(
      id: id ?? this.id,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
