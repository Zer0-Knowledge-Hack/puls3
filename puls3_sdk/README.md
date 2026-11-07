# puls3_sdk

Dart SDK for the puls3 API. It reads the catalog and, in later parts, prepares
hire and Studio calls. **It never signs or submits a transaction.** The design
is [ADR-0007](../docs/adr/0007-developer-sdk.md).

This version covers the catalog, which needs no session. Hire and Studio
calls wait for the session decision in ADR-0007.

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
