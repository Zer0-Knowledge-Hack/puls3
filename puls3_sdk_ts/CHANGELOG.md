# Changelog

This package follows [semantic versioning](https://semver.org/). Before 1.0, a
minor version may change the API.

## Unreleased

The open follow-ups of the #424 review (#438).

- **Sign-in and refresh errors:** a server that fails during sign-in (an
  HTTP status other than 401 or 403) or during a refresh (anything but a
  refusal) now reaches the caller as that error, instead of the 401 of a
  call sent without a session. A refusal still ends the session as before.
- **RPC reads:** an answer whose body never finishes ends as
  `Puls3NetworkError` after `timeoutMs`, not as `Puls3ProtocolError`
  ("no JSON"). `SorobanRpcReader` throws `TypeError` for a `timeoutMs` that
  is not a positive, finite number.
- **`register_full` refusal:** the message for a URI on another origin says
  to set `registrationOrigin` in `withNetwork`.
- **`CliSession` lock:** a program now waits up to 90 seconds (was 30) for
  the lock, longer than a dead program's lock takes to go stale (60), so it
  takes that lock over instead of giving up. When the system keeps refusing
  the takeover, the timeout names the refusal (`EPERM`, `EACCES`). A takeover
  lock moved by mistake that cannot be put back is left in place, not
  removed.

## 0.2.0 (2026-11-26)

The remaining checks and errors of #424.

- **Breaking: `approve` and `reject` require the reviewed result.** Pass
  `{ result }`, the result you reviewed (`{ result: null }` to reject a
  funded hire with no delivery), or `{ trustServer: true }` to keep the old
  behaviour of trusting the server's description of the hire. With neither,
  they throw `InvalidArgument` and send nothing.

- **Signing checks (ADR-0010 D3 rule 4):** `give_feedback` must carry the
  score passed to `rate` with 0 decimals; `fund` must accept a platform fee
  (`max_fee_bps`) of at most the new `Puls3Network.maxFeeBps` (0 in
  `TESTNET`, as production charges); a `register_full` URI must be on the
  new `Puls3Network.registrationOrigin`. A server that charges a fee needs
  `withNetwork({ maxFeeBps })`.
- **`hire`:** `maxReserve` now reaches the server (`createHire` takes
  `{ subcontractReserve }`); before, it was checked but never sent. A
  retried hire whose earlier `create_job` failed on chain throws
  `ChainSubmissionFailed`, not `Puls3Timeout`. A hire left unfunded after
  `fund`, or a retried one that already ended (rejected, expired), throws
  `Puls3ProtocolError` instead of being returned. A
  `maxPrice` or `maxReserve` that is not an integer throws
  `InvalidArgument`, not `RangeError`.
- **`CliSession` lock:** programs that share a session file no longer race
  on a stale lock. The holder writes an owner token and keeps it fresh
  while it works, only one program may take over a lock whose owner died
  (after reading again that it is the same one), and a holder removes the
  lock only while it is still its own. Before, two programs could both take
  over a stale lock and present the same refresh token, which revokes the
  session. A 0.1.0 program sharing the same file still sees a live holder
  as alive.
- **Typed errors:** a 200 whose body is not JSON throws `Puls3ProtocolError`,
  not a raw `SyntaxError`. A `KeySession` sign-in that fails for any reason
  other than the server refusing it (the signer failed, an answer this
  version cannot read, an unreachable server) throws that error, instead of
  sending the call without a session and reporting a 401.
- **Soroban RPC timeout:** each read of the chain is bounded (20 seconds by
  default, `new SorobanRpcReader(network, source, fetch, { timeoutMs })`), so
  a hung RPC ends as `Puls3NetworkError` instead of hanging `hire` and
  `deploy`.
- **Node 20:** `npm test` lists the test files itself
  (`scripts/run-tests.mjs`) instead of passing a glob, which `node --test`
  expands only from Node 21. CI now runs the package on Node 20 and 22.

## 0.1.0

First version (#302).

- **Signing with a developer key** (ADR-0010): `Puls3Signer`, `keypairSigner`
  and `keypairSignerFromEnvironment` (`PULS3_SECRET_KEY`). Every envelope is
  checked before it is signed (`checkPreparedTransaction`,
  `checkPreparedAuthorization`, `checkChallenge`), against the testnet
  contracts pinned in `TESTNET`; a failed check throws `SigningRefused`.
- `KeySession`: signs in with the signer (SEP-10), no app needed.
- Flows that sign and wait on chain: `deploy`, `hire`, `waitForResult`,
  `approve`, `reject`, `rate`.
- The Studio: `saveDraft` and the deploy calls (`prepareDeploy`,
  `submitRegistration`, `getDeploySession`, `prepareWalletAuthorization`,
  `submitWalletAuthorization`); `submitEscrowCall`, `prepareFeedback`,
  `submitFeedback`.
- Errors: `SignerRequired`, `SigningRefused`, `ChainSubmissionFailed`,
  `Puls3Timeout`.

- The catalog without a session: `listAgents`, `getAgent`.
- Hires with a session: `createHire`, `getHire`, `listMyHires`,
  `prepareCreateJob`, `prepareFund`, `prepareComplete`, `prepareReject`.
- The Studio with a session: `listDrafts`, `getDraft`, `testRun`,
  `hireAgentAs`, `getAgentHire`.
- `CliSession`: a CLI session copied from the app, refreshed and kept in a
  user-only file that several Node programs can share.
- Typed responses and typed errors: `Puls3ApiError` with the server's codes,
  `SessionRequired`, `InvalidArgument`, `Puls3HttpError`, `Puls3NetworkError`,
  `Puls3ProtocolError`.
