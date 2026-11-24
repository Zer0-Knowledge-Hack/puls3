# puls3_sdk

Dart SDK for the puls3 API: the catalog, the start of a hire, and the hire and
Studio calls that prepare unsigned transactions. **It never signs or submits a
transaction.** The design is [ADR-0007](../docs/adr/0007-developer-sdk.md).

The catalog needs no session. Everything that acts for a wallet (hire and Studio
calls) needs a CLI session; see the [quickstart](../docs/sdk/quickstart.md) and
[CLI sessions](../docs/sdk/sessions.md).

## Use it from this repo

`puls3_sdk` is a workspace member and is not on pub.dev yet. From another
package in this repo:

```yaml
dependencies:
  puls3_sdk:
    path: ../puls3_sdk
```

A package in this workspace also needs `resolution: workspace` and an entry in
the root `pubspec.yaml`.

```dart
import 'package:puls3_sdk/puls3_sdk.dart';

final sdk = Puls3Sdk.connect(
  Uri.parse('https://puls3-hub-on-stellar.api.serverpod.space/'),
);
try {
  final agents = await sdk.listAgents();
  final scout = await sdk.getAgent('agt-001'); // null for an unknown id
} on AgentCatalogUnavailable catch (e) {
  // The catalog is down. It is never reported as an empty list.
} finally {
  sdk.close();
}
```

## Start a hire

With a session, `createHire` returns the persisted hire and, when available, its
unsigned `create_job`. `prepareCreateJob` asks for a fresh envelope, and
`prepareFund` returns the unsigned `fund`. Repeat the same `requestId` to retry
safely: the server returns the same hire. The key is opaque, so the SDK sends it
exactly as given. Repeating it with a different agent or input is rejected by
the server (`InvalidHire`), which reaches you as a `Puls3ApiException`.

```dart
final start = await sdk.createHire(agentId, wallet, input, requestId);
final createJob =
    start.preparedCreateJob ?? await sdk.prepareCreateJob(start.hire.id);
final fund = await sdk.prepareFund(start.hire.id);
```

`createJob` and `fund` are `PreparedTransaction`s: the wallet signs them; the
SDK does not. `getHire`, `prepareComplete` and `prepareReject` cover the rest of
the lifecycle.

## Run the example

```bash
cd puls3_sdk
PULS3_API_URL=https://puls3-hub-on-stellar.api.serverpod.space/ \
  dart run example/list_catalog.dart
```

## Checks

```bash
dart analyze --fatal-infos
dart test
```

In this workspace `dart pub deps` lists every member, including the Flutter
app, so `dart pub deps | grep -i flutter` is not a test of this package. To
list only what `puls3_sdk` depends on:

```bash
dart pub deps --json | python3 -c "
import sys, json
d = json.load(sys.stdin); pk = {p['name']: p for p in d['packages']}
seen, stack = set(), ['puls3_sdk']
while stack:
    n = stack.pop()
    if n in seen or n not in pk: continue
    seen.add(n); stack += pk[n].get('dependencies', [])
print(sorted(x for x in seen if 'flutter' in x) or 'no flutter')"
```

## Contract tests against the server

The tests above run against fakes. Fakes cannot tell when the SDK sends something the server reads differently, so the server's integration suite also drives this SDK over HTTP (#375): `puls3_server/test/integration/sdk_contract_test.dart`.

Each test goes through the SDK, a CLI session minted by the real wallet sign-in (a fixed test key, no real wallet), the real endpoints and the test database. Only the chain is faked. It compares what the SDK sends with what the server stores.

Run it with the test database up (`docker compose up -d postgres_test redis_test` in `puls3_server/`):

```bash
cd puls3_server && dart test test/integration/sdk_contract_test.dart
```

CI runs it in the `server` job, which also runs when `puls3_sdk/` or `puls3_mcp/` change. If you change what a call sends (trimming, argument order, error mapping), update the matching test there.
