# Serverpod hackathon submission package

- **Issue:** [#4](https://github.com/Zer0-Knowledge-Hack/puls3/issues/4) · **Milestone:** Serverpod (Oct 14) · **Status:** in progress
- **Deadline:** 2026-10-14 23:59 CEST (21:59 UTC) — **no extensions**
- **Submission form:** <https://builderbase.com/event/build-something-real-the-serverpod-hackathon>
- **Last checked:** 2026-10-10

This is the single place that maps the hackathon's requirements and judging criteria to concrete evidence in this repository. It is written to be honest about what works, what is a demo, and what is pending: the "Does it work" criterion (30%) explicitly asks that **nothing critical is faked**.

## 1. Rules confirmed from the official source

Checked 2026-10-10 against the **official rules PDF** (the primary source) and the event page:

- Official rules PDF: <https://sbnxiexidrjwubdfjepb.supabase.co/storage/v1/object/public/uploads/super_event/03771d49-7932-4408-a663-c1db1db88a15/6368bd87-82c9-4759-9b27-6970747b49c3.pdf> (HTTP 200, `application/pdf`)
- Event page (BuilderBase): <https://builderbase.com/event/build-something-real-the-serverpod-hackathon>
- Luma listing: <https://luma.com/builde-mked>
- A public transcription of the same PDF (convenience copy; the PDF prevails): <https://github.com/erickrex/serverpod_dance_trainer/blob/main/docs/rules_serverpod_hackathon.md>

| Rule | Value |
|---|---|
| Submission Period | 2026-09-15 17:30 to **2026-10-14 23:59 CEST** (21:59 UTC). **No extensions.** |
| Judging Period | 2026-10-15 09:00 to 2026-10-20 17:00 CEST |
| Winners announced | 2026-10-22 18:00 CEST, at the Full Stack Flutter conference |
| What to build | A **full-stack application with Serverpod as the backend**. No tracks. |
| Repository | URL to a code repository with **all source, assets and instructions**. Public is simplest; a private repo must be shared with three Serverpod emails. |
| Text description | Features, functionality, **and how it was built**. Mandatory. |
| Build/run instructions | Mandatory. |
| Demo video | **Under 2 minutes** (judges are not required to watch beyond 2:00), showing the project working, **publicly visible on YouTube or Vimeo**. No third-party marks or copyrighted music without permission. Mandatory and primary material. |
| Testing access | A working link/demo/test build, free of charge until the Judging Period ends. |
| Language | English. |
| AI tools | Permitted and encouraged; use **must be disclosed** in the text description. |
| Team size | Max 4 members. |
| Prizes | $10,000 cash + $10,000 Serverpod Cloud credits (the "$20,000" on the event page). |

**Judging Criteria (§6, Stage Two).** Stage One is a pass/fail eligibility screen (theme fit and reasonable use of the Serverpod stack). Stage Two scores:

| Criterion | Weight | What the judges look for |
|---|---|---|
| Does it work | 30% | It runs, the core flow completes, nothing critical is faked |
| Use of the Serverpod stack | 25% | Doing real work, not sitting behind a static page |
| Craft and technical creativity | 25% | Rough is fine, careless is not |
| Usefulness | 20% | A clear user with a clear problem, and this helps |

**Note on the issue's wording.** Issue #4 quotes "23:59" without a timezone. The official rules are in **CEST**, so the deadline is 2026-10-14 23:59 CEST = **21:59 UTC**. Plan against the UTC value to be safe.

## 2. Required items — checklist

| # | Required item | Status | Evidence |
|---|---|---|---|
| 1 | Full-stack app with Serverpod backend | ✅ | Serverpod 4.0.4 (`puls3_server/pubspec.yaml`), live at <https://puls3-hub-on-stellar.api.serverpod.space/>; Flutter app at <https://puls3-4lw.pages.dev/> |
| 2 | Code repository with all source, assets, instructions | ✅ | This repository (public, Apache-2.0) |
| 3 | Text description (features, functionality, how built) | ✅ | [`README.md`](../../README.md) + [§5 text description](#5-text-description-for-the-submission-form) below, incl. the AI-tool disclosure |
| 4 | Build and run instructions | ✅ | [`README.md`](../../README.md#build-and-run) + [`docs/infra/secrets.md`](../infra/secrets.md#run-against-testnet-from-a-fresh-clone) + [`CONTRIBUTING.md`](../../CONTRIBUTING.md) |
| 5 | Demo video, < 2:00, public (YouTube/Vimeo) | ⏳ **pending** (human task) | [§4 video script](#4-demo-video-script) ready; link to be added to the README and here |
| 6 | Testing access, free until judging ends | ✅ | Live web app + live server (both above); no login required for the catalog |
| 7 | Materials in English | ✅ | All docs and UI copy are English |
| 8 | AI-tool use disclosed | ✅ | [§5](#5-text-description-for-the-submission-form) |
| 9 | Submission entered on BuilderBase | ⏳ **pending** (human task) | Screenshot/email to be posted on #4 before the deadline |

## 3. Judging criteria → evidence

### Does it work (30%)

| Evidence | Where |
|---|---|
| Live Serverpod backend responds | `POST https://puls3-hub-on-stellar.api.serverpod.space/health/check` → `{"__className__":"BackendHealth","version":"1.0.0+4df3ba4"}` |
| Live Flutter web app | <https://puls3-4lw.pages.dev/> (HTTP 200) |
| Live agent catalog served from the on-chain registry | `POST .../agent/list` → 8 `AgentSummary` objects (`agt-001`…`agt-008`) |
| Hire funded end-to-end through the server relay | `create_job` [`602dfd37…`](https://stellar.expert/explorer/testnet/tx/602dfd37e5185020513cb2f6d82879ee317b4bb0f514221d563c4a6b831cf388), `fund` [`bb52ff04…`](https://stellar.expert/explorer/testnet/tx/bb52ff04c07b29bfab10073e641e9d7bd77489db4c4e83d588079762cf5f60ad) (`puls3_server/tool/e2e_relay_testnet.dart`) |
| A completed ERC-8183 escrow job | job 3 `complete` [`ee6dfb52…`](https://stellar.expert/explorer/testnet/tx/ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4) |
| Tests | `puls3_domain/test/`, `puls3_server/test/integration/` (`withServerpod`), `puls3_flutter/test/` |
| CI gate | [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) |

**Honesty note (important for this criterion).** The core flow that runs end-to-end is: **catalog → wallet sign-in → hire → create_job → fund → on-chain verification → agent run**. Two parts are **not** wired to the server yet and must not be presented as real in the video:

- **Studio deploy** uses `FakeDeployGateway` in the app ([`puls3_flutter/lib/src/deploy/fake_deploy_gateway.dart`](../../puls3_flutter/lib/src/deploy/fake_deploy_gateway.dart)); the server deploy endpoints are #18/#35. The UI already labels its result as a demo.
- **Rating/reputation** is UI-only today (agents show `rating: 0.0`; no feedback endpoint); the Reputation Registry is #14.

The agent **runtime** is implemented (`puls3_server/lib/src/runtime/`) but **off by default** (`PULS3_RUNTIME_ENABLED=false`), and the deployed server leaves the chain tracker off.

### Use of the Serverpod stack (25%)

| Serverpod feature | Evidence |
|---|---|
| Endpoints | `puls3_server/lib/src/agent/agent_endpoint.dart`, `hire/hire_endpoint.dart`, `auth/wallet_auth_endpoint.dart`, `health/health_endpoint.dart` (13 methods) |
| ORM + migrations | 26 `.spy.yaml` models under `puls3_server/lib/src/`; migrations in `puls3_server/migrations/` |
| Generated client | `puls3_client/lib/src/protocol/` (generated by `serverpod generate`) |
| Authentication | `serverpod_auth_idp_server: 4.0.4`; SEP-10 wallet sign-in (`auth/wallet_auth_endpoint.dart`, `auth/sep10_verifier.dart`), JWT refresh (`auth/jwt_refresh_endpoint.dart`) |
| Serializable exceptions | `puls3_server/lib/src/generated/puls3_api_exception.dart`, `agent/agent_catalog_unavailable.spy.yaml` |
| Health checks | `health/health_endpoint.dart`; verified on the deployed server |
| Testing framework | `puls3_server/test/integration/*` using `withServerpod` and `test_tools/serverpod_test_tools.dart` |
| Serverpod Cloud deploy | `puls3_server/README.md#deploy-to-serverpod-cloud`, `scloud.yaml`, live at `puls3-hub-on-stellar.api.serverpod.space` |
| Postgres + Redis | `puls3_server/docker-compose.yaml`; Serverpod runtime config |

### Craft and technical creativity (25%)

| Evidence | Where |
|---|---|
| Hexagonal architecture with a pure-Dart domain | [`puls3_domain/`](../../puls3_domain/) · [ADR-0001](../adr/0001-system-architecture.md) (#5) |
| Escrow relay: the server prepares, the wallet signs, the server verifies byte-for-byte and tracks | `puls3_server/lib/src/hire/escrow_relay_service.dart`, `ledger/envelope_codec.dart`, `chain/chain_submission_tracker.dart` |
| SEP-10 wallet authentication | `puls3_server/lib/src/auth/sep10_verifier.dart` |
| Custodied agent wallets with encrypted secrets | `puls3_server/lib/src/agent/stellar_agent_wallet_custody.dart`, `agent/aes_gcm_secret_cipher.dart` |
| Agent runtime with provider adapters and a timeout contract | `puls3_server/lib/src/runtime/agent_runner.dart`, `runtime/adapters/anthropic_runtime.dart`, `runtime/adapters/workers_ai_runtime.dart` |
| ERC-8183 escrow and ERC-8004-aligned identity on Soroban | `contracts/escrow/`, `contracts/identity-registry/`, [ADR-0005](../adr/0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) |
| Catalog indexer (bootstrap + event cursor, chain as source of truth) | `puls3_server/lib/src/agent/catalog_indexer.dart` |
| Six ADRs and a spike library | [`docs/adr/`](../adr/), [`docs/spikes/`](../spikes/) |

### Usefulness (20%)

| Evidence | Where |
|---|---|
| Clear users and problem | [Vision](../vision.md) (#2): builders who want to earn and consumers who want trustworthy agents |
| Market research for the target niche | [LATAM B2B market](../research/latam-b2b-market.md) (#80) |
| Eight demo agents for real tasks | `POST .../agent/list`; [`contracts/deployments/demo-agents.json`](../../contracts/deployments/demo-agents.json) |
| Pay-per-task in USDC, verified on-chain before the agent runs | The hire evidence in [§3](#does-it-work-30) |

## 4. Demo video script

Target: **< 2:00**, English, YouTube or Vimeo, public. The rules say presentation quality is not scored separately, so the video shows the working product, not production polish. **Do not fake the Studio deploy or the rating.**

| Scene | Duration | What is shown |
|---|---|---|
| 1. What puls3 is | 0:00–0:10 | Title card + one line: "Create AI agents, find them, and pay them per task in USDC on Stellar." |
| 2. Marketplace (live) | 0:10–0:25 | The web app loads the catalog **from the deployed Serverpod server**; open an agent detail (skills, price, on-chain wallet). |
| 3. Connect wallet | 0:25–0:40 | Connect Freighter, sign the SEP-10 challenge, session established. |
| 4. Hire and pay | 0:40–1:05 | Enter a task, sign `create_job`, sign `fund`; show "Verifying payment…" → `funded`; open the escrow transaction on stellar.expert. |
| 5. Agent runs, result, accept | 1:05–1:30 | The server runs the agent after the payment is verified, returns the result; the consumer accepts (`complete`); show the completion transaction. |
| 6. On-chain + stack recap | 1:30–1:45 | The escrow contract and completed job on stellar.expert; the Serverpod health response naming the deployed commit. |
| 7. Close | 1:45–1:55 | Stack (Flutter + Serverpod 4 + Soroban), repo link, live links. State plainly that Studio deploy and rating are next (#18/#35, #14). |

**If the Studio deploy and rating are wired before recording:** replace scene 6 with a deploy (registration tx on explorer) and a rating, and drop the caveat in scene 7. Otherwise, scene 7's caveat keeps the video honest.

**Recording checklist:** 1080p, browser zoom so text is legible, no copyrighted music, no third-party logos, under 2:00, uploaded as **public** on YouTube/Vimeo, link added to the README and to this doc.

## 5. Text description (for the submission form)

> **puls3 — the agent hub on Stellar.** puls3 is a full-stack marketplace where builders create AI agents, consumers find them, and agents are paid per task in USDC on the Stellar network. It is a Flutter web app backed by a **Serverpod 4** backend in Dart, with Soroban smart contracts for agent identity and an ERC-8183 escrow for payments.
>
> **Features.** An Agent Studio (define an agent's name, skills, model, prompt and price); a Marketplace that lists agents from an on-chain identity registry; wallet-based sign-in (SEP-10) with Freighter; a hire flow where the consumer signs `create_job` and `fund` on a Soroban escrow and the server verifies the funded job on-chain before running the agent; and a Dart agent runtime that executes the task on the builder's chosen model provider.
>
> **How it was built.** The server is Serverpod 4 (endpoints, ORM and migrations, generated client, `serverpod_auth_idp`, health checks, `withServerpod` tests) deployed to Serverpod Cloud; the app is Flutter web; the domain is a pure-Dart package with no framework imports; the chain work goes through a single adapter that builds and verifies Soroban envelopes. The escrow relay is the core idea: the server prepares each transaction, the user's wallet signs it unchanged, the server verifies the signed bytes against what it prepared, relays it, and a tracker confirms it on-chain. Decisions are recorded in the ADRs under `docs/adr/`.
>
> **AI tools disclosure.** This project was developed with AI coding assistants and agentic tooling (including OpenCode), as permitted by §4 of the rules.

## 6. Compliance and risks

| Item | Status / action |
|---|---|
| **"New Projects Only" (§4)** | **Risk.** The rules require projects newly created during the Submission Period (from 2026-09-15). puls3's repository predates it. The team must confirm with the organizers (`nate@builderbase.com`) that the Serverpod backend work qualifies, or document what was built during the period. **Do not ignore this.** |
| Third-party marks/music in the video | None planned. Confirm before upload. |
| Third-party APIs in the project | Stellar RPC, Circle testnet USDC, LLM providers; all used under their terms. |
| Private repo sharing | Not needed: the repository is public. |
| Testing access | Live app + server are public and free; keep them up until 2026-10-20 17:00 CEST. |
| Financial/preferential support (§4) | Confirm the project received none from Serverpod/BuilderBase. |
| Team size | Max 4; confirm the submitting team. |

## 7. Submission checklist (human tasks)

- [ ] Record and upload the demo video (< 2:00, public) and add the link to the README and [§2](#2-required-items--checklist)
- [ ] Confirm the "New Projects Only" eligibility with the organizers
- [ ] Enter the submission on BuilderBase before 2026-10-14 23:59 CEST
- [ ] Post the submission confirmation (screenshot/email) on [#4](https://github.com/Zer0-Knowledge-Hack/puls3/issues/4)
- [ ] Keep the live app and server up until the Judging Period ends (2026-10-20 17:00 CEST)
