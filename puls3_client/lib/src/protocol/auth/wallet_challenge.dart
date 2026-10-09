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

/// A SEP-10 challenge the client signs. The payload is the challenge XDR.
abstract class WalletChallenge
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  WalletChallenge._({
    required this.challengeId,
    required this.wallet,
    required this.payload,
    required this.networkPassphrase,
    required this.expiresAt,
  });

  factory WalletChallenge({
    required String challengeId,
    required String wallet,
    required String payload,
    required String networkPassphrase,
    required DateTime expiresAt,
  }) = _WalletChallengeImpl;

  factory WalletChallenge.fromJson(Map<String, dynamic> jsonSerialization) {
    return WalletChallenge(
      challengeId: jsonSerialization['challengeId'] as String,
      wallet: jsonSerialization['wallet'] as String,
      payload: jsonSerialization['payload'] as String,
      networkPassphrase: jsonSerialization['networkPassphrase'] as String,
      expiresAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  /// Opaque id the client sends back to verifyChallenge.
  String challengeId;

  /// Stellar G-address the challenge was issued for.
  String wallet;

  /// Base64 challenge transaction XDR.
  String payload;

  /// Network passphrase the signature must cover.
  String networkPassphrase;

  /// End of the challenge time bounds.
  DateTime expiresAt;

  /// Returns a shallow copy of this [WalletChallenge]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  WalletChallenge copyWith({
    String? challengeId,
    String? wallet,
    String? payload,
    String? networkPassphrase,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WalletChallenge',
      'challengeId': challengeId,
      'wallet': wallet,
      'payload': payload,
      'networkPassphrase': networkPassphrase,
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WalletChallenge',
      'challengeId': challengeId,
      'wallet': wallet,
      'payload': payload,
      'networkPassphrase': networkPassphrase,
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _WalletChallengeImpl extends WalletChallenge {
  _WalletChallengeImpl({
    required String challengeId,
    required String wallet,
    required String payload,
    required String networkPassphrase,
    required DateTime expiresAt,
  }) : super._(
         challengeId: challengeId,
         wallet: wallet,
         payload: payload,
         networkPassphrase: networkPassphrase,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [WalletChallenge]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  WalletChallenge copyWith({
    String? challengeId,
    String? wallet,
    String? payload,
    String? networkPassphrase,
    DateTime? expiresAt,
  }) {
    return WalletChallenge(
      challengeId: challengeId ?? this.challengeId,
      wallet: wallet ?? this.wallet,
      payload: payload ?? this.payload,
      networkPassphrase: networkPassphrase ?? this.networkPassphrase,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
