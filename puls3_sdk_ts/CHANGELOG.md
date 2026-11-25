# Changelog

This package follows [semantic versioning](https://semver.org/). Before 1.0, a
minor version may change the API.

## 0.1.0 (unreleased)

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
