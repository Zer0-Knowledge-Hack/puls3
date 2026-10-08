# puls3_flutter

A new Flutter project with Serverpod.

## Getting Started

This project is a starting point for a Flutter application that is using
Serverpod.

A great starting point for learning Serverpod is our documentation site at:
[https://docs.serverpod.dev](https://docs.serverpod.dev).

To run the project, first make sure that the server is running, then do:

    flutter run

## Wallet (#25): Freighter and the mock wallet

```text
UI (WalletPanel, WalletChip, deploy/hire flows)
  -> WalletController   one WalletStatus: disconnected, connecting, connected,
                        signing, signed, rejected, wrongNetwork, error
  -> WalletPort         connect, disconnect, address, network, signTransaction,
                        signAuthEntry
     |- FreighterWallet  real extension, via web/freighter_bridge.js
     |- MockWallet       tests and demo console
     '- (another wallet: implement WalletPort)
```

- The app only handles the public address, the network, the unsigned XDR
  and the signed XDR. It never sees or stores a secret key.
- `signTransaction` sends the server-prepared XDR to the wallet unchanged and
  returns the signed XDR; the server submits it. Before the prompt it refuses
  a wallet not on Stellar Testnet, fee-bump envelopes, trailing bytes and
  transactions for another account (#69). Mainnet is not supported.
- `signAuthEntry` signs a Soroban authorization entry for the connected
  account (non-zero expiration, address credentials only).
- A wallet prompt that never answers times out (connect: 2 minutes), so a
  blocked or ignored popup never traps the user.

Freighter is the default on the web. To use the mock wallet instead:

    flutter run -d chrome --dart-define=WALLET=mock

### Testing with Freighter

1. Install the [Freighter](https://www.freighter.app/) extension in Chrome,
   create or import a **test** account and choose **Testnet** in its settings.
2. Run `flutter run -d chrome` (or build into the server, below).
3. Tap **Connect wallet** -> **Connect Freighter** and approve in Freighter.
   The sheet shows the short address and a Testnet badge.
4. Deploy an agent from Studio: Freighter shows the signing prompt. Until the
   relay (#96) and deploy endpoint (#18) exist the transaction is a harmless
   demo envelope that is never submitted, and the flow is labelled as a demo.
5. Also check: reject the connection, reject the signature, switch Freighter
   to another network (Wrong network), Disconnect, and a browser without
   Freighter (Freighter not found, with an install link).

Build into the Serverpod web folder (served at `localhost:8082/app`):

    flutter build web --base-href /app/ --wasm -o <absolute path>/puls3_server/web/app

Tests:

    flutter analyze
    flutter test
