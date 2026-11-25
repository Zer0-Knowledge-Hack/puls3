# Changelog

This package follows [semantic versioning](https://semver.org/). Before 1.0, a
minor version may change the API.

## 0.1.0 (unreleased)

First version (#302). It reads and prepares; it never signs or submits a
transaction.

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
