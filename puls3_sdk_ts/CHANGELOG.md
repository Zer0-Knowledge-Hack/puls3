# Changelog

This package follows [semantic versioning](https://semver.org/). Before 1.0, a
minor version may change the API.

## 0.2.0 (unreleased)

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
  `fund` throws `Puls3ProtocolError` instead of being returned. A
  `maxPrice` or `maxReserve` that is not an integer throws
  `InvalidArgument`, not `RangeError`.

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
