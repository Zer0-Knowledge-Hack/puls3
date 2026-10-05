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
import 'package:puls3_server/src/generated/protocol.dart' as _i2;

/// One agent of the catalog, built from the identity registry metadata.
abstract class AgentSummary
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  AgentSummary._({
    required this.id,
    required this.registryId,
    required this.name,
    required this.description,
    required this.skills,
    required this.priceUsdcStroops,
    this.wallet,
    this.model,
  });

  factory AgentSummary({
    required String id,
    required int registryId,
    required String name,
    required String description,
    required List<String> skills,
    required int priceUsdcStroops,
    String? wallet,
    String? model,
  }) = _AgentSummaryImpl;

  factory AgentSummary.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentSummary(
      id: jsonSerialization['id'] as String,
      registryId: jsonSerialization['registryId'] as int,
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String,
      skills: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['skills'],
      ),
      priceUsdcStroops: jsonSerialization['priceUsdcStroops'] as int,
      wallet: jsonSerialization['wallet'] as String?,
      model: jsonSerialization['model'] as String?,
    );
  }

  /// The metadata id of the agent, for example agt-001.
  String id;

  /// The on-chain integer id in the identity registry.
  int registryId;

  /// The display name.
  String name;

  /// What the agent does.
  String description;

  /// The skill ids, in kebab-case.
  List<String> skills;

  /// The price of one hire in USDC stroops.
  int priceUsdcStroops;

  /// The Stellar address (G...) that receives payments, when registered.
  String? wallet;

  /// The model that runs the agent, when the metadata names one.
  String? model;

  /// Returns a shallow copy of this [AgentSummary]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentSummary copyWith({
    String? id,
    int? registryId,
    String? name,
    String? description,
    List<String>? skills,
    int? priceUsdcStroops,
    String? wallet,
    String? model,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentSummary',
      'id': id,
      'registryId': registryId,
      'name': name,
      'description': description,
      'skills': skills.toJson(),
      'priceUsdcStroops': priceUsdcStroops,
      if (wallet != null) 'wallet': wallet,
      if (model != null) 'model': model,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentSummary',
      'id': id,
      'registryId': registryId,
      'name': name,
      'description': description,
      'skills': skills.toJson(),
      'priceUsdcStroops': priceUsdcStroops,
      if (wallet != null) 'wallet': wallet,
      if (model != null) 'model': model,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentSummaryImpl extends AgentSummary {
  _AgentSummaryImpl({
    required String id,
    required int registryId,
    required String name,
    required String description,
    required List<String> skills,
    required int priceUsdcStroops,
    String? wallet,
    String? model,
  }) : super._(
         id: id,
         registryId: registryId,
         name: name,
         description: description,
         skills: skills,
         priceUsdcStroops: priceUsdcStroops,
         wallet: wallet,
         model: model,
       );

  /// Returns a shallow copy of this [AgentSummary]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentSummary copyWith({
    String? id,
    int? registryId,
    String? name,
    String? description,
    List<String>? skills,
    int? priceUsdcStroops,
    Object? wallet = _Undefined,
    Object? model = _Undefined,
  }) {
    return AgentSummary(
      id: id ?? this.id,
      registryId: registryId ?? this.registryId,
      name: name ?? this.name,
      description: description ?? this.description,
      skills: skills ?? this.skills.map((e0) => e0).toList(),
      priceUsdcStroops: priceUsdcStroops ?? this.priceUsdcStroops,
      wallet: wallet is String? ? wallet : this.wallet,
      model: model is String? ? model : this.model,
    );
  }
}
