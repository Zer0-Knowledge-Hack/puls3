# Flutter Web ↔ Stellar wallet spike

## Evidence status

**Transaction signing, auth-entry signing, and payment evidence are proven
live on Testnet (2026-09-30).**

| Boundary | Result |
|---|---|
| Dart unit tests and XDR fixtures | Automated; `flutter test` |
| Flutter analyzer and web build | Automated; `flutter analyze`, `flutter build web` |
| Freighter connect + transaction approval | Manual; passed 2026-09-30 |
| Account switch without reconnect | Manual; rejected with `WalletAccountChanged` |
| Live Testnet submission and terminal polling | Passed 2026-09-30 (ledger 4953089) |
| Unified SAC `transfer` event for a classic payment | Emitted by SDF Testnet RPC; verified |
| Freighter auth-entry approval (`ADDRESS_V2`) | Manual; passed 2026-09-30 (ledger 4953815) |

Live payment: 1 XLM from `GCCB4MKFLRRD4HBXNGMXQMIIU5TSYX2TBAQIQRIGE5LSILPW77E44GOZ`
to `GBB4PCYW57UQRKED36ZLOHB4PQMBD7QYEVQKXWYB6ER5LOMJ7I6MS4MT` with muxed id
68, transaction
[`820c8a98…d756b4`](https://stellar.expert/explorer/testnet/tx/820c8a985f219346bd7c5672d33b13b7621d384057098619ef82524501d756b4).
The recorded `getTransaction` and trimmed `getEvents` responses are test
fixtures under `spikes/flutter-stellar-wallet/test/fixtures/`, and
`PaymentEvidence.fromRpcResponses` verifies them.

## What the spike demonstrates

### Transaction signing

The Flutter Web adapter connects to Freighter on Testnet and binds every
signature request to the connected account. Immediately before prompting it
re-reads both the active address and network. Then, **before the wallet is
prompted**, it rejects with `PayloadAccountMismatch` any envelope whose
transaction source account or any explicit operation source account is not
the connected account. Muxed (`M...`) sources are compared by their
underlying `G...` account. This closes a gap found live: after switching the
Freighter account and reconnecting, the app previously signed an XDR prepared
for the other payer.

Envelope XDR that is empty, not base64, truncated, or followed by trailing
bytes is rejected with `InvalidEnvelope`, also before the prompt.

A signed transaction is accepted only when its body is unchanged and it
contains a **new**, cryptographically valid signature from that exact account
over the Testnet transaction hash.

### Authorization-entry signing

Freighter's `signAuthEntry` does not sign a `SorobanAuthorizationEntry`. It
takes the base64 XDR of a `HashIdPreimage` and returns an ed25519 signature
over `sha256(preimage)`. The Freighter guide documents the legacy
`ENVELOPE_TYPE_SOROBAN_AUTHORIZATION` preimage (network id, nonce,
`signatureExpirationLedger`, invocation).

SDF Testnet RPC now runs protocol 29 (stellar-rpc 29.0.0). Simulating a
native SAC `transfer` there returned **only `ADDRESS_V2` credentials**
(CAP-71). The JS SDK documents `useUpgradedAuth=false` as a no-op from
protocol 28 on, so legacy `ADDRESS` entries can no longer be requested from
Testnet. `ADDRESS_V2` entries are signed over
`ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS`, which adds the credential
address to the legacy fields.

`FreighterWallet.signAuthEntry(entryXdr)` therefore:

1. Parses the server-simulated entry. Non-canonical XDR or trailing bytes
   count as malformed (`InvalidEnvelope`).
2. Accepts legacy `ADDRESS` or `ADDRESS_V2` credentials for the connected
   `G...` account. Another address fails with `PayloadAccountMismatch`.
   Source-account credentials fail with `InvalidEnvelope`.
   `ADDRESS_WITH_DELEGATES` fails with `UnsupportedAuthCredentials`: every
   delegate node needs its own signature, so it is out of scope. The wallet
   is not prompted in any of these cases.
3. Builds the preimage for that arm with the SDK's `buildPreimage` (the same
   builder `SorobanAuthorizationEntry.sign` uses) from the Testnet network id,
   nonce, `signatureExpirationLedger`, `rootInvocation`, and for V2 the
   address. It then sends the preimage's base64 XDR to the bridge.
4. Rejects a wallet-reported `signerAddress` that differs from the session
   (`WalletAccountChanged`) and any signature that is not 64 bytes or does
   not verify against the session key over `sha256(preimage)`
   (`InvalidEnvelope`).
5. Attaches the signature the way `SorobanAuthorizationEntry.sign` does in
   `stellar_flutter_sdk` 3.8.0: a `Vec` of `{public_key, signature}` maps,
   appended to any existing vector. The credential arm is preserved (V2 is
   never downgraded to legacy). Tests assert that the result is
   byte-identical to the SDK signing the same legacy and V2 entries with the
   same key.

The server must still validate contract, function, arguments, nonce, and
expiration against its own intent before submission. Simulation returns
`signatureExpirationLedger: 0`, so the server must set a real expiration
before handing the entry to the wallet. The wallet signs whatever expiration
it is given.

**Verified live 2026-09-30:** Freighter 6.x signed an `ADDRESS_V2` entry
over the `ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS` preimage, even
though its guide shows only the legacy type. Its "Confirm Authorizations"
popup showed the authorized address. The signed entry verified in Dart and
the SAC `transfer` it authorized succeeded in
[`731fdb98…62650e`](https://stellar.expert/explorer/testnet/tx/731fdb98f97db64e48200999ba852ec3136dc3848dfa07c95a9958bfde62650e)
(ledger 4953815).

**Not recorded:** the exact runtime shape of `signedAuthEntry` returned by
the Freighter extension. freighter-api 6.0.1 forwards the extension's
`postMessage` payload unchanged, so `web/freighter_bridge.js` normalizes a
base64 string, a `Uint8Array`/`ArrayBuffer`, or a JSON-serialized Node
`Buffer` (`{type: 'Buffer', data: [...]}`) to base64. The live signature
verified, so it arrived in one of these shapes; which one was not logged.
Dart verifies the signature, so an unexpected shape fails closed.

### Production adapter (#69)

The spike adapter above stays as reviewed. The production adapter that
replaced it in #113 (`puls3_flutter/lib/src/wallet/freighter/freighter_wallet.dart`)
closes the #69 findings. Each case below is refused with
`WalletInvalidPayload` before Freighter is called, and its test in
`puls3_flutter/test/wallet/freighter_wallet_test.dart` asserts that the
bridge was never called (`signCalls == 0` / `authCalls == 0`):

| Guarantee | Test |
|---|---|
| A fee-bump envelope is refused (only standard `Transaction` envelopes are signed) | `#69: refuses a fee-bump envelope before the prompt` |
| An auth entry with `signatureExpirationLedger == 0` is refused | `#69: refuses an entry without an expiration ledger` |
| An auth entry followed by trailing bytes is refused | `#69: refuses trailing bytes before the prompt` |
| An auth entry with contract-address credentials is refused | `#69: refuses contract-address credentials` |

Legacy `ADDRESS` signing still passes there (`signs the preimage like the
SDK signer`); `ADDRESS_V2` signing is covered by the spike tests. The spike
adapter's own tests do not cover the four cases above, so these guarantees
hold for the production adapter only.

## Automated verification

Use Flutter 3.35+ / Dart 3.8+ and `stellar_flutter_sdk` 3.8.0:

```text
cd spikes/flutter-stellar-wallet
flutter pub get
flutter analyze
flutter test
flutter build web
```

The tests cover account switches, wrong networks, source and operation-source
account binding (including muxed sources), unchanged envelopes,
pre-existing-only signatures, unrelated signers, modified transaction bodies,
auth-entry preimage construction and signature verification, malformed XDR
(including trailing bytes after a transaction envelope), failed
transactions, mismatched hashes/payment fields, `getEvents` cursor
pagination, the recorded live Testnet responses, and that the harness command
compiles on the Dart VM.

## Manual browser proof

1. Install Freighter 6.x, create/import a Testnet account, and select Testnet.
2. Run `flutter run -d chrome` from `spikes/flutter-stellar-wallet`.
3. Select **Connect Freighter** and record the displayed public address.
4. Paste a server-prepared Testnet transaction XDR whose source is that
   address and select **Sign transaction**.
5. Confirm the Freighter summary, approve it, and record whether the app
   accepts the returned XDR.
6. Repeat after switching accounts. Expected result: the app rejects the
   request (`WalletAccountChanged` without reconnecting,
   `PayloadAccountMismatch` after reconnecting with the old payload).
7. Paste a server-simulated `SorobanAuthorizationEntry` XDR for the connected
   account and select **Sign auth entry**. Record approval or the exact
   stable failure kind.

Never place a seed phrase or secret key in the app, logs, fixtures, command
history, or repository.

## Live RPC harness

After browser signing, save only the signed envelope XDR to a temporary file.
From `spikes/flutter-stellar-wallet` run:

```text
dart run bin/rpc_payment_harness.dart \
  <rpc-url> <signed-xdr-file> <asset-contract-id> <payer-g-address> \
  <destination-g-address> <muxed-id> <amount-stroops>
```

Without arguments it prints usage and exits 64. Non-integer amounts or ids
also exit 64; an unreadable or invalid XDR file exits 65.

**Why it runs on the plain Dart VM.** The `stellar_flutter_sdk` 3.8.0 barrel
exports its smart-account storage adapter, which imports
`package:flutter/services.dart` and therefore `dart:ui`. The Dart VM cannot
compile that. `lib/stellar_sdk_vm.dart` re-exports only the Flutter-free SDK
libraries that the harness and `payment_evidence.dart` need. These are `src/`
paths, kept stable by the exact `3.8.0` pin; revisit the list on every SDK
upgrade. This was chosen over running the harness through
`flutter test --dart-define=...` because it keeps a normal CLI with exit codes
and real network I/O in one command. `test/rpc_payment_harness_test.dart`
runs the command and fails if `dart:ui` reappears.

The harness submits the envelope and polls up to 30 seconds for a terminal
status. It then queries `getEvents` **from the transaction's own ledger**
(from `getTransaction`) and pages with the RPC cursor until that ledger is
exhausted, keeping only the transaction's rows. The native XLM SAC is busy
enough that a single 100-event page from an earlier ledger missed the
transaction live. A read-only recheck of ledger 4953089 with limit 10 needed
3 pages and verified. Finally it decodes transaction meta and event XDR,
validates the hash/asset/payer/destination/muxed id/amount, and prints a
Testnet explorer URL. A timeout, `FAILED`, absent event, RPC error, exhausted
page budget, malformed XDR, or mismatch is a failed proof—not partial success.

## Payment architecture correction

Protocol 23 / CAP-67 changed SAC `transfer` so its `to` parameter accepts a
`MuxedAddress`. A Soroban `Address` limitation therefore does **not** forbid
this payment path. The SAC strips the muxed id for ledger balance movement and
emits the underlying destination in the `to` topic plus `to_muxed_id` in the
event data map.

The spike prepares a classic payment as one valid route. **SDF Testnet RPC
(`https://soroban-testnet.stellar.org`) emitted the unified SAC `transfer`
event for the live classic payment**, from the native SAC
`CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC`, with topics
`["transfer", from, to, "native"]` and data
`{amount: 10000000, to_muxed_id: 68}`. In `TransactionMetaV4` that event
sits in `operations[].events`, while fee events sit in the transaction-level
`events`; the verifier reads both and accepts the SEP-11 asset as an optional
fourth topic. Any other provider must still confirm that it runs with
`EMIT_CLASSIC_EVENTS=true`. Without the event, the verifier fails closed
rather than fabricating asset or muxed evidence. The server remains
responsible for submission, durable polling, replay protection, and
persistence.

## Bridge contract and stable failures

The JavaScript bridge exchanges JSON payloads with Dart. Sessions:

```json
{"address":"G...","networkPassphrase":"Test SDF Network ; September 2015"}
```

Auth-entry preimage signatures (`puls3FreighterSignAuthEntryPreimage`):

```json
{"signature":"<base64 64-byte ed25519 signature>","signerAddress":"G..."}
```

Bridge failures use stable machine-oriented prefixes such as `wrong_network`
and `account_changed`; Dart exposes typed `WalletFailure` variants
(`WalletUnavailable`, `WalletRejected`, `WrongNetwork`,
`WalletAccountChanged`, `PayloadAccountMismatch`,
`UnsupportedAuthCredentials`, `InvalidEnvelope`, `ModifiedEnvelope`). Human
text may change without becoming application
control flow.

The CDN-pinned Freighter API module is acceptable only for this isolated
spike. Production must bundle/vendor the exact dependency and enforce CSP and
supply-chain controls. Flutter mobile requires a separate deep-link or wallet
adapter.

## Recommended changes for #8 and ADR-0003

These are recommendations only. No production endpoint is implemented here.
Each one names the section it changes and the spike evidence behind it.
"Verified" means it was observed on SDF Testnet on 2026-09-30 or covered by
the spike's tests; anything else is marked **unverified**.

### ADR-0003 ([`docs/adr/0003-payment-rail-and-custody.md`](../adr/0003-payment-rail-and-custody.md))

1. **Decision 1 (rail): allow a classic `payment` to the `M…` address as an
   equivalent route.** Verified: a classic payment of native XLM to a muxed
   address emitted the unified SAC `transfer` event with `to_muxed_id` on SDF
   Testnet RPC (tx `820c8a98…`). It needs no simulation and no auth entry, and
   Freighter signed the server-prepared envelope unchanged. The Soroban
   `transfer` invocation also works: Freighter signed its `ADDRESS_V2` auth
   entry and the transfer succeeded (tx `731fdb98…`). **Unverified:** both
   routes with USDC. The asset topic would be `USDC:<issuer>` instead of
   `native`; prove this in #19 before relying on it.
2. **Decision 3 (verification): state where and how the event is read.**
   Verified: in `getTransaction`, the `transfer` event is in
   `TransactionMetaV4.operations[].events`. The transaction-level `events`
   hold only the fee events. The SAC event has **4 topics**:
   `["transfer", from, to, asset]`. `to` is the underlying `G…` account and
   the data is a map `{amount, to_muxed_id}`. A 3-topic parser rejected the
   real event. One `getTransaction` call is therefore enough, as the ADR
   intends. **Unverified:** the `xdrFormat: "json"` shape. The spike decoded
   the base64 XDR with the SDK.
3. **Decision 3: add a seventh check, "the `from` topic equals the hire's
   consumer wallet".** The ADR lists six checks without a payer check, while
   #8 already defines `PaymentNotFromConsumer`. The spike verifier matches
   `from` and rejects a mismatch (tested).
4. **Decision 3: if `getEvents` is used as a cross-check, query from the
   transaction's own ledger and page with the cursor.** Verified: the native
   SAC produced 27 events in ledger 4953089. One 100-event page from an
   earlier start ledger missed the transaction, and the fee and transfer
   events of one transaction are not contiguous. The spike's
   `collectTransactionEvents` fails closed on RPC errors, missing cursors,
   and exhausted page budgets.
5. **Decision 3 / #30: require classic-event emission from the RPC
   provider.** Verified only for `https://soroban-testnet.stellar.org`. Any
   other or hosted provider must confirm `EMIT_CLASSIC_EVENTS=true`. Without
   the event, verification fails closed and the hire cannot be paid.
6. **Decision 5 (server chain access): do not add `stellar_flutter_sdk` to
   Serverpod.** Verified: its 3.8.0 `pubspec.yaml` depends on the Flutter
   SDK, and its barrel imports `package:flutter/services.dart` (`dart:ui`),
   so `dart run` fails to compile. Importing only its Flutter-free `src/`
   libraries (`lib/stellar_sdk_vm.dart`) works on the Dart VM inside a
   Flutter toolchain. This was verified for RPC reads, XDR decoding, and
   evidence checks. Keep the ADR's plain-HTTP RPC plus `stellar_dart` plan
   and pin exact SDK versions. **Unverified:** `stellar_dart` itself, and
   harness submission through `sendTransaction`.
7. **Decision 6 (`set_agent_wallet` row): specify the auth-entry protocol.**
   Verified: Testnet is on protocol 29 and simulation returns **only
   `ADDRESS_V2`** credentials. Legacy opt-out is a no-op from protocol 28.
   Freighter 6.x signs the `ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS`
   preimage and its popup shows the authorized address. The server must:
   - accept `ADDRESS_V2` when assembling the transaction;
   - set `signatureExpirationLedger` before sending the entry, because
     simulation returns `0`;
   - re-verify address, network, contract, function, arguments, nonce,
     expiration, and signature before submission.

   `ADDRESS_WITH_DELEGATES` stays unsupported.
8. **Consequences, #25 row: record the proven wallet-adapter requirements.**
   Verified for Freighter 6.x on Flutter Web:
   - signing is bound to the connected account and network;
   - a transaction or operation source that is not the connected account is
     rejected before the prompt (muxed-aware);
   - trailing bytes after a transaction envelope are rejected before the
     prompt;
   - the signed envelope must be unchanged and carry a new valid signature.

   The production adapter adds the #69 guarantees (see "Production adapter
   (#69)" above). Production must still bundle the Freighter API and enforce
   CSP. Mobile needs a separate wallet adapter.

### #8 API contract draft ([`docs/architecture/api.md`](../architecture/api.md), provisional)

1. **`StudioEndpoint.prepareWalletAuthorization` /
   `DeploySession.authorizationEntryXdr`:** document the returned value as a
   simulated `ADDRESS_V2` `SorobanAuthorizationEntry` for the builder's
   wallet, with a server-set non-zero `signatureExpirationLedger`. This is
   based on recommendation 7 above.
2. **`StudioEndpoint.completeDeploy` errors:** define what
   `InvalidAuthorizationEntry` covers:
   - wrong credential type;
   - address is not the session wallet;
   - network, contract, function, arguments, or nonce differ from what the
     server prepared;
   - expired entry;
   - signature does not verify over the arm's preimage.

   Alternatively, add a separate `AuthorizationExpired` so Flutter can
   re-prepare instead of failing.
3. **F5-4 and product question 2 (who builds and submits):** the verified
   path is a **server-prepared** unsigned envelope that the wallet signs
   unchanged. Consider adding `unsignedTransactionXdr` to
   `PaymentInstruction`, with the consumer as the transaction source.
   Building the transaction in the client is **unverified** in this spike.
   Either way, `confirmPayment` must verify on chain, so submission can stay
   in the app.
4. **`HireEndpoint.confirmPayment` errors:** map the evidence checks to the
   existing codes:
   - asset contract → `WrongAsset`;
   - `to` topic → `WrongDestination`;
   - `amount` → `WrongAmount`;
   - `to_muxed_id` → `WrongHireReference`;
   - `from` → `PaymentNotFromConsumer`.

   Add a distinct code (e.g. `PaymentEvidenceUnavailable`) for "transaction
   succeeded but no unified `transfer` event was found". It is not a
   transient `ChainUnavailable`, and retrying will not fix a provider without
   classic events (recommendation 5).
5. **`Payment` model (`models/payment.spy.yaml`):** document that `payee` is
   the underlying `G…` agent wallet from the `to` topic, not the `M…`
   address. The hire reference comes from `to_muxed_id` (= `hireId`). This
   is verified from the live event.
6. **Flow rows F1-4, F4-7, F5-4:** state that the wallet's pre-prompt
   rejections are client-only outcomes with no endpoint call:
   `WrongNetwork`, `WalletAccountChanged`, `PayloadAccountMismatch`,
   `InvalidEnvelope`, and `UnsupportedAuthCredentials`. The fix for each is
   to reconnect or re-prepare. **Unverified:** the F1-3 wallet challenge
   signature (`signMessage`) was not exercised by this spike.

## Sources verified 2026-09-30

- [Freighter transaction signing](https://developers.stellar.org/docs/build/guides/freighter/prompt-to-sign-tx)
- [Freighter authorization-entry signing](https://developers.stellar.org/docs/build/guides/freighter/sign-auth-entries)
- [SAC payments to muxed addresses](https://developers.stellar.org/docs/tokens/stellar-asset-contract#sending-to-a-muxed-address)
- [Muxed accounts](https://developers.stellar.org/docs/build/guides/transactions/pooled-accounts-muxed-accounts-memos#muxed-accounts)
- [Horizon-to-RPC event migration](https://developers.stellar.org/docs/data/apis/migrate-from-horizon-to-rpc#endpoint-mapping)
- [RPC data formats](https://developers.stellar.org/docs/data/apis/rpc/api-reference/structure/data-format#json-format)

Scout also identified the community-maintained
[Soneso Flutter Wallet SDK](https://github.com/soneso/stellar_wallet_flutter_sdk).
It is discovery evidence only and is not a dependency of this spike.
