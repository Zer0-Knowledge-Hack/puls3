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

/// One agent of the catalog, built from the identity registry metadata.
abstract class AgentSummary
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AgentSummary._({
    required this.id,
    required this.registryId,
    required this.name,
    required this.description,
    required this.skills,
    required this.priceUsdcStroops,
    this.wallet,
    this.model,
    double? rating,
    int? paidHireCount,
  }) : rating = rating ?? 4.0,
       paidHireCount = paidHireCount ?? 0;

  factory AgentSummary({
    required String id,
    required int registryId,
    required String name,
    required String description,
    required List<String> skills,
    required int priceUsdcStroops,
    String? wallet,
    String? model,
    double? rating,
    int? paidHireCount,
  }) = _AgentSummaryImpl;

  factory AgentSummary.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentSummary(
      id: jsonSerialization['id'] as String,
      registryId: jsonSerialization['registryId'] as int,
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String,
      skills: _ihzwmcdm.Protocol().deserialize<List<String>>(
        jsonSerialization['skills'],
      ),
      priceUsdcStroops: jsonSerialization['priceUsdcStroops'] as int,
      wallet: jsonSerialization['wallet'] as String?,
      model: jsonSerialization['model'] as String?,
      rating: (jsonSerialization['rating'] as num?)?.toDouble(),
      paidHireCount: jsonSerialization['paidHireCount'] as int?,
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

  /// The agent's rating from 1 to 5, computed by the #11 reputation function
  /// over its feedback. An agent without feedback has the #11 empty-input
  /// value (4.0). The default keeps summaries built without it valid.
  double rating;

  /// How many paid hires rated the agent: the feedback entries the #11
  /// function counted.
  int paidHireCount;

  /// Returns a shallow copy of this [AgentSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AgentSummary copyWith({
    String? id,
    int? registryId,
    String? name,
    String? description,
    List<String>? skills,
    int? priceUsdcStroops,
    String? wallet,
    String? model,
    double? rating,
    int? paidHireCount,
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
      'rating': rating,
      'paidHireCount': paidHireCount,
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
      'rating': rating,
      'paidHireCount': paidHireCount,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
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
    double? rating,
    int? paidHireCount,
  }) : super._(
         id: id,
         registryId: registryId,
         name: name,
         description: description,
         skills: skills,
         priceUsdcStroops: priceUsdcStroops,
         wallet: wallet,
         model: model,
         rating: rating,
         paidHireCount: paidHireCount,
       );

  /// Returns a shallow copy of this [AgentSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
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
    double? rating,
    int? paidHireCount,
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
      rating: rating ?? this.rating,
      paidHireCount: paidHireCount ?? this.paidHireCount,
    );
  }
}
