# x402 Dart client spike (#164)

A Dart client that pays one x402 `exact` call on Stellar Testnet: it reads the
`PAYMENT-REQUIRED` terms, checks them against an allow-list, signs the SAC
`transfer` authorization entry and retries with `PAYMENT-SIGNATURE`.

This is a throwaway proof. Product code must not import it. The verdict and
the testnet transactions are in
[docs/spikes/x402-dart.md](../../docs/spikes/x402-dart.md).

## Run

```
dart pub get
dart analyze --fatal-infos && dart test
dart run bin/pay.dart --secret-file <testnet-key-file> "https://remesa-tia-testnet.vercel.app/v1/quote?amount=100"
```

Options: `--max-amount <stroops>` (default 2500000 = 0.25 USDC), `--pay-to`,
`--asset`, `--rpc`. The defaults are TIA's testnet `payTo` and the testnet
USDC SAC.

Keep the key file outside the repo. `*.secret` is ignored here as a backstop.

## Layout

| Path | What it does |
|---|---|
| `lib/src/terms.dart` | Decodes the 402 terms and applies the allow-list |
| `lib/src/soroban.dart` | Hand-written XDR: the `transfer` envelope, the auth entry and its signing payload (`ADDRESS` and `ADDRESS_V2`) |
| `lib/src/rpc.dart` | `simulateTransaction`, `getLatestLedger`, `getLedgers` |
| `lib/src/client.dart` | The 402 → sign → retry flow |
| `bin/pay.dart` | The CLI |
| `reference/` | The same call with the official `@x402/fetch` client |
