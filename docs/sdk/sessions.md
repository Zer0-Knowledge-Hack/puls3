# CLI sessions outside the app

Hire and Studio calls act for a wallet, so they need that wallet's session.
Browsing the catalog needs nothing. This page explains how a program outside the
app gets a session, for a person at a terminal and for an automated test.

A **CLI session** is a separate refresh token for the same wallet. It is not the
app's own session: revoking one leaves the other working, and a CLI session can
never mint another one. It refreshes for **72 hours** from the moment the app
creates it, however often it is used.

## 1. From the app

This is the normal path and the one the [CLI reference](../cli/reference.md#wallet-session)
uses.

1. Open [puls3.org](https://puls3.org/) on **Testnet**, connect your wallet and
   open the wallet sheet.
2. Choose **Copy session for CLI**. The app signs in first if needed and shows
   the refresh token **once**.
3. Put it in the environment, never in an argument or in a file you commit:

   ```bash
   export PULS3_REFRESH_TOKEN='<the token>'
   ```

The first call seeds the session file. It is readable only by you (mode 0600)
and the rotated tokens stay there, so later calls do not need the variable
again. Copying a new token replaces the saved one on the next call.

| Setting | Default |
|---|---|
| Session file | `$PULS3_SESSION_FILE`, else `$XDG_CONFIG_HOME/puls3/session.json`, else `$HOME/.config/puls3/session.json`; on Windows `%APPDATA%\puls3\session.json` |
| Refresh variable | `PULS3_REFRESH_TOKEN` |
| Refresh lifetime | 72 hours from creation, absolute |
| Live sessions per wallet | 5; creating a sixth revokes the oldest |

The `puls3` CLI has no login command of its own: it reads `PULS3_REFRESH_TOKEN`
and the session file exactly as the snippets below do. The app (or the script in
section 3) is what creates the session.

The CLI and the MCP server share the file and lock it while refreshing, so two
programs never present the same refresh token.

The TypeScript SDK ([`puls3_sdk_ts/`](../../puls3_sdk_ts/README.md), #302) keeps
its own file, `node-session.json` in the same folder (`PULS3_NODE_SESSION_FILE`
moves it), because Node cannot take the lock the Dart programs use. **Copy a
separate session for a Node program.** Seeding it and the CLI with the same
token makes both rotate it, and the server revokes the session on the second
use. To end a session early, revoke it
from the wallet sheet (**Revoke**, under **Copy session for CLI**). A revoked
session can still answer for up to 10 minutes, because access tokens are checked
without a database read until they expire. Copying a new session does not revoke
the old one.

## 2. Use the session

`CliSession.open` reads the seed and the file. `Puls3Sdk.connect` takes the
session as `session:`; without a session only the catalog works and the hire and
Studio calls throw `SessionRequired` before sending anything.

```dart
import 'dart:io';

import 'package:puls3_sdk/puls3_sdk.dart';

Future<void> main() async {
  final apiUrl = Uri.parse(Platform.environment['PULS3_API_URL']!);
  final session = await CliSession.open(
    apiUrl,
    environment: Platform.environment,
  );
  if (session == null) {
    stderr.writeln('No CLI session. Set PULS3_REFRESH_TOKEN first.');
    exit(64);
  }
  final sdk = Puls3Sdk.connect(apiUrl, session: session);
  try {
    final hire = await sdk.getHire(
      12,
      Platform.environment['PULS3_CONSUMER']!,
    );
    stdout.writeln(hire.hire.status);
  } finally {
    session.close();
    sdk.close();
  }
}
```

Use the URL your server prints. A local `dart bin/main.dart` usually listens on
`http://localhost:8080/`; the sandbox and E2E launcher may use another port, so
set `PULS3_API_URL` rather than editing the code. See the
[local environment](../testing/local-environment.md).

> `puls3_sdk` and `puls3_client` both export a type named `CliSession`: the
> session file above, and the server's generated `CliSession` model. A program
> that imports both packages must prefix or hide one; a program that only uses
> the SDK needs only `package:puls3_sdk/puls3_sdk.dart`.

## 3. From a script (automated tests)

Use this when no app is available: CI, a fresh sandbox, or a test fixture. It
reproduces the app's side of SEP-10 by hand.

### What the server needs

The server must have wallet auth configured:

- the Serverpod password `walletAuthSigningKey` (an `S…` key that only signs),
- `PULS3_AUTH_HOME_DOMAIN` and `PULS3_AUTH_WEB_AUTH_DOMAIN`,
- a chain it can read the signer weights from (`PULS3_STELLAR_RPC_URL` and the
  matching network passphrase).

`scripts/setup-local-secrets.sh` does **not** enable wallet auth: the signing
key is commented out in `config/passwords.example.yaml`. See
[secrets](../infra/secrets.md) and the
[server README](../../puls3_server/README.md) for the local values.

The account you sign in as must exist and be funded on that network, because the
server reads its signer weights and thresholds. A fresh account works: its master
key has weight 1 and threshold 1. Fund it from [Friendbot](https://friendbot.stellar.org)
on testnet, or from the sandbox Friendbot at `http://localhost:8000/friendbot`.

### What the project needs

An outside Dart project needs the client and a pure-Dart Stellar package:

```yaml
dependencies:
  puls3_client:
    path: /absolute/path/to/puls3/puls3_client
  stellar_dart: ^2.3.0
```

`stellar_flutter_sdk` **does not work here**: it pulls in Flutter, so a pure
Dart program cannot resolve its imports. `stellar_dart` is the package the
server's own tests use for this flow.

### Mint a session

Save this as `bin/mint_cli_session.dart`. It reads the server URL and a
throwaway `S…` key from the environment, signs in, creates a CLI session and
prints its refresh token once.

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_client/puls3_client.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

Future<void> main() async {
  final apiUrl = Uri.parse(Platform.environment['PULS3_API_URL']!);
  final walletKey = stellar.StellarPrivateKey.fromBase32(
    Platform.environment['PULS3_TEST_WALLET_SECRET']!,
  );
  final wallet = walletKey.toPublicKey().toAddress().address;

  final client = Client(apiUrl.toString());
  try {
    final challenge = await client.walletAuth.createChallenge(wallet);
    final signed = _sign(
      challenge.payload,
      walletKey,
      challenge.networkPassphrase,
    );
    final signedIn = await client.walletAuth.verifyChallenge(
      challenge.challengeId,
      wallet,
      signed,
    );

    // Only a live wallet session may create a CLI session.
    client.authKeyProvider = _TokenAuth(signedIn.token);
    final grant = await client.cliSession.create();
    stdout.writeln(grant.refreshToken);
  } finally {
    client.close();
  }
}

String _sign(String xdr, stellar.StellarPrivateKey key, String network) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(xdr))
          as stellar.TransactionV1Envelope;
  final hash = Uint8List.fromList(
    stellar.TransactionSignaturePayload(
      networkId: stellar.StellarNetwork.fromPassphrase(network).passphraseHash,
      taggedTransaction: decoded.tx,
    ).txHash(),
  );
  // Append: the challenge already carries the server's signature.
  final signatures = [...decoded.signatures, key.sign(hash)];
  return base64Encode(
    stellar.TransactionV1Envelope(
      tx: decoded.tx,
      signatures: signatures,
    ).toVariantXDR(),
  );
}

final class _TokenAuth implements ClientAuthKeyProvider {
  _TokenAuth(this._token);

  final String _token;

  @override
  Future<String?> get authHeaderValue async =>
      wrapAsBearerAuthHeaderValue(_token);
}
```

Run it and seed the session file:

```bash
export PULS3_API_URL=http://localhost:8080/
export PULS3_TEST_WALLET_SECRET='<a throwaway S… key, never committed>'
export PULS3_REFRESH_TOKEN="$(dart run bin/mint_cli_session.dart)"
unset PULS3_TEST_WALLET_SECRET
```

Then use the session as in [section 2](#2-use-the-session). `CliSession.open`
saves the seed in the session file, so `PULS3_REFRESH_TOKEN` is only needed for
the first call.

The details that are easy to get wrong:

- **Keep the server's signature.** The challenge payload is already signed by
  the server. Append the wallet signature to `decoded.signatures`; do not
  replace the list.
- **Sign the network-tagged hash.** Use
  `challenge.networkPassphrase`, not a hard-coded testnet passphrase. A wrong
  network reaches `verifyChallenge` as `InvalidWalletSignature`.
- **Authenticate before creating the session.** `cliSession.create` only accepts
  a live app wallet session. Without `client.authKeyProvider` carrying
  `signedIn.token` the call is unauthenticated (`ServerpodClientUnauthorized`);
  with a token that is not an app wallet session it fails as
  `CliSessionNotAllowed`.
- **The challenge is single-use.** It expires after 15 minutes and a second
  `verifyChallenge` for the same id fails. Mint a new one; do not retry the same
  payload.
- **The printed refresh token is a bearer secret.** It grants that wallet's
  session for 72 hours. Do not commit it, log it or paste it into an issue. In
  CI, mask it as a secret.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `AuthenticationUnavailable` on `createChallenge` | The server is missing `walletAuthSigningKey`, `PULS3_AUTH_HOME_DOMAIN` or `PULS3_AUTH_WEB_AUTH_DOMAIN`. |
| `InvalidWalletSignature` | The wallet signed a different transaction, the network passphrase is wrong, or the server's signature was dropped. `details.reason` says which check failed (`tampered`, `walletMismatch`, …). |
| `CliSessionNotAllowed` | `cliSession.create` was called with a token that is not an app wallet session (a CLI session, or a revoked one). Without any token the call is `ServerpodClientUnauthorized` instead. |
| `SessionRequired` from the SDK | Neither `PULS3_REFRESH_TOKEN` nor a saved session file exists. |
| Commands fail after 72 hours | The CLI session ended. Copy a new one from the app (or mint another). |
| Two programs refresh at once | Use one session file per wallet; `CliSession` locks it, but hard-coded copies of the tokens bypass that lock. |

The session never lets the SDK sign or submit a transaction. `prepare*` calls
return unsigned envelopes, and the CLI session is only an authentication
credential ([ADR-0007](../adr/0007-developer-sdk.md)).
