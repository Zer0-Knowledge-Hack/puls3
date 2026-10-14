import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import '../ledger/xdr_invoke_encoder.dart';

/// Arguments of `register_full(caller, agent_uri, metadata)`.
///
/// The catalog and hire read `id`, `name`, `description`, `skills`,
/// `priceUsdcStroops`, `model` and `puls3.manifestVersion` as UTF-8.
/// `manifestHash` is the raw SHA-256 of the draft document. The prompt
/// stays off the chain.
List<ScArg> registerFullArgs({
  required StellarAddress caller,
  required String agentUri,
  required Uint8List manifestHash,
  required AgentManifest manifest,
  required String catalogId,
}) => [
  ScArg.address(caller),
  ScArg.string(agentUri),
  ScArg.vec([
    _entry('id', catalogId),
    _entry('name', manifest.name),
    _entry('description', manifest.description),
    _entry(
      'skills',
      jsonEncode([for (final skill in manifest.skills) skill.id]),
    ),
    _entry('priceUsdcStroops', manifest.price.stroops.toString()),
    _entry('model', manifest.model.id),
    _entry('puls3.manifestVersion', manifest.version.value.toString()),
    ScArg.map({
      'key': const ScArg.string('manifestHash'),
      'value': ScArg.bytes(manifestHash),
    }),
  ]),
];

ScArg _entry(String key, String value) => ScArg.map({
  'key': ScArg.string(key),
  'value': ScArg.bytes(Uint8List.fromList(utf8.encode(value))),
});

/// Arguments of `set_metadata(caller, agent_id, key, value)`.
///
/// One key per call. The builder is the source account, so the existing
/// envelope signature covers it.
List<ScArg> setMetadataArgs({
  required StellarAddress caller,
  required int agentId,
  required String key,
  required Uint8List value,
}) => [
  ScArg.address(caller),
  ScArg.u32(agentId),
  ScArg.string(key),
  ScArg.bytes(value),
];

/// Arguments of `set_agent_wallet(caller, agent_id, new_wallet)`.
List<ScArg> setAgentWalletArgs({
  required StellarAddress caller,
  required int agentId,
  required StellarAddress newWallet,
}) => [
  ScArg.address(caller),
  ScArg.u32(agentId),
  ScArg.address(newWallet),
];
