# Spike: a Dart x402 client for Stellar (#164)

## Verdict: go, Dart-native

A Dart client paid TIA's testnet x402 API and got the data back, with no
TypeScript in the payment path. It reads the 402 terms, checks them against
an allow-list, simulates the SAC `transfer`, signs the payer's authorization
entry and retries with `PAYMENT-SIGNATURE`. TIA's facilitator settled each
payment on Stellar Testnet. ADR-0006 D5 therefore takes the Dart-native path
and the testnet sidecar is not needed.

The code is in [`spikes/x402-dart/`](../../spikes/x402-dart/). It is a
standalone package and does not touch `puls3_server`.

## Evidence (Stellar Testnet, 2026-11-05)

Payer `GCGLWML52UWN6ZFFY24NW73XDWUFSFKDACGZ2YRU3WBLTYGARD3EUSEB`, a
throwaway testnet account. Recipient: TIA's `payTo`
`GB6GCGWLKAMGQI2D7VIO2VLZFREBJBGCAP7E7ZGXHWWNZIXWLPX5YO7Q`. Asset: testnet
USDC SAC `CBIELTK6…DAMA`.

| Client | Call | Amount | HTTP | Settlement |
|---|---|---|---|---|
| Dart | `GET /v1/quote?amount=100` | 0.10 USDC | **200** | [`fe670aa1…0ec922`](https://stellar.expert/explorer/testnet/tx/fe670aa1d3e0ae330bcaa84efad7fa86de3e5216dd722c427e1fb510bd0ec922) |
| Dart | `GET /v1/route?amount=100` | 0.25 USDC | 504 | [`b036bbfb…f316a1`](https://stellar.expert/explorer/testnet/tx/b036bbfb5433a0e0b9bc80504ecc65e60f9e6a72eecae5d1142dd5f16df316a1) |
| Dart | `GET /v1/route?amount=100` | 0.25 USDC | **200** | [`1d67da44…9dd90d`](https://stellar.expert/explorer/testnet/tx/1d67da44845eac2ea1e0f5f80ad40a53463387be2f2b44d0f6e74357b99dd90d) |
| `@x402/fetch` 2.30.0 | `GET /v1/quote?amount=100` | 0.10 USDC | 504 | [`ed488c44…81afc4`](https://stellar.expert/explorer/testnet/tx/ed488c44ae004e2a24c6ba361d73d8faf744d1d9cc118368fefdd7a7eb81afc4) |
| `@x402/fetch` 2.30.0 | `GET /v1/quote?amount=100` | 0.10 USDC | 504 | [`768664b5…f8bc9e`](https://stellar.expert/explorer/testnet/tx/768664b53680dd61f464bbb34c6997ec4fd214ed0aea693e8cd6eb0761f8bc9e) |
| `@x402/fetch` 2.30.0 | `GET /v1/quote?amount=100` | 0.10 USDC | **200** | [`901fed78…112b34`](https://stellar.expert/explorer/testnet/tx/901fed78b842d03d463f209a404ae4edcb24841a0fe12ac93aeec1ee6c112b34) |

Each settlement is one `transfer` that debits the payer and credits TIA's
`payTo` by the exact amount (checked with Horizon's effects). The facilitator
was the transaction source and paid the fee; the payer spent no XLM.

The Dart signed entry for the first call had expiration ledger 5575791,
signed at ledger 5575731: 60 ledgers, that is `maxTimeoutSeconds` 300 at the
measured 5 s a ledger.

## Problem on TIA's side: paid calls that return 504

Three of the six paid calls got a Vercel `504 FUNCTION_INVOCATION_TIMEOUT`
**after** the payment had settled. The payer paid and got no data. The
official TypeScript client hit it twice out of three, the Dart client once
out of three, so it is not a client problem. A paid call took 29–56 s end to
end, most of it on TIA's side, which is close to a serverless time limit.

TIA should hear about this before puls3 agents pay it for real: a provider
that settles before it serves, and then times out, takes the agent's money
for nothing. For the runtime (#20) it means:

- A 5xx without a `PAYMENT-RESPONSE` header does not prove the payment did
  not happen. The runtime must check the chain (or the facilitator) before
  it retries, or it pays twice.
- The per-hire cap (ADR-0006 D6) must count these payments.

## What the client checks before it signs

- **Terms** (before anything else): `x402Version` 2, scheme `exact`, the
  configured network, an allowed asset, an allowed `payTo`, an amount at or
  below the maximum, `maxTimeoutSeconds` within the limit, and
  `areFeesSponsored: true`. Otherwise it throws `TermsRejected` and signs
  nothing.
- **The simulated authorization**: exactly one entry, an address credential
  for the payer's account, no signature yet, and an invocation byte-equal to
  `transfer(payer, payTo, amount)` on the asset with no sub-invocations.
  Otherwise it throws `UnexpectedAuthorization` and signs nothing. This stops
  a lying RPC from getting a signature for another call.
- **The expiration**: the current ledger plus `maxTimeoutSeconds` divided by
  the measured ledger close time, rounded down. It is never zero.

## What `stellar_dart` 2.3.0 could and could not do

| Need | `stellar_dart` 2.3.0 | The spike |
|---|---|---|
| Parse an `S…` key, derive the `G…` address | Yes (`StellarPrivateKey.fromBase32`) | Used |
| ed25519 signature | Yes (`StellarPrivateKey.sign`) | Used |
| Decode `G…`/`C…` strkeys to raw bytes | Yes (`StellarAddress.fromBase32Addr`) | Used |
| `SorobanAuthorizationEntry` with `ADDRESS` credentials | Model exists | Not used: the spike edits the entry as bytes |
| `ADDRESS_V2` credentials (CAP-71) | **No:** `SorobanCredentialsType` stops at `address` (1) | Hand-written |
| `ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS` (10), the V2 signing payload | **No:** `EnvelopeType` stops at 9 | Hand-written |
| `HashIdPreimage` for Soroban authorization | **No** class | Hand-written |

The SDF testnet RPC (protocol 30) still records `ADDRESS` (type 1)
credentials by default, which is what TIA's flow signed today. The client
handles both 1 and 2 because the default is set to change. The hand-written
XDR is about 380 lines (`soroban.dart` and `xdr.dart`), in the style of the
server's `XdrWriter`.

Byte-level proof: for a fixed key, nonce and expiration, the Dart client
produces the same unsigned envelope, the same invocation and the same signed
`ADDRESS` and `ADDRESS_V2` entries as `@stellar/stellar-sdk`
(`authorizeEntry`, `TransactionBuilder`). The test vectors are in
`test/soroban_test.dart`.

## The payload format

`PAYMENT-SIGNATURE` is base64 of the JSON
`{x402Version: 2, resource, accepted, payload: {transaction}}`. `accepted` is
the chosen `accepts` entry as received. `transaction` is a base64
`TransactionEnvelope` with no signatures:

- source: the all-zero account `GAAA…WHF`, sequence 1. If the payer were
  the source, simulation would return a `SOURCE_ACCOUNT` credential and there
  would be no entry to sign. The facilitator rebuilds the transaction with
  its own source and fee.
- one `InvokeHostFunction` with the signed entry in `auth`;
- the `SorobanTransactionData` and resource fee from a second simulation
  that includes the signature, since checking it costs more than the
  recording run counted.

This mirrors `ExactStellarScheme` in `@x402/stellar` 2.30.0.

## How to run it

```
cd spikes/x402-dart
dart pub get
dart analyze --fatal-infos && dart test
dart run bin/pay.dart --secret-file <testnet-key-file> "https://remesa-tia-testnet.vercel.app/v1/quote?amount=100"
```

The reference run with the official client:

```
cd spikes/x402-dart/reference
npm ci
node pay.mjs <testnet-key-file> "https://remesa-tia-testnet.vercel.app/v1/quote?amount=100"
```

The payer needs testnet XLM (Friendbot), a USDC trustline and testnet USDC.
faucet.circle.com works; so does buying USDC with testnet XLM on the testnet
DEX (`path-payment-strict-receive`), which needs no captcha.

The secret key is read from a file and never printed. Tests check the CLI
output for a paid call, a refused call and a malformed key file.

## What it took

About one working session on 2026-11-05: reading the x402 Stellar client and
facilitator to get the payload format, the Dart client and its tests, the
live runs, and this report. Well inside the two days ADR-0006 D5 allowed.

## What is left for Phase 1 (not in this spike)

- Move the client behind `ProviderPaymentPort` in `puls3_server` and sign
  with the agent's custodied key (#20, #34). The signer is an interface, so
  the custody adapter can implement it without exposing the key.
- Reconcile a payment whose response is lost (see the 504 problem above).
- Per-hire and per-day caps (ADR-0006 D6, D7).
- Mainnet: a mainnet RPC, the mainnet USDC SAC, and a facilitator that
  supports `stellar:pubnet`.
