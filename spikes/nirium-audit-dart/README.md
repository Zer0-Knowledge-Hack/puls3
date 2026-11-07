# Nirium receipt spike (#246)

This standalone Dart package anchors a puls3 receipt for a settled escrow job
on Nirium's Audit Trail and verifies it without calling Nirium. The verdict
and the evidence are in
[`docs/spikes/nirium-audit.md`](../../docs/spikes/nirium-audit.md).

The package is not part of the workspace and does not touch `puls3_server`.

## Checks

```bash
dart pub get
dart analyze
dart test
```

The tests use fixtures and make no network calls. The fixtures are the
`complete` transaction of job 3 from Horizon, and two signed documents from
Nirium's repository.

## Run against testnet

Anchoring writes to IPFS, so it is public and permanent. Anchor only a record
built from public chain data, which is the only kind this CLI builds.

```bash
# A throwaway attesting key; *.secret is gitignored.
dart run bin/receipt.dart keygen --out attester.secret

TX=ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4

# Anchor the full record (default) or only its hash (--mode hash).
dart run bin/receipt.dart anchor --tx $TX --registry-id 7 --key-file attester.secret

# Verify from IPFS: the hash, puls3's signature, and the transaction on Horizon.
# A hash-only anchor also needs --record out/<cid>.json.
dart run bin/receipt.dart verify --cid <cid> --key <attesting G… key>

# Twenty anchors under the 20-a-minute limit, then verify them again later.
dart run bin/receipt.dart measure --tx $TX --registry-id 7 \
  --key-file attester.secret --mode hash --count 20
dart run bin/receipt.dart reverify --measure out/measure-hash-<ts>.json \
  --key <G…> --record out/<cid>.json
```

`verify` exits 0 for a trusted receipt. Otherwise it exits 1 and prints each
reason on stderr.
