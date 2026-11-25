# ADR-0015: Branching strategy, stacked PRs, and artifact versioning

- **Status:** Proposed
- **Date:** 2026-11-25
- **Issue:** #425
- **Related:** [ADR-0001](0001-system-architecture.md) (repo layout) · [ADR-0004](0004-agent-manifest-and-deployment.md) (agent manifest versioning) · [ADR-0010](0010-npm-sdk-signs-with-a-developer-key.md) (npm SDK contract pinning) · [ADR-0014](0014-installable-skills.md) (versioned skill packs) · [CONTRIBUTING.md](../../CONTRIBUTING.md) · [docs/sdk/releasing.md](../sdk/releasing.md)

## Context

`puls3` is a multi-stack monorepo containing:

- Dart/Flutter packages (`puls3_domain`, `puls3_client`, `puls3_sdk`, `puls3_cli`, `puls3_mcp`, `puls3_server`, `puls3_flutter`), plus the upcoming npm SDK ([ADR-0010](0010-npm-sdk-signs-with-a-developer-key.md));
- Soroban Rust smart contracts (`identity-registry`, `reputation-registry`, `escrow`, `placeholder`);
- Continuous deployments from `main` to Serverpod Cloud (`puls3_server`) and Cloudflare Pages (`puls3_flutter`);
- Versioned domain and database artifacts (`puls3.agent-manifest/v1`, `skill_packs`, Serverpod migrations).

The repository already defines parts of a release and Git workflow: GitHub Flow on `main`, Conventional Commits, `CI / gate`, `Secrets / scan`, `Issue gate / issue-gate`, and SemVer + `<package>-v<version>` tags in [docs/sdk/releasing.md](../sdk/releasing.md). However, an audit of the current repository shows several gaps where conventions are incomplete or applied inconsistently:

1. **Branch naming and hygiene:** `CONTRIBUTING.md` documents only `feat/`, `docs/`, and `chore/`, while the repository has accumulated `fix/`, `ci/`, `test/`, `spike/`, un-issued branches, local review branches (`review-pr-*`, `pr-*`), and over 100 unpruned remote branches.
2. **Stacked PR friction:** `main` enforces squash-merge, `require_last_push_approval`, and `enforce_admins`. When large features ship as chained PRs, squash-merging a parent PR leaves child PRs conflicted, dismisses approvals, and can auto-close child PRs if the parent branch is deleted before retargeting.
3. **Uneven artifact versioning:**
   - `puls3_client` and `puls3_sdk` have `0.1.0` and `CHANGELOG.md`, but zero git release tags exist yet and `pubspec.yaml` lacks Melos `command.version` configuration.
   - `puls3_domain`, `puls3_cli`, and `puls3_mcp` have `publish_to: none` and no `version:` field.
   - `puls3_server` reports `1.0.0+<short_sha>` via `PULS3_GIT_SHA`, while `puls3_server/CHANGELOG.md` still has the Stagehand template and `puls3_server/Dockerfile` has no OCI image annotations (`org.opencontainers.image.*`).
   - `puls3_flutter` keeps a static `1.0.0+1` and `scripts/cloudflare-pages-build.sh` passes no `--build-name` or `--build-number`.
   - Soroban contracts expose `version()` matching `Cargo.toml` and record `wasm_hash_sha256` in `contracts/deployments/testnet.json`, but builds do not embed SEP-55 metadata (`--meta`) and deployment manifests do not record `crate_version` or `git_commit`.

## Decision

### 1. Branching strategy: Strict GitHub Flow on `main` (no GitFlow)

`puls3` will **not** adopt GitFlow (`develop` / `release/*` branches). In a multi-stack monorepo with continuous deployment on `main`, a long-lived `develop` branch multiplies merge conflicts and creates drift between contracts, backend, and frontend.

Instead, we standardize on **strict GitHub Flow (trunk-based on `main`)**:

1. **Single permanent branch (`main`):** always green and deployable. Direct pushes and force pushes remain blocked.
2. **Closed branch taxonomy:**
   - Standard work: `<type>/<issue-number>-<short-slug>` where `<type>` is strictly one of:
     `feat` · `fix` · `docs` · `chore` · `ci` · `test` · `spike`
   - Patching an already-published SDK release when `main` has unreleased breaking changes: `hotfix/<package>-<issue-number>-<short-slug>` branched from `<package>-v<X.Y.Z>` and cherry-picked back to `main`.
3. **No review or scratch branches on `origin`:**
   - Local PR reviews and agent checks run in detached worktrees (`git worktree add --detach`) rather than pushing `review-pr-*` or `local/*` branches.
   - Enable GitHub's *Automatically delete head branches* setting for standard PRs.
4. **Conventional Commits in PR titles:**
   - Because `main` uses squash-merge, every PR title must follow `<type>(<scope>): <summary> (#<issue>)` (or `<type>: <summary> (#<issue>)`), so `main` history remains machine-readable for changelogs and version bumps.

### 2. Stacked PR protocol

Prefer independent PRs against `main` (using feature flags or config toggles when incomplete). When a dependency stack (`A -> main`, `B -> A`) is unavoidable:

1. Limit stacks to at most **2–3 open PRs**.
2. Intermediate PRs use `Refs #<issue>` (never `Closes #<issue>`), per `Issue gate`.
3. **Required merge sequence:**
   - Retarget `B`'s base branch to `main` **before** deleting `A`'s branch (or merge `A` without deleting its branch first, then retarget `B` to `main`, then delete `A`'s branch).
   - Sync `B` with `main` (merge or rebase).
   - Request final review on `B` **after** the sync push so `require_last_push_approval` is not invalidated.

### 3. Artifact versioning: Independent versioning by artifact family

A single global repository version does not fit contracts, SDKs, and continuously deployed apps that evolve at different speeds. Each artifact family follows its own industry standard:

| Artifact family | Versioning scheme | Git tag / identifier | Metadata & provenance |
| --- | --- | --- | --- |
| **Publishable SDKs** (`puls3_client`, `puls3_sdk`, npm SDK) | **SemVer 2.0.0** (`0.x` until 1.0 stability) + [Keep a Changelog](https://keepachangelog.com) | `<package>-v<X.Y.Z>` (e.g. `puls3_sdk-v0.1.0`) + GitHub Release | Managed via `melos version` (Dart) and npm/Changesets (TS). Any contract redeploy changing pinned `contract_id`s requires a new SDK release (ADR-0010). |
| **Continuously deployed apps** (`puls3_server`, `puls3_flutter`) | **CalVer** `YYYY.MM.DD+<short_sha>` *(or SemVer `X.Y.Z+<short_sha>` — confirm in team review)* | No tag per commit (optional milestone tags) | `puls3_server` reports via `/health/check` (`PULS3_GIT_SHA`); `puls3_server/Dockerfile` sets `LABEL org.opencontainers.image.*`; `scripts/cloudflare-pages-build.sh` passes `--build-name` and `--build-number`. |
| **Soroban contracts** (`escrow`, `identity-registry`, `reputation-registry`) | **SemVer** in `Cargo.toml` + `pub fn version()` | `contracts/<name>-v<X.Y.Z>-<network>` on deploy | Release builds pass `--meta source_repo=github:Zer0-Knowledge-Hack/puls3` and `--meta revision=<sha>` (**SEP-55**). `contracts/deployments/<network>.json` records `crate_version`, `git_commit`, `wasm_hash_sha256`, and `contract_id`. |
| **Internal / CLI packages** (`puls3_domain`, `puls3_cli`, `puls3_mcp`) | `publish_to: none` internally; **SemVer** if distributed as binaries | `<bin>-v<X.Y.Z>` (only if published) | If `puls3_cli` or `puls3_mcp` ship standalone binaries on GitHub Releases, use `<bin>-v<X.Y.Z>-<os>-<arch>` + `SHA256SUMS`. |
| **Domain & DB artifacts** (`puls3.agent-manifest/v1`, `skill_packs`, migrations) | Schema `puls3.<type>/v<N>` + monotonic integer + SHA-256 / Serverpod timestamp | Persisted on-chain / in DB | Unchanged; follows ADR-0004, ADR-0014, and `puls3_server/migrations/migration_registry.txt`. |

## Open decisions for team review

Before moving this ADR to `Accepted`, the team should confirm two points on #425:

1. **App versioning (`puls3_server` and `puls3_flutter`):** adopt **CalVer** (`YYYY.MM.DD+<short_sha>`) for continuous deploys, or keep **SemVer** (`1.x.y+<short_sha>`) bumped per milestone/release?
2. **CLI / MCP binary distribution:** keep `puls3_cli` and `puls3_mcp` source-only inside the workspace, or publish prebuilt release archives?

## Consequences

- **Docs:** [CONTRIBUTING.md](../../CONTRIBUTING.md) updates section `3.2 Branches`, `3.3 Commits`, and `3.4 Pull requests` with the closed prefix list, detached-worktree review rule, and stacked PR merge protocol. [docs/sdk/releasing.md](../sdk/releasing.md) links to this policy and clarifies contract/SDK release coupling.
- **Repository settings:** enable *Automatically delete head branches* on GitHub and prune merged remote branches.
- **Tooling (follow-up issues):** Melos `command.version` config in `pubspec.yaml`, OCI labels in `puls3_server/Dockerfile`, build flags in `scripts/cloudflare-pages-build.sh`, and SEP-55 `--meta` + provenance fields in `contracts/deployments/*.json`.
