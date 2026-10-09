import '../agent/registry_event_reader.dart';
import 'registry_events.dart';
import 'soroban_rpc_client.dart';
import 'stellar_config.dart';

/// One `getEvents` page holds at most this many events.
const _pageLimit = 100;

/// A safety bound on pages read for one [eventsSince] call, so a node that
/// always returns a cursor cannot loop forever. Hitting it reports
/// [RegistryEventBatch.truncated].
const _maxPages = 1000;

/// [RegistryEventReader] over Soroban RPC `getEvents` and `getLatestLedger`.
///
/// Pages are followed with the node's cursor until a page is not full. Only
/// events the configured identity registry emitted are returned.
final class SorobanRegistryEventReader implements RegistryEventReader {
  SorobanRegistryEventReader(this._rpc, this._config);

  final SorobanRpcClient _rpc;
  final StellarConfig _config;

  @override
  Future<int> latestLedger() => _rpc.getLatestLedger();

  @override
  Future<RegistryEventBatch> eventsSince(int startLedger) async {
    final registry = _config.identityRegistry;
    final all = <RegistryEvent>[];
    String? cursor;
    var pages = 0;
    var truncated = false;
    while (true) {
      final page = await _rpc.getEvents(
        startLedger: cursor == null ? startLedger : null,
        cursor: cursor,
        filters: [
          RpcEventFilter(contractIds: [registry.value]),
        ],
        limit: _pageLimit,
      );
      all.addAll(parseRegistryEvents(page.events, registry: registry));
      pages++;
      if (page.events.length < _pageLimit) break;
      cursor = page.cursor;
      if (cursor == null) break;
      if (pages >= _maxPages) {
        truncated = true;
        break;
      }
    }
    return RegistryEventBatch(events: all, truncated: truncated);
  }
}
