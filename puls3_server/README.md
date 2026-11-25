# puls3 Serverpod backend

Serverpod **4.0.4**, pinned on **2026-10-07**. The backend currently exposes a
`health` endpoint so the Flutter app can verify the generated client, server,
and shared workspace are connected, and a read-only `agent` endpoint that serves
the agent catalog from the on-chain identity registry.

## Agent catalog endpoint

`agent.list` returns every agent with valid metadata (`AgentSummary`: `id`,
`registryId`, `name`, `description`, `skills`, `priceUsdcStroops`, optional
`wallet` and `model`). `agent.get(id)` returns the agent with that metadata id,
for example `agt-001`, or `null` when there is none. There is no rating: the
registry does not store one.

The endpoint reads from the Postgres index (`agent_record`), which the
**agent catalog indexer** below syncs from the identity registry. While the
index is empty the endpoint falls back to reading the registry directly: the
registry has no list function, so it reads `total_agents` and then the metadata
of ids `0` to `total - 1` through Soroban RPC simulations (four agents at a
time). An agent whose metadata is missing or invalid, such as a superseded
registration, is skipped. Reads never touch the chain while the index has rows,
so a chain outage does not take the catalog down. The endpoint never signs or
submits a transaction.

The chain is read from the testnet values unless these variables override
them: `PULS3_STELLAR_RPC_URL`, `PULS3_STELLAR_NETWORK_PASSPHRASE`,
`PULS3_STELLAR_USDC_SAC`, `PULS3_STELLAR_IDENTITY_REGISTRY`,
`PULS3_STELLAR_ESCROW`, `PULS3_STELLAR_PREVIOUS_ESCROWS` (comma-separated: the
escrows `PULS3_STELLAR_ESCROW` replaced, whose jobs still make a rating count)
and `PULS3_STELLAR_SIMULATION_SOURCE`. Each RPC call
times out after 8 seconds. To move to a new escrow, follow
[Rotating the escrow](../docs/operations/escrow-rotation.md).

`PULS3_STELLAR_REPUTATION_REGISTRY` is the Reputation Registry contract id
(#14). Its testnet default is the deployed registry
`CBJZYEJ5DS7TDLA2ECRAW3ICQIYAOMTCQ5QSY7PYJ5PJ2W5EAHPBP5Q4`, recorded in `contracts/deployments/testnet.json`. While it is
unset on another network, `FeedbackEndpoint.prepareFeedback` fails with `HireConfigurationMissing`
and every agent shows the #11 empty-input rating (`4.0`, `0` paid hires). Once
set, the catalog reads each agent's feedback from the registry (cached for 60
seconds) and `prepareFeedback` builds the real `give_feedback` call. The value
is public, like the other contract ids.

With no indexed rows and a chain that cannot be read, the on-chain fallback
throws the serializable `AgentCatalogUnavailable` exception; an outage is never
an empty list, and an unknown id is never reported as an outage.

### Marketplace search for subcontracting (ADR-0011 D9)

`AgentSearchService` (built by `buildAgentSearchService`) ranks the agents a
hired agent may subcontract. It has no endpoint; the runtime's `search_agents`
tool calls it. Candidates are hireable, priced within the remaining reserve,
and are neither the hiring agent nor any agent up its hire chain (by registry
id or provider wallet). The pure rules live in `puls3_domain`
(`rankAgentCandidates`, `justifyRelatedPartyPick`):

- Score: `0.50 * skillMatch + 0.25 * (rating - 1) / 4 + 0.15 * hires / (hires + 10) + 0.10 * (1 - price / reserve)`,
  ties to the lowest registry id. `skillMatch` is the matched fraction of the
  requested skills and of the query words (0.6 / 0.4 when both are given).
- Related party (D10): an agent sharing a custody, Studio deploy or registry
  owner with the hiring agent. Unknown owners (no row, or a failed registry
  read) count as related, so an opt-out anywhere in the hire chain drops them.
- A related pick is justified when it is rank 1, costs no more than the
  best-ranked independent candidate whose skill match is at least the pick's
  minus 0.1, or no such independent exists.

## Hidden agents

The Identity Registry has no delete and anyone can register an agent on chain,
so the catalog would otherwise show every registered agent. Maintainers hide one
by listing its registry id:

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_HIDDEN_AGENT_IDS` | unset | Comma-separated registry ids, e.g. `15,16`. Unset or blank hides nothing; a malformed id fails the request instead of being ignored |

A hidden agent is left out of `agent.list`, `agent.get` returns `null` for it,
`createHire` refuses it with the same `AgentNotFound` as an unknown id (the
server raises `AgentUnavailable`), and its `/registry/<hash>` file is a 404.
Jobs already funded are not touched: they settle or refund as usual, because the
hire relay and `getHire` keep reading the unfiltered catalog.

On Serverpod Cloud, set it with
`scloud variable set PULS3_HIDDEN_AGENT_IDS "15,16"` and redeploy.

## Agent catalog indexer

A background loop keeps the `agent_record` index in sync with the identity
registry. The first pass bootstraps from registry state, because the RPC keeps
only about 7 days of events. Later passes read the registry events after the
stored cursor (`catalog_index_state`) to find the agents that changed, then
hydrate them from state; any agent missing from the index is always hydrated,
so a registration is never lost. Writes are idempotent (upsert by registry id),
so re-running a pass never creates duplicates. The chain stays the source of
truth; the index keeps serving reads while the chain is down.

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_INDEXER_ENABLED` | `false` | Only `true` starts the loop |
| `PULS3_INDEXER_INTERVAL_SECONDS` | `30` | Seconds between passes; a positive whole number |

It is off by default so tests, CI and existing deployments do not read the
chain unless asked to. It uses the same `PULS3_STELLAR_*` variables as the
agent catalog, and writes `[catalog-indexer]` lines to stdout (info) and stderr
(warnings).

## Chain submission tracker

A background loop drives relayed `ChainSubmission` records from `submitted`
to `confirmed` or `failed` (relay step 5 in `docs/architecture/api.md`). Each
pass polls `getTransaction` for up to 100 records, resends the persisted
envelope at most every 30 seconds while the transaction is not found, fails
it as `PreparationExpired` once the chain time passes its time bounds, and
confirms `createJob` and `fund` from their escrow events. After a successful
`fund` the hire effect (`HireEscrowEffects`) reads the job from the escrow and
pays the hire only if the job matches it (state `Funded`; client and
evaluator are the consumer; provider, token, budget and `expired_at` as
prepared); otherwise the submission fails as `JobMismatch` with the mismatching
field. When a transaction carries several escrow events, the effect uses the
one that belongs to the hire (the hire's job id for `fund`; client, agent,
price and prepared expiry for `createJob`); zero or several matches fail as
`JobMismatch` on `job_id`.

A successful transaction whose escrow event is not visible yet stays
`submitted` for up to 3 passes before it fails as `JobEvidenceUnavailable`.
That count lives in memory, so a restart starts it again.

A `fund` or other record that is not found after its time bounds fails as
`PreparationExpired` only while the node still retains the ledgers since the
record was created (`oldestLedgerCloseTime` of `getTransaction`, or 24 hours
when the node does not report it). Past that window the transaction may have
landed unseen, so it fails as `OutcomeUnknown`, and every `prepare…` call for
that hire raises `OutcomeUnknown` until the record is resolved by hand. An
expired `fund` is first reconciled through the escrow job: `Funded` or later
pays the hire, `Open` is `PreparationExpired`.

`submit`, `complete`, `reject`, `release`, `claimRefund` and `registerFull`
are confirmed when the transaction succeeds. Hire status is then derived from
those records (#208): `submitted`, `completed`, `rejected` or `expired`. The
tracker does not write a status column. `setAgentWallet` stays untracked.

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_TRACKER_ENABLED` | `false` | Only `true` starts the loop |
| `PULS3_TRACKER_INTERVAL_SECONDS` | `5` | Seconds between passes; a positive whole number |

It is off by default so tests, CI and existing deployments do not poll the
chain. It uses the same `PULS3_STELLAR_*` variables as the agent catalog, and
writes `[chain-tracker]` lines to stdout (info) and stderr (warnings).

## Agent runtime

A second background loop runs the agent of every funded hire once (#20).
When the tracker records a hire's payment, it queues a run (`hire_run`) in
the same transaction. Each pass:
1. fails runs still `running` past the timeout plus a minute (`interrupted`);
2. takes up to 10 queued runs, one at a time, with a conditional update, so
   two runners never run the same hire;
3. loads the manifest the hire pinned and calls the model through
   `AgentRunner` (input and output limits, timeout that aborts the call);
   a free-model (`workers-ai`) run first reserves one slot for the agent on
   the UTC day, and above 10 slots it fails with `team_run_quota_exceeded`
   before calling the model. This covers every free-model agent, including
   the seeded demo agents; a run that fails after reserving keeps its slot;
4. stores the result, or a safe failure code such as `timeout`,
   `provider_error:<type>`, `manifest_unavailable` or
   `team_run_quota_exceeded`.

For the subcontracting tool loop (#334, ADR-0011 D8) the model layer also
holds conversations with tools: `ConversationRuntime.converse` returns one
`ModelTurn`, the final text or the tool calls, and
`AgentRunner.converseOnce` applies the same timeout, abort and limits to each
turn (the input limit counts the whole conversation). Every Anthropic model
supports tools. On Workers AI, the models in `workersAiToolModels`
(`@cf/mistralai/mistral-small-3.1-24b-instruct`) hold tool conversations
through the OpenAI-compatible `/ai/v1/chat/completions` endpoint, whose tool
calls carry ids; any other Workers AI model holds plain conversations only and
fails a call with tools as `tools_unsupported`. `ToolLoop.offersTools`
(`callsTools`) applies the same rule per model, so subcontracting works on
Anthropic or on that free model (#334 T8.0).

Each run goes through the domain (`Hire.startRun`, `Hire.failRun`).
`HireEndpoint.getHire` shows the progress as `runtimeStatus` (`queued`,
`running`, `failed`; a run in `awaitingChild` shows `running`), with the
`result` and `failureReason`.

A successful run stores the result and, when agent-wallet custody is
configured, the runtime signs escrow `submit` with the custodied provider
key (#208). The tracker confirms it and `getHire` then reports `submitted`.
Seeded demo agents that still pay to the escrow admin cannot sign until
[#209](https://github.com/Zer0-Knowledge-Hack/puls3/issues/209). Studio-deployed
agents already have custodied wallets. Demo manifests are seeded in
`lib/src/runtime/demo_manifests.dart`, keyed by the agent's `id` metadata
(`agt-006` Copy Forge, `agt-007` Support Relay). Both run on Cloudflare
Workers AI (`@cf/meta/llama-3.3-70b-instruct-fp8-fast`), the free provider of
the #34 model policy. `ProviderRouter` sends each run to its manifest's
provider; a provider without credentials fails the run as
`unsupported_provider`.

| Setting | Default | Meaning |
|---|---|---|
| `PULS3_RUNTIME_ENABLED` | `false` | Only `true` starts the loop |
| `PULS3_RUNTIME_INTERVAL_SECONDS` | `5` | Seconds between passes; a positive whole number |
| `PULS3_RUNTIME_TIMEOUT_SECONDS` | `120` | Longest one run may take; it must end before the job's `expired_at` |
| `PULS3_WORKERS_AI_ACCOUNT_ID` | none | Cloudflare account id for Workers AI (public) |
| Serverpod password `workersAiApiToken` | none | Cloudflare API token for Workers AI. Locally, `shared: workersAiApiToken:` in `config/passwords.yaml`; on Serverpod Cloud, `scloud password set workersAiApiToken --from-file <file>` |
| Serverpod password `anthropicApiKey` | none | Optional Anthropic API key, for manifests with provider `anthropic` (BYOK) |

With neither provider configured the loop does not start, even when enabled.

The server-wide `workersAiApiToken` serves every free `workers-ai` agent:
seeded demos and Studio deploys, for test runs and paid hires (#318). Paid
providers (for example Anthropic) still run on the builder's own key
(ADR-0004 amendment), resolved from the deploy record.

It is off by default so tests, CI and existing deployments never call a paid
model. It writes `[agent-runtime]` lines to stdout (info) and stderr
(warnings).

### Run phases (#334, T5.3)

With a `SubcontractSetup` (search, `SubcontractPort`, `ChildResultSource`
and a `RunnerLease`), `HireRunner` runs an opted-in Anthropic manifest
through `ToolLoop`. A run that opens a child moves `running` →
`awaitingChild`: the loop state is stored in `hire_run` (`loopState`, versioned
JSON from `tool_loop_codec.dart`: the transcript with each turn's opaque
`providerContent`, turns and children used, the remaining reserve and the
search snapshots; plus `pendingToolCallId`, `childHireId` and `childRequest`
with the justification, D10 verdict and ranking), the model call has ended,
and nothing holds the timeout. Each pass first asks `ChildResultSource` about
every paused run; once the child delivered or failed, the run goes back to
`running` and the loop continues with that result. An awaiting run is never
swept as `interrupted`, shows `runtimeStatus` `running`, and its hire stays
`funded` (ADR-0011 D7). A retryable provider failure mid-loop stores the
conversation and the next attempt continues it, so no finished turn is
repeated and no child is opened twice. Studio (`OwnedRunManifest`) runs hold
the conversation on the builder's credential (`runnerLease`). The stored
state is bounded by the loop's input cap (`input.max_chars` plus 32,000
characters of headroom) plus provider content: tens of kilobytes.

### Child verdicts (#334, T6.3)

`EscrowChildResultSource` is the real `ChildResultSource`. Once the child's
facts are final, the parent agent A judges its child B with one server rule
(ADR-0011 D3) and A's custodied wallet signs the verdict as the child's
evaluator: a `childComplete` or `childReject` submission (server-signed; it
calls the escrow's `complete` or `reject`). The 32-byte `reason` is the
SHA-256 of the UTF-8 reason code:

| Code | When | Call |
|---|---|---|
| `child_complete` | B's `submit` confirmed and its output is non-blank | `complete` from `Submitted` |
| `child_output_empty` | B's submitted output is empty or blank | `reject` from `Submitted` |
| `child_run_failed` | B's run failed | `reject` from `Funded` |
| `child_not_submitted` | B's run succeeded but its `submit` can never land | `reject` from `Funded` |

Length is never a reason to reject. B's run already fails an output over its
own manifest's `output.max_chars`, which no manifest may set above 16,000
(domain invariant I30), so a stored output is work B delivered within its own
terms. "Malformed" and "off the subtask" (D3) are not checked either, on
purpose: they would need a model call that B's output could steer, so anything
non-blank is paid.

The parent's loop gets B's stored output (`ChildDelivered`) after a confirmed
`complete` or a deadline-relay `release`, and `ChildFailed` with the reason
code after a confirmed `reject`, `child_expired` after `claim_refund`, and
`child_not_opened` for a child whose `create_child_job` never landed. When
the parent's run fails, its open children are still judged by the same rule on
every runtime pass. The reserve backs B's work until B finishes, whoever hired
the parent. A
delivered output that would push the parent's conversation past its limit
(`input.max_chars` plus the loop's headroom) is cut to the longest prefix that
fits and labelled with `truncated` and `output_runes`, so the paid result never
fails the parent's next segment with `input_too_long`. A
`pending` or `unverified` receipt line keeps the parent waiting. One verdict
is in flight per child; a failed one is built again up to three attempts,
after which the deadline relay settles the child. On confirmation the tracker
fills the receipt line's `state`, `fee`, `payout` (from `JobCompleted`; 0 for
a reject) and `settleTransaction`; the complete verdict stores B's
`deliverableHash` when it is sent.

`AgentSubmitSender` takes an optional `childrenOpen` check (`OpenChildren`)
and does not submit a parent hire while a child is open; a simulation refused
with `ChildrenOpen` stores nothing and is retried, so it never burns an
attempt. Agent-signed calls (`submit`, `createChildJob` and the verdicts) are
kept one in flight at a time.

**Wired in production (T6.4.5).** `startAgentRuntime` builds the setup, the
port, the result source, the reconciler and `childrenOpen` per pass
(`buildSubcontractServices`), and the chain tracker passes `ChildJobEffects`.
It is on only where the submit wiring is on (custodied keys) and
`PULS3_HIRE_JOB_DURATION_SECONDS` is set; the log line says
`subcontracting on` or `subcontracting off`. A hire carries a reserve only
with `PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS`, and a run is offered the tools
only when its manifest opted in (`subcontractEnabled`). With subcontracting on,
`staleAfter` is `timeout * 8 + 1 min` and the pass timeout
`2 * batch * 8 * timeout + 1 min`; with it off a run is one model call, so they
stay `timeout + 1 min` and `2 * batch * timeout + 1 min`
(`agentRuntimeTimings`). With it off, runs still `awaitingChild` from an
earlier deployment are counted in a startup log line and wait for their escrow
to expire.

### Hire configuration

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_HIRE_JOB_DURATION_SECONDS` | none (required) | How long a new hire's escrow job stays valid: `HireService.createHire` sets the job's `expired_at` to now plus this many seconds, and `fund` is only accepted for a job with that same `expired_at`. A positive whole number; without it `createHire` fails with `HireConfigurationMissing`. The value is deferred (ADR-0005 D3), so no default is set. It must be longer than the escrow's `approval_window` plus the run time: `submit` fails with `SubmitTooLate` unless `now + approval_window < expired_at`, and the testnet escrow's window is 86400 s, so `86400` makes every `submit` fail. The examples use `259200`: a hire that subcontracts needs two approval windows plus the escrow's 600 s `CHILD_EXPIRY_MARGIN`, because a child job must expire one window plus 600 s before the parent's and still leave the child a full window to submit, so `172800` leaves no room for a child. |
| `PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS` | none (required) | How long an unsigned escrow envelope stays valid: its `maxTime` is now plus this many seconds, and `submitEscrowCall` answers `PreparationExpired` after it. A positive whole number. |
| `PULS3_STELLAR_INCLUSION_FEE_STROOPS` | none (required) | The inclusion fee, in stroops, of every prepared envelope; the simulated resource fee is added on top. A positive whole number. |
| `PULS3_PLATFORM_FEE_BPS` | none (required) | The `max_fee_bps` argument of `fund`, in basis points from 0 to 1000 (the contract's `MAX_FEE_BPS`). It must equal `NetworkConfig.platformFeeBps`. `0` is a valid value. |
| `PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS` | none (optional) | The platform ceiling of a hire's subcontract reserve, in USDC stroops (ADR-0011 D1). Read only when `createHire` asks for a reserve above 0: such a hire is funded with `fund_with_reserve` instead of `fund`. A reserve above the ceiling fails with `InvalidHire`; without the setting a reserve fails with `HireConfigurationMissing`, so a deployment without it hires exactly as before. `0` turns subcontracting off. `getHireTerms` reports it as `reserveMaxStroops`, 0 when unset; an unreadable value is logged and also reported as 0. |

The three relay keys have no default, fallback or placeholder. They are read
when an operation needs them, so a missing, empty, non-integer or out-of-range
value makes that call fail with `HireConfigurationMissing` naming the key
(`createHire` and the `prepare*` methods read the keys they need;
`submitEscrowCall` reads none) and never stops the server or affects the other endpoints.

### Hire endpoint sessions

Every `HireEndpoint` method (`createHire`, `getHireTerms`, `prepareCreateJob`,
`prepareFund`, `prepareComplete`, `prepareReject`, `submitEscrowCall`,
`getHire`) requires a
signed-in caller: a request without a session is HTTP 401 before the method
runs. The method then resolves the caller's wallet through the
`SessionWallet` seam before doing any work. The production binding,
`WalletSessionWallet`, reads the wallet that [wallet sign-in](#wallet-sign-in)
bound to the session and never trusts an address the caller sends. Tests
inject a fake with `HireEndpoint.sessionWallet`. `InputTooLong` has no
documented limit, so the hire `input` length is not checked.

### End-to-end proof on testnet

`tool/e2e_relay_testnet.dart` creates and funds a hire on **testnet** using
only `createHire`, `prepareFund` and `submitEscrowCall`, signing the unsigned
XDR unchanged with a consumer key. It composes the real `HireEndpoint`, wiring,
codec, Soroban RPC client and chain tracker over the test PostgreSQL (test
mode, migrations applied), checks that a second submit of one preparation
returns the existing record, and that an envelope with altered time bounds
(a copy, never broadcast) is rejected with `EnvelopeMismatch`. It prints the
hire and job ids, both transaction hashes with Stellar Expert links and the
final status, and exits non-zero on any failed step.

The secret is read from `PULS3_E2E_CONSUMER_SECRET` and is never printed or
stored; feed it from the Stellar CLI in the same command. The relay values
below are for this run only (they are not defaults of the server); the chain
ids default to testnet and can be overridden with the `PULS3_STELLAR_*` keys.
The consumer needs XLM and testnet USDC of the allowed token, and the registry
needs an agent with a wallet (`PULS3_E2E_AGENT_ID` picks one; the cheapest
otherwise).

```bash
docker start puls3_server-postgres_test-1 puls3_server-redis_test-1
cd puls3_server
PULS3_E2E_CONSUMER_SECRET="$(stellar keys secret alice)" \
PULS3_E2E_CONSUMER_ADDRESS="$(stellar keys address alice)" \
PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS=600 \
PULS3_STELLAR_INCLUSION_FEE_STROOPS=100000 \
PULS3_PLATFORM_FEE_BPS=0 \
PULS3_HIRE_JOB_DURATION_SECONDS=259200 \
dart run tool/e2e_relay_testnet.dart
```

### Stuck submit refund proof on testnet (#277)

`tool/e2e_stuck_submit_refund_testnet.dart` proves the two consumer refunds
of #277 on **testnet**. Run 1 funds a hire, lets the runtime's submit sender
try `submit` (the escrow refuses it with `SubmitTooLate`), checks that
`getHire` reports `submitErrorCode`, and signs `reject` from `funded`. Run 2
funds a second hire, waits past `expired_at`, and signs `claim_refund`
through `prepareClaimRefund`. Both runs check the consumer's USDC balance on
Horizon before and after. `--only reject|claim` runs one of them.

The job duration must be under the escrow's approval window (one day) so the
submit can never land. The seed agents' payee is not custodied, so the tool
adds a placeholder `agent_wallet` row for it in the local test database
while it runs (it holds no usable key and is removed at the end).
`escrowRelaySigningKey` must stay unset, so the relay cannot refund on its
own. Run it on a fresh database: `puls3_test` may hold hires of the local
sandbox escrow, whose job ids clash with the testnet ones. The record of the
run is `docs/verification/277-stuck-submit-refund.md`.

```bash
docker start puls3_server-postgres_test-1 puls3_server-redis_test-1
docker exec puls3_server-postgres_test-1 psql -U postgres -c "create database puls3_e2e_277;"
cd puls3_server
SERVERPOD_DATABASE_NAME=puls3_e2e_277 \
PULS3_E2E_CONSUMER_SECRET="$(stellar keys secret alice)" \
PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS=600 \
PULS3_STELLAR_INCLUSION_FEE_STROOPS=100000 \
PULS3_PLATFORM_FEE_BPS=0 \
PULS3_HIRE_JOB_DURATION_SECONDS=360 \
dart run tool/e2e_stuck_submit_refund_testnet.dart
```

### Submit and complete proof on testnet (#208)

`tool/e2e_submit_testnet.dart` continues past funding: the agent runtime
signs escrow `submit` with the custodied provider key, then the consumer
signs `complete` unchanged. It prints both transaction hashes with Stellar
Expert links. Seed demo agents that still pay the escrow admin (`GAFUY…`)
are skipped; the hire must be of a Studio-deployed agent whose wallet is in
`agent_wallet`. Rebinding the seed catalog is #209.

Default Serverpod mode is `test` (`postgres_test`, same as the relay proof).
A Studio deploy against the local development server writes `agent_wallet`
and the manifest to development Postgres (`localhost:8090`), so that agent
is invisible in test mode. Stop `dart bin/main.dart` and set
`PULS3_E2E_SERVERPOD_MODE=development` to use those rows.

The same consumer secret and relay fee keys as the relay proof. Also:

- `PULS3_AGENT_WALLET_SECRET_KEY` (custody cipher; see `docs/infra/secrets.md`)
- Workers AI (`PULS3_WORKERS_AI_ACCOUNT_ID` + `workersAiApiToken`) or Anthropic,
  so the run can finish
- `PULS3_E2E_AGENT_ID` optional; otherwise the cheapest custodied agent
- `PULS3_E2E_SERVERPOD_MODE` optional (`test` or `development`)

```bash
# Stop dart bin/main.dart first so ports 8080–8082 are free.
docker start puls3_server-postgres-1 puls3_server-redis-1
cd puls3_server
set -a; . ../.env; set +a
PULS3_E2E_CONSUMER_SECRET="$(stellar keys secret alice)" \
PULS3_E2E_CONSUMER_ADDRESS="$(stellar keys address alice)" \
PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS=600 \
PULS3_STELLAR_INCLUSION_FEE_STROOPS=100000 \
PULS3_PLATFORM_FEE_BPS=0 \
PULS3_HIRE_JOB_DURATION_SECONDS=259200 \
PULS3_E2E_SERVERPOD_MODE=development \
dart run tool/e2e_submit_testnet.dart
```

Paste the printed `submit` and `complete` hashes on PR #213.

### Feedback proof on testnet (#179)

`tool/e2e_feedback_testnet.dart` continues the funded hire of the relay proof:
the agent fixture signs `submit` directly, the server releases the job after
`approval_deadline` through the chain tracker's deadline pass (it needs the
`escrowRelaySigningKey` password), the hire reads `completed`, and the
consumer rates it with `prepareFeedback` and `submitFeedback`. It exits
non-zero unless the hire has a `feedbackReference` and `AgentEndpoint.get`
counts the new rating. It is an ops proof and has no unit test.

Both secrets come from the environment and are never printed. The run waits
for the approval window, so it can take as long as the window (30 minutes at
most).

```bash
cd puls3_server
PULS3_E2E_HIRE_ID=<hire id printed by the relay proof> PULS3_E2E_CONSUMER_SECRET="$(stellar keys secret alice)" PULS3_E2E_AGENT_SECRET="$(stellar keys secret agent)" dart run tool/e2e_feedback_testnet.dart
```

## Wallet sign-in

Hires need a wallet session (#136). The app asks
`walletAuth.createChallenge` for a SEP-10 challenge, the wallet signs it, and
`walletAuth.verifyChallenge` checks both signatures and returns a Serverpod
session (a JWT, renewed through `jwtRefresh`).

| Setting | Default | Meaning |
|---|---|---|
| Serverpod password `walletAuthSigningKey` | none | Stellar secret key (`S…`) that signs every challenge. It only signs and never submits, so a new key with no funds is enough. Locally, `walletAuthSigningKey:` in `config/passwords.yaml`; on Serverpod Cloud, `scloud password set walletAuthSigningKey --from-file <file>` |
| `PULS3_AUTH_HOME_DOMAIN` | none | Home domain written into the challenge (`<home domain> auth`). The deployed server uses its API host |
| `PULS3_AUTH_WEB_AUTH_DOMAIN` | none | Host that serves wallet authentication. The deployed server uses its API host |

In the `production` run mode **the server refuses to start** while any of the
three is missing or blank (`WalletAuthConfig.ensureProduction` in
`server.dart`), so set them before deploying a commit that includes #136.
Other run modes start, and `createChallenge` answers
`AuthenticationUnavailable`. When all three are set, the server publishes its
public signing key and home domain in the web app's `config.json` (`auth`).

A key for testnet:

```bash
stellar keys generate puls3-auth --network testnet
stellar keys secret puls3-auth > walletAuthSigningKey.txt
scloud password set walletAuthSigningKey --from-file walletAuthSigningKey.txt
rm walletAuthSigningKey.txt
```

## Agent wallet custody

Part of #18. Each agent will get its own custodied ed25519 account (ADR-0003
decision 4). The server generates the keypair, encrypts the secret seed with
AES-256-GCM, and stores only the ciphertext, nonce, MAC and key version in
`agent_wallet`. The wallet address is the GCM additional authenticated data, so
a secret copied to another row does not decrypt. The plaintext seed is never
logged, stored or returned; only the public `G…` address leaves the custody
adapter. Creation is idempotent per caller key (the deploy session/draft id), so
a retry cannot orphan a funded account.

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_AGENT_WALLET_SECRET_KEY` | none (required) | Base64 of a random 32-byte key (`openssl rand -base64 32`) that encrypts agent secrets and builder provider credentials (#235) at rest. **Back it up:** losing it makes every custodied account unrecoverable. When it is unset, creating an agent wallet fails with `AgentWalletCustodyUnavailable`, and saving a builder credential fails as `RuntimeUnavailable`. |

Funding the account and adding its USDC trustline, and the on-chain
registration (`register_full` / `set_agent_wallet`), are the next part of #18.

## Prerequisites

- Dart 3.12.2
- Flutter 3.44.4 (to run the app)
- Docker with Docker Compose
- Serverpod CLI 4.0.4: `dart pub global activate serverpod_cli 4.0.4`

## Start the backend

The full path (fresh clone → server and app against testnet) is in
[docs/infra/secrets.md](../docs/infra/secrets.md#run-against-testnet-from-a-fresh-clone).
In short: from the repository root, generate the local Docker passwords
(`puls3_server/.env`) and Serverpod password files (on Windows, run this from
Git Bash):

```bash
./scripts/setup-local-secrets.sh
```

To configure them manually instead, start by copying the tracked templates:

```bash
cd puls3_server
cp .env.example .env
cp config/passwords.example.yaml config/passwords.yaml
```

Replace every empty or `<generate>` value. The development and test
`database`/`redis` values in `config/passwords.yaml` must match the respective
passwords in `.env`.

`puls3_server/.env` only holds these local Docker passwords. The server's
public network config (`PULS3_STELLAR_*`, `PULS3_TRACKER_*`) lives in the root
`.env` (`cp .env.example .env`). Then, from `puls3_server/`, start PostgreSQL
and Redis, load the root config and run the server with pending migrations
applied:

```bash
docker compose up --build --detach
set -a; . ../.env; set +a
dart bin/main.dart --apply-migrations
```

The API listens on `http://localhost:8080` by default. The Flutter app reads
that URL from `puls3_flutter/assets/config.json` and displays
`Backend v1.0.0` when the health call succeeds.

## Tests and analysis

```bash
dart test
dart analyze
cd ../puls3_client && dart analyze
```

The integration tests use Serverpod's generated test tools and the test
PostgreSQL/Redis services started by the Compose command above (ports 9090 and
9091).

### End-to-end suites on the local sandbox

`test/e2e/` runs the hire lifecycle (F1, F5, F6, F7) on the real server stack
against the local Stellar network of the sandbox (#253). The suites register
their own agent, create ephemeral accounts and fund them from the local
Friendbot, so they need no secret and never reach a public network. A plain
`dart test` reports them as skipped.

```bash
docker compose -f puls3_server/docker-compose.yaml up -d soroban_standalone postgres_test redis_test
bash scripts/setup-local-soroban.sh        # deploys the contracts, writes .env.local-soroban
cd puls3_server
dart test -t e2e --run-skipped -j 1
```

- `-j 1` runs the files one after the other: they share the test database.
- `--run-skipped` is needed because the tag is skipped by default, which is how
  a plain `dart test` leaves them out (`dart_test.yaml`).
- `hire_relay_e2e_test.dart`: create, tamper check, relay `create_job`,
  idempotent resubmit, `fund`, with the database rows and the escrow job state.
- `feedback_e2e_test.dart`: the agent `submit` through the production
  `AgentSubmitSender`, consumer `complete`, `give_feedback`, and the catalog
  counting the rating.
- The suites play the wallets through the `SessionWallet` seam: the real
  wallet sign-in (`WalletAuthEndpoint`) is covered by
  `test/integration/wallet_session_hire_test.dart`.
- After re-running `scripts/setup-local-soroban.sh` the contracts are new and
  job ids restart, so hires left in `puls3_test` by earlier runs can collide
  with the new jobs (`JobMismatch`). Reset that database
  (`docker compose -f puls3_server/docker-compose.yaml down -v postgres_test`).

### Browser E2E of the hire flow

`puls3_flutter/integration_test/hire_flow_e2e_test.dart` drives the Flutter web
app in headless Chrome against the real server and the same sandbox: market,
agent page, `HireSheet`, the wallet signing `create_job` and `fund`, and the
confirmation. Flutter 3.44 does not run web integration tests with
`flutter test -d chrome`; the supported route is `flutter drive` with
chromedriver.

```bash
# Besides the sandbox above: chromedriver matching your Chrome
# (https://googlechromelabs.github.io/chrome-for-testing/).
CHROMEDRIVER=/path/to/chromedriver bash scripts/e2e-flutter-local.sh
```

The script seeds an agent and a funded consumer wallet
(`puls3_server/tool/e2e_seed_local.dart`), starts the server on a database of
its own (`puls3_e2e`, dropped afterwards) and runs `flutter drive`. The seed
also stores the agent's key in custody in that database, as a Studio deploy
does, because the server refuses to hire an agent without it. Every key is
ephemeral and lives in a temp directory the script removes. The wallet is
`AutomatedKeyWallet`, a test fixture next to the test. The USDC balance check
(Horizon on testnet) is stood in for, because the sandbox pays in its native
token.

#### Browser E2E in Docker (needed on Windows)

On native Windows the run above cannot sign in: Dart's `Platform.environment`
upper-cases variable names there, so the server never finds
`SERVERPOD_PASSWORD_walletAuthSigningKey` and the hire fails with "Your wallet
session ended". Production and CI run Linux, so the journey runs in a Linux
container instead:

```bash
# Same services and setup as above; no Flutter, Stellar CLI or Chrome needed.
bash scripts/e2e-flutter-docker.sh
```

- The image (`docker/e2e-browser/Dockerfile`) pins Flutter 3.44.4 (Dart
  3.12.2), Stellar CLI 28.1.0 and Chrome for Testing with its chromedriver,
  each checked against its SHA-256. It holds no secret.
- The container joins the compose network and reaches `soroban_standalone`
  and `postgres_test` by name; it sees a copy of `.env.local-soroban` whose
  URLs name the service. Only `POSTGRES_TEST_PASSWORD` is passed in.
- The repository is mounted read-write, but every `.dart_tool/`, `build/` and
  Flutter `ephemeral/` directory and the pub cache live in named volumes
  (`puls3-e2e-browser-*`), so the Windows workspace keeps its own artifacts
  and later runs reuse the Linux ones. Remove them with
  `docker volume ls -q --filter name=puls3-e2e-browser | xargs docker volume rm`.
- The scripts run from a copy with `\r` stripped, so a CRLF checkout works.
- The first run builds the image and compiles the web app (several minutes).

## Regenerate Serverpod code

After changing an endpoint or a `*.spy.yaml` model, regenerate the server,
client, and test helpers:

```bash
serverpod generate
git status --short
```

Commit all generated changes. A second generation run must leave the working
tree unchanged.

When you are finished, you can shut down Serverpod with `Ctrl-C`, then stop Postgres and Redis.

```bash
docker compose stop
```

## Health version and allowed origins

`health.check` returns the package version from `pubspec.yaml`. When
`PULS3_GIT_SHA` is set, the commit is appended as semver build metadata, for
example `1.0.0+63fbad2`, so a deployed server names the commit it runs. Without
it, `health.check` returns `1.0.0` alone. A value with characters other than
letters, digits, `-` and `.` stops the server at startup.

Browsers may call the API server only from an origin listed in
`PULS3_ALLOWED_ORIGINS` (comma-separated, for example
`https://puls3.org,https://puls3-4lw.pages.dev`). In the `development` run mode, loopback origins
(`localhost`, `127.0.0.1` or `[::1]`, any port) are allowed as well; in
`production`, `staging` and `test` they are not. A request from any other
origin, or with several `Origin` headers, gets `403` before an endpoint runs.
Requests without an `Origin` header, such as `curl`, are not affected.

Serverpod 4.0.4 answers CORS preflight (`OPTIONS`) requests in its own core
middleware, before added middleware runs, so preflight responses still carry
`Access-Control-Allow-Origin: *`. The request that follows is still rejected
when its origin is not allowed.

## Deploy to Serverpod Cloud

The server runs on Serverpod Cloud, which also provides its PostgreSQL
database. The Flutter web app is deployed separately to Cloudflare Pages (not
covered here); build it with `--dart-define=PULS3_API_URL=<api-url>` so it
calls this server. In the Pages project, `scripts/cloudflare-pages-build.sh`
reads `PULS3_API_URL`, `PULS3_HIRE` and `PULS3_STUDIO` from the environment; set
`PULS3_HIRE=server` once this server has wallet sign-in configured, or hires
stay the labelled demo. On the production branch (`main`) the build sets
`STUDIO=server` by default, so the public Studio saves, test-runs and deploys
through this server; set `PULS3_STUDIO=demo` to opt a production build out.
Preview branches keep the labelled demo unless `PULS3_STUDIO` is set.

With `PULS3_HIRE=server` or the server Studio the Pages build also needs the
SEP-10 values the app
checks every sign-in challenge against before the wallet is prompted (#136),
and fails without them. All three are public:

| Pages variable | Value for this deployment |
|---|---|
| `PULS3_AUTH_SERVER_SIGNING_KEY` | the `G…` account of the `walletAuthSigningKey` password (today `GBEELNIKCJBWCVR4KYEP4LTLXWGD5MOSLRF32CHFULLMPGNTKBBKHOEG`) |
| `PULS3_AUTH_HOME_DOMAIN` | `puls3-hub-on-stellar.api.serverpod.space` |
| `PULS3_AUTH_WEB_AUTH_DOMAIN` | `puls3-hub-on-stellar.api.serverpod.space` |

If `walletAuthSigningKey` is rotated, update `PULS3_AUTH_SERVER_SIGNING_KEY`
and rebuild Pages, or every sign-in is refused before the wallet prompt.

| | URL |
|---|---|
| API server | `https://puls3-hub-on-stellar.api.serverpod.space/` |
| Health check | `POST https://puls3-hub-on-stellar.api.serverpod.space/health/check` |

Run every command from `puls3_server/`. The commands were checked against the
help output and source of `serverpod_cloud_cli` **1.0.0**.

> **Git Bash on Windows:** pub installs the CLI as `scloud.bat`, which Git Bash
> does not find as `scloud`. Run `alias scloud=scloud.bat` first, or use
> PowerShell or cmd.

### First deploy

Do these steps once, in order. Steps 1 and 2 are per machine; steps 3 to 7 are
per project.

1. **Install the CLI.** Pick the path that matches `dart --version`:

   - **Dart 3.12.2 or newer (preferred):**

     ```bash
     dart pub global activate serverpod_cloud_cli 1.0.1
     ```

     1.0.1 is the latest release and needs Dart 3.12.2. The first deploy of
     `puls3-hub-on-stellar` used it.

   - **Older Dart (3.10.3 to 3.12.1):** `dart pub global activate
     serverpod_cloud_cli 1.0.0` installs but does not compile, because pub
     picks `serverpod_cloud_shared` 1.0.1, which dropped a class 1.0.0 uses.
     Install 1.0.0 with that dependency pinned instead:

     ```bash
     mkdir -p ~/scloud-1.0.0/bin && cd ~/scloud-1.0.0
     printf '%s\n' \
       'name: scloud_1_0_0' \
       'publish_to: none' \
       'environment:' \
       "  sdk: '>=3.10.3 <4.0.0'" \
       'dependencies:' \
       '  serverpod_cloud_cli: 1.0.0' \
       'dependency_overrides:' \
       '  serverpod_cloud_shared: 1.0.0' \
       'executables:' \
       '  scloud: scloud' > pubspec.yaml
     dart pub get
     # Windows: $LOCALAPPDATA/Pub/Cache. macOS/Linux: $HOME/.pub-cache.
     PUB_CACHE_DIR="${PUB_CACHE:-$LOCALAPPDATA/Pub/Cache}"
     cp "$PUB_CACHE_DIR/hosted/pub.dev/serverpod_cloud_cli-1.0.0/bin/serverpod_cloud_cli.dart" bin/scloud.dart
     dart pub global activate --source path .
     cd -
     ```

   Check it with `scloud version`.

2. **Log in.** Create an account at <https://accounts.serverpod.dev/> first.

   ```bash
   scloud auth login
   ```

3. **Create the project with a database.** Project ids are global; pick a free
   one. `starter` is the smaller of the two plans the CLI offers (`starter`,
   `growth`). A plan can be billed: check its price and apply the hackathon
   credits in the Serverpod Cloud console before you run this.

   ```bash
   scloud project create <project-id> --plan starter --enable-db
   ```

4. **Link the project.** This writes the id into `scloud.yaml`, replacing
   `REPLACE_WITH_PROJECT_ID`, and keeps the pre-deploy script. Commit the
   change, so teammates can deploy without linking. The file holds only the
   project id, not credentials.

   ```bash
   scloud project link <project-id>
   git add scloud.yaml && git commit -m "chore(server): link Serverpod Cloud project"
   ```

   Do not use `scloud launch` here: it adds `serverpod run flutter_build` and
   `serverpod generate` as pre-deploy scripts, and neither is needed.

5. **Set the environment variables.** The values are public, so they are plain
   variables, not secrets.

   ```bash
   scloud variable set SERVERPOD_APPLY_MIGRATIONS true
   scloud variable set PULS3_ALLOWED_ORIGINS https://puls3.org,https://puls3-4lw.pages.dev
   ```

   - `SERVERPOD_APPLY_MIGRATIONS=true` makes Serverpod apply pending migrations
     from `migrations/` at every start (the same as `--apply-migrations`
     locally).
   - `PULS3_ALLOWED_ORIGINS` is the origin of the Cloudflare Pages deployment
     (no path; comma-separate several).
   - `PULS3_GIT_SHA` is set by the pre-deploy script in step 6. Do not set it
     by hand.
   - `PULS3_STELLAR_*` default to testnet. Set them only for another network.

   For hires on testnet (wallet sign-in, payment confirmation and the agent
   run), also set these. Replace `<api-host>` with
   `<project-id>.api.serverpod.space`:

   ```bash
   scloud variable set PULS3_AUTH_HOME_DOMAIN <api-host>
   scloud variable set PULS3_AUTH_WEB_AUTH_DOMAIN <api-host>
   scloud variable set PULS3_TRACKER_ENABLED true
   scloud variable set PULS3_INDEXER_ENABLED true
   scloud variable set PULS3_RUNTIME_ENABLED true
   scloud variable set PULS3_WORKERS_AI_ACCOUNT_ID <cloudflare-account-id>
   scloud variable set PULS3_HIRE_JOB_DURATION_SECONDS 259200
   scloud variable set PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS 600
   scloud variable set PULS3_STELLAR_INCLUSION_FEE_STROOPS 100000
   scloud variable set PULS3_PLATFORM_FEE_BPS 0
   ```

   - `PULS3_AUTH_*`, with the `walletAuthSigningKey` password below, enable
     [wallet sign-in](#wallet-sign-in). Production does not start without
     them.
   - `PULS3_TRACKER_ENABLED=true` is required for hires: a hire is paid only
     when the tracker confirms its `fund`
     ([Chain submission tracker](#chain-submission-tracker)). Without it, a
     payment stays at "Awaiting payment".
   - `PULS3_INDEXER_ENABLED` keeps the catalog in sync with the registry.
     `PULS3_RUNTIME_ENABLED` and the Workers AI account run the agent of every
     paid hire ([Agent runtime](#agent-runtime)).
   - The four hire values are the ones of the testnet end-to-end proof
     ([Hire configuration](#hire-configuration)). `PULS3_PLATFORM_FEE_BPS`
     must equal `NetworkConfig.platformFeeBps` (0 on testnet).

   Serverpod Cloud generates and manages the platform passwords (see
   [Secrets in Serverpod Cloud](#secrets-in-serverpod-cloud)). Set the two
   that hires need from files: `walletAuthSigningKey`
   ([Wallet sign-in](#wallet-sign-in)) and `workersAiApiToken`
   ([Agent runtime](#agent-runtime)). Check them with `scloud password list`.

6. **Deploy.**

   ```bash
   scloud deploy --show-files
   ```

   Before it uploads, `scloud deploy` runs the pre-deploy script from
   `scloud.yaml` on your machine, in `puls3_server/` (through `cmd /c` on
   Windows, `bash -c` elsewhere): `dart run tool/set_deploy_sha.dart` sets
   `PULS3_GIT_SHA` to `git rev-parse --short HEAD`, with a `-dirty` suffix when
   tracked files have uncommitted changes. If the script fails (no `git`, no
   `scloud` on the `PATH`, not logged in), the deploy stops before uploading.
   The command waits for the rollout. To follow it again later, run
   `scloud status deployment show`.

7. **Verify.** Replace `<api>` with `https://<project-id>.api.serverpod.space`.

   ```bash
   curl -s -X POST -d '{}' <api>/health/check
   curl -s -o /dev/null -w '%{http_code}\n' -X POST -d '{}' \
     -H 'Origin: https://puls3.org' <api>/health/check             # 200
   curl -s -o /dev/null -w '%{http_code}\n' -X POST -d '{}' \
     -H 'Origin: https://puls3-4lw.pages.dev' <api>/health/check   # 200
   curl -s -o /dev/null -w '%{http_code}\n' -X POST -d '{}' \
     -H 'Origin: https://evil.example.com' <api>/health/check      # 403
   curl -s -o /dev/null -w '%{http_code}\n' -X POST -d '{}' \
     -H 'Origin: http://localhost:3000' <api>/health/check         # 403
   ```

   The first call returns JSON whose `version` is `1.0.0+<sha>` for the commit
   you deployed. If it shows `1.0.0` alone, `PULS3_GIT_SHA` was not applied:
   check `scloud variable list`, then run `scloud deploy --redeploy`. The
   localhost call must return 403: loopback origins are allowed only in the
   `development` run mode. A 200 there means the server is not running in
   `production`; check the "run mode" line in `scloud log` before going on.
   Finally, put the API URL in the root README.

### Redeploy

**Automatic.** `.github/workflows/deploy-server.yml` deploys `main` to
Serverpod Cloud every time the CI workflow passes on a push to `main`, one
deploy at a time, and fails unless `health/check` then reports
`1.0.0+<commit>`. It needs the repository secret `SERVERPOD_CLOUD_TOKEN`
(`scloud auth create-token`, then `gh secret set SERVERPOD_CLOUD_TOKEN`). It does
not set variables or passwords: set new ones (step 2 below) before merging the
code that needs them. Run it by hand from the Actions tab
(`workflow_dispatch`) to redeploy `main`.

**Manual**, when Actions is unavailable. Anyone with access to the project, on
a machine where steps 1 and 2 are done:

1. Update `main`: `git switch main && git pull`.
2. Compare `scloud variable list` and `scloud password list` with step 5 and
   set anything new first. A production server without the
   [wallet sign-in](#wallet-sign-in) settings does not start.
3. Deploy: `scloud deploy`. The pre-deploy script sets `PULS3_GIT_SHA`.
4. Verify with the three calls of step 7. `version` must name the commit you
   just pulled. With the hire settings in place, `walletAuth/createChallenge`
   answers instead of `Endpoint not found`.

To change only variables (no new code), run `scloud variable set ...` and then
`scloud deploy --redeploy`, which redeploys the running build with the latest
variables and secrets.

### If a deploy or migration fails

| Look at | Command |
|---|---|
| Rollout state of the latest deploy | `scloud status deployment show` |
| Build output (compile and dependency errors) | `scloud build log` |
| Server logs (startup, migrations, requests) | `scloud log --since 1h` or `scloud log --tail` |
| Running podlets and service URLs | `scloud status live` |

- **Fix forward:** fix the cause on a branch, merge it to `main`, and redeploy.
- **Go back to a known good commit:** `git switch --detach <good-sha>`, then
  `scloud deploy`. The CLI has no rollback command, so this uploads and builds
  that commit again.
- **Migrations** only move forward. Older code is not guaranteed to work
  against a newer schema, so prefer fixing forward once a migration has run.
  `scloud db backup` manages database snapshots; take one before a risky
  migration.

Not verified from the CLI (check on the first deploy): whether a failed build
or rollout keeps the previous deployment serving, and whether a variable set
by the pre-deploy script is always applied by the same deploy (the step 7
check catches it).

### Secrets in Serverpod Cloud

How each row of `docs/infra/secrets.md` (#30) maps to Serverpod Cloud:

| Secret | In Serverpod Cloud |
|---|---|
| `database`, `redis`, `serviceSecret` | Platform-managed. No action |
| `emailSecretHashPepper`, `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper` | Platform-managed. No action |
| `serverSideSessionKeyHashPepper` | Not used: the server issues JWTs only |
| `mySharedPassword` | Unused template entry. Do not set |
| `walletAuthSigningKey`, `escrowRelaySigningKey` (optional `S…` that signs permissionless `release` and `claim_refund`; without it the tracker still runs and those calls stay off), `workersAiApiToken`, `anthropicApiKey` (optional) | `scloud password set <name> --from-file <file>`. The server reads it with `getPassword('<name>')` (injected as `SERVERPOD_PASSWORD_<name>`) |
| Stellar CLI keys (deployer, escrow admin, agent wallet, test client, test USDC issuer) | Never. They stay in the Stellar CLI config of the person who runs the scripts |

Use `scloud variable set --secret <NAME> --from-file <file>` only for a secret
that must not get the `SERVERPOD_PASSWORD_` prefix. Prefer `--from-file` over a
value on the command line, so the secret does not land in the shell history.
Never upload `config/passwords.yaml`.

### Reference

| Task | Command |
|---|---|
| List variables | `scloud variable list` |
| Apply changed variables without uploading | `scloud deploy --redeploy` |
| Preview the upload without deploying | `scloud deploy --wet-run --show-files` |

The upload follows `.gitignore` and the repository-root `.scloudignore`:
passwords, run-mode configs (Serverpod Cloud generates the server
configuration), tests, Docker files and `web/app` are left out.
