import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/registry_events.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:test/test.dart';

const _registry =
    'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ';
const _other = 'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';
const _owner = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

RpcEvent _event({
  required List<Object?> topics,
  required Object? value,
  String contractId = _registry,
  bool successful = true,
}) => RpcEvent(
  ledger: 5023604,
  contractId: contractId,
  topicJson: topics,
  valueJson: value,
  inSuccessfulContractCall: successful,
);

Object _bytes(List<int> bytes) => {
  'bytes': bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
};

Object _map(Map<String, Object?> fields) => {
  'map': [
    for (final entry in fields.entries)
      {
        'key': {'symbol': entry.key},
        'val': entry.value,
      },
  ],
};

List<RpcEvent> _fixtureEvents() {
  final json =
      jsonDecode(
            File(
              'test/unit/ledger/fixtures/get_events_registry_register_7.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final events = (json['result']! as Map)['events']! as List;
  return [
    for (final raw in events.cast<Map<String, Object?>>())
      RpcEvent(
        ledger: raw['ledger']! as int,
        contractId: raw['contractId']! as String,
        topicJson: raw['topicJson']! as List,
        valueJson: raw['valueJson'],
        inSuccessfulContractCall: raw['inSuccessfulContractCall'] == true,
        txHash: raw['txHash'] as String?,
      ),
  ];
}

void main() {
  final registry = StellarAddress.parse(_registry);

  test('parses a metadata_set event into its bytes', () {
    final events = parseRegistryEvents(
      [
        _event(
          topics: [
            {'symbol': 'metadata_set'},
            {'u32': 7},
            {'string': 'name'},
          ],
          value: _map({
            'value': _bytes(utf8.encode('Ledger Scout')),
          }),
        ),
      ],
      registry: registry,
    );

    final parsed = events.single as MetadataSetEvent;
    expect(parsed.agentId, 7);
    expect(parsed.key, 'name');
    expect(utf8.decode(parsed.value), 'Ledger Scout');
  });

  test('parses a registered event into owner and uri', () {
    final events = parseRegistryEvents(
      [
        _event(
          topics: [
            {'symbol': 'registered'},
            {'u32': 7},
            {'address': _owner},
          ],
          value: _map({
            'agent_uri': {'string': 'puls3://demo/agt-001'},
          }),
        ),
      ],
      registry: registry,
    );

    final parsed = events.single as RegisteredEvent;
    expect(parsed.agentId, 7);
    expect(parsed.owner.value, _owner);
    expect(parsed.uri, 'puls3://demo/agt-001');
  });

  test('parses a uri_updated event', () {
    final events = parseRegistryEvents(
      [
        _event(
          topics: [
            {'symbol': 'uri_updated'},
            {'u32': 9},
            {'address': _owner},
          ],
          value: _map({
            'new_uri': {'string': 'puls3://demo/agt-002'},
          }),
        ),
      ],
      registry: registry,
    );

    final parsed = events.single as UriUpdatedEvent;
    expect(parsed.agentId, 9);
    expect(parsed.uri, 'puls3://demo/agt-002');
  });

  test('skips another contract, a failed call and an unknown event', () {
    final events = parseRegistryEvents(
      [
        _event(
          contractId: _other,
          topics: [
            {'symbol': 'metadata_set'},
            {'u32': 1},
            {'string': 'name'},
          ],
          value: _map({'value': _bytes([1])}),
        ),
        _event(
          successful: false,
          topics: [
            {'symbol': 'metadata_set'},
            {'u32': 2},
            {'string': 'name'},
          ],
          value: _map({'value': _bytes([1])}),
        ),
        _event(
          topics: [
            {'symbol': 'something_else'},
            {'u32': 3},
          ],
          value: _map({'value': _bytes([1])}),
        ),
      ],
      registry: registry,
    );

    expect(events, isEmpty);
  });

  test('skips a malformed event without failing the page', () {
    final events = parseRegistryEvents(
      [
        _event(
          topics: [
            {'symbol': 'metadata_set'},
            {'u32': 7},
          ],
          value: _map({'value': _bytes([1])}),
        ),
        _event(
          topics: [
            {'symbol': 'metadata_set'},
            {'u32': 7},
            {'string': 'name'},
          ],
          value: _map({'nope': _bytes([1])}),
        ),
      ],
      registry: registry,
    );

    expect(events, isEmpty);
  });

  test('parses the recorded agent 7 registration', () {
    final events = parseRegistryEvents(_fixtureEvents(), registry: registry);

    expect(events, hasLength(8));
    expect(events.map((e) => e.agentId).toSet(), {7});
    expect(events.whereType<MetadataSetEvent>(), hasLength(7));
    final registered = events.whereType<RegisteredEvent>().single;
    expect(registered.owner.value, _owner);
    expect(registered.uri, 'puls3://demo/agt-001');
    final name = events.whereType<MetadataSetEvent>().firstWhere(
      (e) => e.key == 'name',
    );
    expect(utf8.decode(name.value), 'Ledger Scout');
  });
}
