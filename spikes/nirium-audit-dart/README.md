# Nirium receipt spike (#246, #274)

This standalone Dart package anchors a puls3 receipt for a settled escrow job
on Nirium's Audit Trail and verifies it without calling Nirium. The verdict
and the evidence are in
[`docs/spikes/nirium-audit.md`](../../docs/spikes/nirium-audit.md).

The package is not part of the workspace and does not touch `puls3_server`.
It is where the Nirium work stays until the team decides to build on it.

## Checks

```bash
dart pub get
dart analyze
dart test
```

The tests use fixtures and make no network calls. The fixtures are:

- the `complete` transaction of job 3 from Horizon;
- escrow job 3 from Soroban RPC (`getLedgerEntries`);
- the two documents Nirium's gateway served for our anchors, byte for byte
  (`*.ipfs`, marked binary in `.gitattributes`), so their CIDs recompute;
- two signed documents from Nirium's repository.

## Run against testnet

Anchoring writes to IPFS, so it is public and permanent. Anchor only a record
built from public chain data, which is the only kind this CLI builds.

```bash
# A throwaway attesting key; *.secret is gitignored.
dart run bin/receipt.dart keygen --out attester.secret

TX=ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4

# Anchor the full record (default) or only its hash (--mode hash).
dart run bin/receipt.dart anchor --tx $TX --registry-id 7 --key-file attester.secret

# Verify from IPFS: the CID, the hash, puls3's signature, the transaction on
# Horizon and the escrow job on Soroban RPC.
# A hash-only anchor also needs --record out/<cid>.json.
dart run bin/receipt.dart verify --cid <cid> --key <attesting G… key>

# Twenty anchors under the 20-a-minute limit, then verify them again later.
dart run bin/receipt.dart measure --tx $TX --registry-id 7 \
  --key-file attester.secret --mode hash --count 20
dart run bin/receipt.dart reverify --measure out/measure-hash-<ts>.json \
  --key <G…> --record out/<cid>.json
```

## The receipt queue (#274)

`lib/src/queue.dart` is how a server would anchor a receipt for every settled
hire without the hire waiting for it. It still lives here, outside
`puls3_server`, until the team decides whether to build on Nirium.

- A hire only **queues** its `complete` transaction: one row, no network call.
- A pass (`runOnce`, from a timer) **anchors** what is pending. A 429, a 5xx or
  a network error is retried with a pause that doubles from 30 seconds to one
  hour. Another 4xx, or a transaction that is not a settlement, fails at once.
- 15 minutes later a pass **verifies** the receipt from IPFS and the chain. A
  CID that cannot be read yet, or a chain that does not answer, is retried. A
  readable document that is wrong fails and is never shown as verified.
- A step gives up after 12 tries. The queue is one JSON file, rewritten
  through a temporary file, so it survives a restart. It never holds the key.

```bash
dart run bin/receipt.dart queue-add --tx $TX
dart run bin/receipt.dart queue-run --key-file attester.secret   # anchors
dart run bin/receipt.dart queue-status
# 15 minutes later (or pass --verify-after 0 to try at once):
dart run bin/receipt.dart queue-run --key-file attester.secret   # verifies
```

`queue-run` exits 1 when a receipt failed in that pass. Run it from a loop or
a scheduler to act as the timer.

## The sandbox (#296)

`bin/sandbox.dart` runs the queue end to end with **no call to Nirium**. It
starts a Nirium node on `localhost` (`lib/src/local_node.dart`): the same two
requests as the real node, documents kept in memory, and each CID computed
from the bytes it serves. The queue, `NiriumAuditClient` and `IpfsReader` are
the real ones and talk HTTP to it. The chain is only read (Horizon and Soroban
RPC, testnet by default).

```bash
dart run bin/sandbox.dart                      # job 3 of the spike, every scenario
dart run bin/sandbox.dart --tx <hash> --scenario happy --scenario restart
dart run bin/sandbox.dart --mode hash          # anchor only the hash
dart run bin/sandbox.dart --horizon http://localhost:8000/ \
  --rpc http://localhost:8000/rpc --network stellar:standalone --tx <hash>
```

Without `--key-file` it signs with a key made for that run and never written.
The queue's waits are not slept through: the clock jumps to the moment a
receipt is due, so a run takes seconds. It exits 0 when every scenario ended
in the state it expects:

| Scenario | What the local node does | Must end |
|---|---|---|
| `happy` | nothing unusual | verified |
| `rateLimit` | answers 429 to the first two anchors | verified |
| `outage` | answers 503 to the first anchor | verified |
| `slowIpfs` | serves 404 for the first two reads | verified |
| `restart` | (a new queue over the same file after the anchor) | verified |
| `otherBytes` | serves bytes that do not hash to the CID | failed |
| `otherKey` | (the receipt is anchored by another key) | failed |

`verify` exits 0 for a trusted receipt. Otherwise it exits 1 and prints each
reason on stderr.
