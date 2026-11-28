# ADR-0015: Branching strategy, stacked PRs, and artifact versioning

- **Status:** Proposed
- **Date:** 2026-11-25
- **Issue:** #425
- **Related:** [ADR-0001](0001-system-architecture.md) (repo layout) · [ADR-0004](0004-agent-manifest-and-deployment.md) (agent manifest versioning) · [ADR-0010](0010-npm-sdk-signs-with-a-developer-key.md) (npm SDK contract pinning) · [ADR-0014](0014-installable-skills.md) (versioned skill packs) · [CONTRIBUTING.md](../../CONTRIBUTING.md) · [docs/sdk/releasing.md](../sdk/releasing.md) (Dart release process) · [docs/sdk/releasing-npm.md](../sdk/releasing-npm.md) (npm release process)

## Context

`puls3` is a multi-stack monorepo containing:

- Dart/Flutter packages (`puls3_domain`, `puls3_client`, `puls3_sdk`, `puls3_cli`, `puls3_mcp`, `puls3_server`, `puls3_flutter`), plus the npm SDK `@puls3_org/sdk` (`puls3_sdk_ts/`, published as 0.1.0; [ADR-0010](0010-npm-sdk-signs-with-a-developer-key.md) is Accepted);
- Soroban Rust smart contracts (`identity-registry`, `reputation-registry`, `escrow`, `placeholder`);
- Continuous deployments from `main` to Serverpod Cloud (`puls3_server`) and Cloudflare Pages (`puls3_flutter`);
- Versioned domain and database artifacts (`puls3.agent-manifest/v1`, `skill_packs`, Serverpod migrations).

The repository already defines parts of a release and Git workflow: GitHub Flow on `main`, Conventional Commits, `CI / gate`, `Secrets / scan`, `Issue gate / issue-gate`, and SemVer + `<package>-v<version>` tags in [docs/sdk/releasing.md](../sdk/releasing.md), and a tag-triggered npm release in [docs/sdk/releasing-npm.md](../sdk/releasing-npm.md). However, an audit of the current repository shows several gaps where conventions are incomplete or applied inconsistently:

1. **Branch naming and hygiene:** `CONTRIBUTING.md` documents the pattern `<type>/<issue-number>-<short-slug>` with examples for `feat/`, `docs/` and `chore/` only. Across all pull requests the team has used `feat` (116), `docs` (52), `fix` (46), `chore` (18), `ci` (12), `test` (10) and `spike` (4), plus a long-lived `sandbox/nirium` branch for the #296 spike and `dependabot/*` branches opened by the bot. Some branches carry no issue number (`ci/consolidate-workflows`, `fix/web-cache-headers`), which matches the Issue gate's exceptions for docs-only and `no-issue` pull requests. Local review branches (`review-pr-*`, `pr-*`) were pushed at times, and closed or orphaned branches piled up on `origin` (36 remote branches, pruned to 7 on 2026-11-25).
2. **Stacked PR friction:** `main` requires one approval from someone other than the author, `require_last_push_approval`, `enforce_admins`, and the `gate` and `scan` checks. Squash merge is the usual method, but linear history is not required and merge commits are also used (for example #411). When large features ship as chained PRs (the #334 stacks reached four open PRs), squash-merging a parent PR leaves child PRs conflicted, dismisses approvals, and can auto-close child PRs if the parent branch is deleted before retargeting.
3. **Uneven artifact versioning:**
   - `puls3_client` and `puls3_sdk` are published as `0.1.0` on pub.dev under the verified publisher `puls3.org`, with `CHANGELOG.md` and the tags `puls3_client-v0.1.0` and `puls3_sdk-v0.1.0` (on `2fe943e`). They are released manually with `dart pub publish` per [docs/sdk/releasing.md](../sdk/releasing.md).
   - `@puls3_org/sdk` is published as `0.1.0` on npm with the tag `sdk-ts-v0.1.0` (on `edf81ae`). Later versions are published by `.github/workflows/publish-sdk-ts.yml` on `sdk-ts-vX.Y.Z` tags, per [docs/sdk/releasing-npm.md](../sdk/releasing-npm.md).
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
   - Standard work uses `<type>/<issue-number>-<short-slug>` with one of:
     `feat` · `fix` · `docs` · `chore` · `ci` · `test` · `spike`
   - Work the Issue gate accepts without an issue (docs-only changes, or a PR labelled `no-issue`): `<type>/<short-slug>`.
   - Patching an already-published SDK release when `main` has unreleased breaking changes: `hotfix/<package>-<issue-number>-<short-slug>` branched from `<package>-v<X.Y.Z>` and cherry-picked back to `main`.
   - Long-lived spike sandboxes that an open issue asks for: `sandbox/<short-slug>` (today `sandbox/nirium` for #296). The issue names the branch, and the branch is deleted when the issue closes.
   - Bot branches (`dependabot/*`) keep the bot's own naming.
3. **No review or scratch branches on `origin`:**
   - Local PR reviews and agent checks run in detached worktrees (`git worktree add --detach`) rather than pushing `review-pr-*` or `local/*` branches.
   - GitHub's *Automatically delete head branches* setting is enabled and deletes the branch of a merged PR. The author deletes the branch of a PR closed without merging.
4. **Conventional Commits in PR titles:**
   - **Squash merge is the only merge method.** Merge commits and rebase merging are disabled in the repository settings (see *Consequences and rollout*). Every PR title must follow `<type>(<scope>): <summary> (#<issue>)` (or `<type>: <summary> (#<issue>)`), so `main` history remains machine-readable for changelogs and version bumps. GitHub appends the PR number on squash, so the commit on `main` reads `<type>(<scope>): <summary> (#<issue>) (#<pr>)`, as it already does today.
   - Commit types are the branch types above plus `build`, `refactor`, `perf` and `revert` when they apply.
5. **Tags are for releases only.** Every tag follows the formats in section 3. Ad-hoc tags such as `backup/feat-19-pre-rework` do not belong on `origin`.

### 2. Stacked PR protocol

Prefer independent PRs against `main` (using feature flags or config toggles when incomplete). When a dependency stack (`A -> main`, `B -> A`) is unavoidable:

1. Limit stacks to at most **4 open PRs**. Work that needs more is grouped into fewer, larger slices.
2. Intermediate PRs use `Refs #<issue>` (never `Closes #<issue>`), per `Issue gate`.
3. **Required merge sequence:**
   - Merge `A`. When GitHub deletes `A`'s branch after the merge, it retargets `B` to `main` on its own. Never delete `A`'s branch by hand while `A` is unmerged: that closes `B`.
   - Before `A`'s branch is deleted, record its tip (`git rev-parse A`, or use `A@{upstream}` while it still exists). After the squash merge, replay only `B`'s own commits onto `main` with `git rebase --onto main <A's old tip> B`. A plain merge or rebase would replay `A`'s original commits against their squashed copy and usually conflicts.
   - Force-push `B` with `git push --force-with-lease`.
   - Request final review on `B` **after** that push so `require_last_push_approval` is not invalidated.

### 3. Artifact versioning: Independent versioning by artifact family

A single global repository version does not fit contracts, SDKs, and continuously deployed apps that evolve at different speeds. Each artifact family follows its own industry standard:

| Artifact family | Versioning scheme | Git tag / identifier | Metadata & provenance |
| --- | --- | --- | --- |
| **Publishable SDKs** (`puls3_client`, `puls3_sdk`, `@puls3_org/sdk`) | **SemVer 2.0.0** (`0.x` until 1.0 stability) + `CHANGELOG.md` with one section per release | `<package>-v<X.Y.Z>` (e.g. `puls3_sdk-v0.1.0`) on the commit it was published from. A GitHub Release is optional (none exists yet). Exception: `@puls3_org/sdk` uses the tag prefix `sdk-ts` (`sdk-ts-v<X.Y.Z>`), because a scoped name with `/` cannot be a clean tag. | Released per [docs/sdk/releasing.md](../sdk/releasing.md) (Dart: manual `dart pub publish`, no publishing from CI) and [docs/sdk/releasing-npm.md](../sdk/releasing-npm.md) (npm: version bump in a PR, then a tag the workflow publishes with provenance). Any contract redeploy changing pinned `contract_id`s requires a new SDK release (ADR-0010). |
| **Continuously deployed apps** (`puls3_server`, `puls3_flutter`) | **CalVer** `YYYY.M.D+<short_sha>` (no leading zeros, so it stays valid SemVer, e.g. `2026.11.5+3d8b852`) *(or SemVer `X.Y.Z+<short_sha>` — confirm in team review)*. The short SHA is build metadata in the version string; `github.run_number` is the `--build-number`, because Flutter needs an integer (Android `versionCode`). | No tag per commit (optional milestone tags) | `puls3_server` reports via `/health/check` (`PULS3_GIT_SHA`); `puls3_server/Dockerfile` sets `LABEL org.opencontainers.image.*`; `scripts/cloudflare-pages-build.sh` passes `--build-name` and `--build-number`. |
| **Soroban contracts** (`escrow`, `identity-registry`, `reputation-registry`) | **SemVer** in `Cargo.toml` + `pub fn version()` | `contracts/<name>-v<X.Y.Z>-<network>` on deploy (new; no contract tag exists yet). A version without an upgrade function is a new contract id ([docs/operations/escrow-rotation.md](../operations/escrow-rotation.md)), so each deploy gets its own tag. | Release builds pass `--meta source_repo=github:Zer0-Knowledge-Hack/puls3` and `--meta revision=<sha>` (**SEP-55**). `contracts/deployments/<network>.json` keeps its snake_case keys (`contract_id`, `wasm_hash_sha256`, `deploy_tx`, `deployed_at_utc`) and adds `crate_version` and `git_commit`. |
| **Internal / CLI packages** (`puls3_domain`, `puls3_cli`, `puls3_mcp`) | `publish_to: none` internally; **SemVer** if distributed as binaries | `<bin>-v<X.Y.Z>` (only if published) | If `puls3_cli` or `puls3_mcp` ship standalone binaries on GitHub Releases, use `<bin>-v<X.Y.Z>-<os>-<arch>` + `SHA256SUMS`. |
| **Domain & DB artifacts** (`puls3.agent-manifest/v1`, `skill_packs`, migrations) | Schema `puls3.<type>/v<N>` + monotonic integer + SHA-256 / Serverpod timestamp | Persisted on-chain / in DB | Unchanged; follows ADR-0004, ADR-0014, and `puls3_server/migrations/migration_registry.txt`. |

#### SDK tags and release process

- **Tag format:** `<package>-v<X.Y.Z>` stays the rule. The npm package `@puls3_org/sdk` uses `sdk-ts` as its tag prefix (`sdk-ts-v<X.Y.Z>`), which matches the trigger of `.github/workflows/publish-sdk-ts.yml` (`sdk-ts-v[0-9]+.[0-9]+.[0-9]+`) and the protected `npm` environment, which only allows `sdk-ts-v*` tags.
- **Release process:** this ADR adopts the processes already in place as the current release process: [docs/sdk/releasing.md](../sdk/releasing.md) for the Dart packages and [docs/sdk/releasing-npm.md](../sdk/releasing-npm.md) for the npm package. Melos `command.version` (Dart) and Changesets (TS) are an optional future improvement, not a requirement of this ADR.

## Open decisions for team review

Before moving this ADR to `Accepted`, the team should confirm two points on #425:

1. **App versioning (`puls3_server` and `puls3_flutter`):** adopt **CalVer** (`YYYY.M.D+<short_sha>`, e.g. `2026.11.5+3d8b852`, with `github.run_number` as the `--build-number`) for continuous deploys, or keep **SemVer** (`1.x.y+<short_sha>`) bumped per milestone/release?
2. **CLI / MCP binary distribution:** keep `puls3_cli` and `puls3_mcp` source-only inside the workspace, or publish prebuilt release archives?

## Consequences and rollout

The pull request that proposes this ADR also carries the #425 documentation, so accepting it leaves nothing to write afterwards:

- **Docs (in this PR):** [CONTRIBUTING.md](../../CONTRIBUTING.md) sections `3.2 Branches`, `3.3 Commits` and `3.4 Pull requests` list the branch types, the detached-worktree review rule, the PR title rule and the stacked PR merge order. [docs/sdk/releasing.md](../sdk/releasing.md) and [docs/sdk/releasing-npm.md](../sdk/releasing-npm.md) link to this policy.
- **Repository settings (done 2026-11-25):** *Automatically delete head branches* is enabled, `origin` was pruned to `main`, the branches of open PRs and `sandbox/nirium`, and the ad-hoc tag `backup/feat-19-pre-rework` was removed. Only release tags remain.
- **Repository settings (on acceptance, by an admin):**
  - add a tag ruleset that only lets maintainers create, move or delete release tags (patterns `*-v*` for `<package>-v<X.Y.Z>` and `sdk-ts-v<X.Y.Z>`, and `contracts/*-v*` for `contracts/<name>-v<X.Y.Z>-<network>`, since `*` does not match `/`). [docs/sdk/releasing-npm.md](../sdk/releasing-npm.md) already asks for one for `sdk-ts-v*`, and no ruleset exists yet;
  - make `Issue gate / issue-gate` a required check on `main`. CONTRIBUTING lists it as required, but today `main` only requires `gate` and `scan`;
  - disable merge commits and rebase merging, so squash merge is the only method.
- **On acceptance:** record the two open decisions in section 3 and in *Open decisions*, set the status to `Accepted`, and switch the PR to `Closes #425`.
- **Tooling (follow-up issues):**
  - **#431, app/server version stamping:** OCI labels (`org.opencontainers.image.*`) in `puls3_server/Dockerfile`, a real `puls3_server/CHANGELOG.md` in place of the Stagehand template, and Flutter web `--build-name` / `--build-number` in `scripts/cloudflare-pages-build.sh`. Melos `command.version` is optional (see *SDK tags and release process*).
  - **#432, Soroban provenance:** SEP-55 `--meta source_repo=github:Zer0-Knowledge-Hack/puls3 --meta revision=<sha>` on release builds, `crate_version` / `git_commit` in `contracts/deployments/*.json`, and the release steps in `contracts/README.md`. It also backfills the contracts already on testnet: their `crate_version`, `git_commit` and `contracts/<name>-v<X.Y.Z>-testnet` tag.
