# MVP screen specs

- **Issue:** #23 · **Date:** 2026-10-09
- **Sources:** [MVP user flows](flows.md) (#22, screen IDs and error paths), [domain model](../domain/model.md) (#9, field names), [API contract](../architecture/api.md) (#8)

What each screen shows and how it behaves in every state, so "done" is not a matter of opinion. Each section gives the purpose, the flows it belongs to, the data shown (named exactly as in the domain model), the four states, the actions and where they lead, and the components it uses. The [component inventory](#component-inventory) maps every reusable widget to its screens.

**Wireframes.** Every screen has a desktop (1440 px) and a mobile (390 px) wireframe in [`wireframes/`](wireframes/), named `<screen-id>-<width>.png`. S02 and S03 also have one per state (`-loading`, `-empty`, `-error`), and S06 has its failed-run and deadline-passed states. They are low to mid fidelity: the layout, components and labels are the app's, set in Roboto rather than the final brand fonts, and colors are only indicative (final visuals are #24). Screens that exist render from the app; S05, S06 and S10 are not built yet and are drawn from the same components after flows F6 and F7. To regenerate them after a UI change:

```
cd puls3_flutter
flutter test tool/wireframes/wireframes_test.dart --update-goldens
```

**Figma:** _link to be added by the frontend owner_ (the PNGs above are the source of truth until then).

**Reading the field names.** `Agent.price` is a `UsdcAmount`, shown in USDC with two decimals; addresses (`Agent.wallet`, `Payment.payer`) are shown shortened (`GABC…WXYZ`) with the full value on copy. Two values the app shows are not domain fields: the agent's model (`ModelId`, from its manifest) and its rating (average `Feedback.score`, served once #21 lands; hidden while there is none).

## Screens

| ID | Route / kind | Flows | Built | Wireframes |
|---|---|---|---|---|
| [`S01-landing`](#s01-landing) | `/` | F2 | Yes | [1440](wireframes/S01-landing-1440.png) · [390](wireframes/S01-landing-390.png) |
| [`S02-marketplace`](#s02-marketplace) | `/market` | F2, F3 | Yes | [1440](wireframes/S02-marketplace-1440.png) · [390](wireframes/S02-marketplace-390.png) |
| [`S03-agent-detail`](#s03-agent-detail) | `/agent/:id` | F3, F4, F5, F7 | Yes | [1440](wireframes/S03-agent-detail-1440.png) · [390](wireframes/S03-agent-detail-390.png) |
| [`S04-hire-sheet`](#s04-hire-sheet) | Bottom sheet over S03 | F5, F6 | Yes | [1440](wireframes/S04-hire-sheet-1440.png) · [390](wireframes/S04-hire-sheet-390.png) |
| [`S05-my-hires`](#s05-my-hires) | `/hires` | F6 | No | [1440](wireframes/S05-my-hires-1440.png) · [390](wireframes/S05-my-hires-390.png) |
| [`S06-hire-detail`](#s06-hire-detail) | `/hires/:id` | F6, F7 | Partly (read-only) | [1440](wireframes/S06-hire-detail-1440.png) · [390](wireframes/S06-hire-detail-390.png) |
| [`S07-studio`](#s07-studio) | `/studio` | F4, F8, F9, F10 | Yes | [1440](wireframes/S07-studio-1440.png) · [390](wireframes/S07-studio-390.png) |
| [`S08-deploy-sheet`](#s08-deploy-sheet) | Bottom sheet over S07 | F4, F10, F11 | Yes | [1440](wireframes/S08-deploy-sheet-1440.png) · [390](wireframes/S08-deploy-sheet-390.png) |
| [`S09-wallet-connect`](#s09-wallet-connect) | Sheet over any screen | F1 | Yes | [1440](wireframes/S09-wallet-connect-1440.png) · [390](wireframes/S09-wallet-connect-390.png) |
| [`S10-rate-sheet`](#s10-rate-sheet) | Bottom sheet over S06 | F7 | No | [1440](wireframes/S10-rate-sheet-1440.png) · [390](wireframes/S10-rate-sheet-390.png) |
| [`S11-playground`](#s11-playground) | Panel beside the S07 preview (desktop), sheet over S07 (phone) | F9 | No | [1440](wireframes/S11-playground-1440.png) · [390](wireframes/S11-playground-390.png) |
| [`S12-my-agents`](#s12-my-agents) | `/studio/agents` | F10, F11 | No | [1440](wireframes/S12-my-agents-1440.png) · [390](wireframes/S12-my-agents-390.png) |

Every screen sits in the app shell: the top bar (logo, wallet chip) and, on phones, the bottom navigation (Studio, Marketplace). Sheets open above the whole app.

---

### S01-landing

**Purpose:** introduce puls3 and lead to the Marketplace or the Studio. **Flows:** F2 (entry).

**Data:** two featured agents: `Agent.name`, `Agent.wallet`, `Agent.price`.

| State | What the user sees |
|---|---|
| Loading | The hero and features render at once; the featured cards wait for the catalog. |
| Empty | No agents: the featured row is hidden; the hero stays. |
| Error | The catalog failed: the featured row is hidden; the Marketplace shows the error (S02). |
| Success | Hero, two featured agents, feature points, footer. |

**Actions:** **Explore Marketplace** → S02. **Open Studio** → S07. A featured agent → S03.

**Components:** `PulseBackground`, `Puls3Logo`, `SectionLabel`, `PrimaryButton`, `AgentMiniCard`, `FeaturePoint`, `BuiltOnStellar`, `SiteFooter`.

### S02-marketplace

**Purpose:** find an agent by text or skill. **Flows:** F2, then F3.

**Data per agent:** `Agent.name`, `Agent.description`, the first `Skill.name` of `Agent.skills`, `Agent.price`, the model, and the rating when there is one. Header: the number of agents listed.

| State | What the user sees | Wireframe |
|---|---|---|
| Loading | Six card skeletons in the grid. | [1440](wireframes/S02-marketplace-loading-1440.png) · [390](wireframes/S02-marketplace-loading-390.png) |
| Empty | No agents registered: "No agents yet" with **Create an agent** (→ S07). A search or skill filter with no match: "No matching agents" with **Clear filters**. | [1440](wireframes/S02-marketplace-empty-1440.png) · [390](wireframes/S02-marketplace-empty-390.png) |
| Error | Banner "Could not load the agents" with **Retry**; the user stays on S02. When the bundled demo catalog is shown instead, it is labelled "DEMO CATALOG" with a banner and **Retry**. | [1440](wireframes/S02-marketplace-error-1440.png) · [390](wireframes/S02-marketplace-error-390.png) |
| Success | Search box, skill chips (an agent must have every selected skill), "Showing N of M", the agent grid (3, 2 or 1 columns). | [1440](wireframes/S02-marketplace-1440.png) · [390](wireframes/S02-marketplace-390.png) |

**Actions:** type to search (name, description, model, skills). Tap skill chips to filter; **All** clears them. Tap a card → S03.

**Components:** `ContentWidth`, `SkillChip`, `AgentGrid`, `AgentCard`, `AgentGridSkeleton`, `AgentCardSkeleton`, `EmptyState`, `ErrorBanner`, `SiteFooter`.

### S03-agent-detail

**Purpose:** decide whether to hire an agent. **Flows:** F3, then F5; F4 and F7 return here.

**Data:** `Agent.name`, `Agent.description`, `Agent.skills` (`Skill.name`), `Agent.price`, the model, the rating, and the on-chain identity: `Agent.id` (the registry id) and `Agent.wallet`, with **View on explorer** for the Identity Registry. `Agent.owner` is listed once the catalog serves it.

| State | What the user sees | Wireframe |
|---|---|---|
| Loading | A skeleton of the profile and the price card. A cached copy from S02 shows at once, with **Hire** disabled until the agent is confirmed. | [1440](wireframes/S03-agent-detail-loading-1440.png) · [390](wireframes/S03-agent-detail-loading-390.png) |
| Empty | Unknown id: "Agent not found" with **Back to Marketplace**. | [1440](wireframes/S03-agent-detail-empty-1440.png) · [390](wireframes/S03-agent-detail-empty-390.png) |
| Error | Nothing cached: "Could not load this agent" with **Retry**. Cached copy: "Showing the last known data" with **Retry**, and **Hire** disabled until it loads. | [1440](wireframes/S03-agent-detail-error-1440.png) · [390](wireframes/S03-agent-detail-error-390.png) |
| Success | Profile, about, skills, on-chain identity, and the price card with **Hire**. Two columns on desktop, one on phones. | [1440](wireframes/S03-agent-detail-1440.png) · [390](wireframes/S03-agent-detail-390.png) |

**Actions:** **Hire** → S04. **View on explorer** → stellar.expert (new tab). **Marketplace** → S02. An agent that does not accept hires (`active: false`, ADR-0004) hides **Hire** and says "Not accepting hires".

**Components:** `AgentDetailView`, `AgentDetailSkeleton`, `AgentAvatar`, `RatingBadge`, `SectionLabel`, `SkillChip`, `KeyValueRow`, `AddressBadge`, `PriceTag`, `PrimaryButton`, `EmptyState`, `ErrorBanner`, `SiteFooter`.

### S04-hire-sheet

**Purpose:** describe the task and pay into escrow. **Flows:** F5, then F6.

**Data:** the agent's `Agent.name`, `Agent.price` and `Agent.wallet` (destination), the escrow contract, the network fee, the task text (`createHire` input), and once paid: `Hire.id` and `Payment.transaction`.

| State | What the user sees |
|---|---|
| Loading | **Confirm & sign** shows "Signing…" and the current step: creating the hire, "Sign the escrow job (1 of 2)", "Sign the payment (2 of 2)", sending to the escrow. |
| Empty | No task typed: **Confirm & sign** is disabled. |
| Error | "Payment failed" with the reason (wallet rejected, not signed in, preparation expired, missing USDC, server unavailable) and **Try again**, which resumes from the failed step without creating a second hire. |
| Success | "Payment sent to the escrow" with `Hire.id`, the transaction and **View on StellarExpert**. A demo backend says "Demo signature only" and links nothing. |

**Actions:** **Confirm & sign** → wallet prompts (S09 first if no wallet). **View hire** → S06. **Back to Marketplace** → S02.

**Components:** `HirePaymentView`, `KeyValueRow`, `PriceTag`, `AddressBadge`, `PrimaryButton`.

### S05-my-hires

**Purpose:** see every hire of the connected wallet. **Flows:** F6 (step 6). **Not built yet.**

**Data per hire:** the agent's `Agent.name`, `Hire.status` (`open`, `funded`, `submitted`, `completed`, `rejected`, `expired`; a reject from `open` reads **Cancelled**), `Hire.runtimeStatus` (`queued`, `running`, `failed`), `Hire.price`. Newest first.

| State | What the user sees |
|---|---|
| Loading | Row skeletons. |
| Empty | "No hires yet" with **Explore agents** (→ S02). No wallet connected: S09 first (hires belong to `Hire.consumer`). |
| Error | Banner with **Retry**; the list stays if one was loaded. |
| Success | One row per hire with status and run progress. |

**Actions:** a row → S06.

**Components:** `ScreenHeader`, `SkillChip` (status), `PriceTag`, `EmptyState`, `ErrorBanner`.

### S06-hire-detail

**Purpose:** follow a hire, read the result and decide. **Flows:** F6, F7. **Partly built** (`hire_detail_screen.dart`, #28): status, run progress, result with **Copy** and the `fund` link, polled until final. **Approve** and **Reject and refund** wait for the server-signed `submit` (#97); **Rate** waits for #14 and #21.

**Data:** `Hire.id`, the agent's `Agent.name`, `Hire.status`, `Hire.runtimeStatus`, `Hire.failureReason`, `Hire.price` (held in escrow), the result, the approval deadline, `Payment.transaction` (the `fund` link), and the refund transaction after a reject or expiry. A rated hire shows `Feedback.score`.

| State | What the user sees |
|---|---|
| Loading | A skeleton; while the agent works (`funded`, `queued` or `running`) the steps update by polling `getHire`. |
| Empty | Unknown or someone else's hire: "Hire not found" with **My hires** (→ S05). |
| Error | Banner with **Retry**. A failed run (`runtimeStatus: failed`) shows `Hire.failureReason` and **Reject and refund**: [1440](wireframes/S06-hire-detail-run-failed-1440.png) · [390](wireframes/S06-hire-detail-run-failed-390.png). |
| Success | Steps (funded, ran, submitted, completed), the result (scrollable, with **Copy**), the deadline, **Approve** and **Reject and refund**. After the approval deadline, **Reject** is hidden and the hire is **Completed** by `release`, with **Rate** if not rated: [1440](wireframes/S06-hire-detail-deadline-passed-1440.png) · [390](wireframes/S06-hire-detail-deadline-passed-390.png). |

**Actions:** **Approve** → wallet signs `complete` → **Completed**. **Reject and refund** (optional reason) → wallet signs `reject` → **Rejected**; hidden after the deadline. **Rate** → S10.

**Components:** `ScreenHeader`, `ProgressStepRow`, `SectionLabel`, `KeyValueRow`, `AddressBadge`, `PrimaryButton`, `ErrorBanner`.

### S07-studio

**Purpose:** build an agent, save it as a draft and deploy it. **Flows:** F4, F8, F9, F10.

**Data:** the manifest draft, named as `AgentManifestDraft`: `name`, `description`, `skills` (`Skill.name`, kebab-case `Skill.id`), `model` (`ModelId.provider`, `ModelId.id`), `systemPrompt`, `inputType` and `inputMaxChars`, `outputType` and `outputMaxChars`, `price`. The preview is the Marketplace card.

| State | What the user sees | Wireframe |
|---|---|---|
| Loading | The form renders at once (drafts from the server, #35, will show a skeleton). | [1440](wireframes/S07-studio-loading-1440.png) · [390](wireframes/S07-studio-loading-390.png) |
| Empty | A blank form; **Deploy** disabled; "N fields to complete". | [1440](wireframes/S07-studio-empty-1440.png) · [390](wireframes/S07-studio-empty-390.png) |
| Error | The domain's problems (`ManifestProblem`) under each edited field; **What is missing?** shows the rest; **Deploy** stays disabled. | [1440](wireframes/S07-studio-error-1440.png) · [390](wireframes/S07-studio-error-390.png) |
| Success | "Ready to deploy" and **Deploy to Stellar** enabled. | [1440](wireframes/S07-studio-1440.png) · [390](wireframes/S07-studio-390.png) |

**Actions:** **Deploy to Stellar** → S08 (S09 first if no wallet). **Save draft** (F8). **Test run** → S11 (F9). **My agents** → S12 (F11). When editing a live agent, a banner says the edit becomes version *n+1* (F10).

**Components:** `AgentForm`, `AgentCard` (preview), `SectionLabel`, `SkillChip`, `PrimaryButton`, `SiteFooter`.

### S08-deploy-sheet

**Purpose:** register the agent on Stellar step by step, or deploy a new version of it. **Flows:** F4 (steps 4 to 8), F10 (steps 4 to 6), F11 (resume).

**Data:** the steps (preparing, waiting for signature, registering on-chain, activating, live), the agent's `Agent.id`, the registration transaction and `Agent.wallet` once live.

| State | What the user sees | Wireframe |
|---|---|---|
| Loading | The stepper with the active step and its explanation; the sheet can be closed while the wallet prompt is open. | [1440](wireframes/S08-deploy-sheet-1440.png) · [390](wireframes/S08-deploy-sheet-390.png) |
| Empty | Not applicable: the sheet opens only with a valid manifest. | — |
| Error | The failed step with the reason and a recovery action: **Try again** from that step, **Prepare again** after an expiry, **Use current account** after an account switch. | [1440](wireframes/S08-deploy-sheet-error-1440.png) · [390](wireframes/S08-deploy-sheet-error-390.png) |
| Success | "Agent deployed" with `Agent.id`, the transaction and **View on explorer**, **Open agent** (→ S03). A demo backend says "Demo deploy only" and links nothing. | [1440](wireframes/S08-deploy-sheet-success-1440.png) · [390](wireframes/S08-deploy-sheet-success-390.png) |

**Actions:** **Open agent** → S03. **Back to Studio** → S07.

**Components:** `DeployFlowView`, `DeployStepper`, `ProgressStepRow`, `DeployPhaseCard`, `DeployErrorPanel`, `DeploySuccess`, `CopyableValueRow`, `PrimaryButton`.

### S11-playground

**Purpose:** run a saved draft once on a sample input, without payment or chain writes. **Flows:** F9.

**Data:** the draft's `StudioDraft.draftId`, `inputType` and `inputMaxChars`, `outputType`; after a run, `TestRunResult.output` and `TestRunResult.remainingDailyRuns`.

| State | What the user sees | Wireframe |
|---|---|---|
| Loading | **Running…** with the input locked, and a note that the run stops at the runtime timeout. | [1440](wireframes/S11-playground-loading-1440.png) · [390](wireframes/S11-playground-loading-390.png) |
| Empty | The input box with its counter (`0 / inputMaxChars`), **Run** disabled until there is text, and "Test runs are free and limited per day". | [1440](wireframes/S11-playground-empty-1440.png) · [390](wireframes/S11-playground-empty-390.png) |
| Error | `TestQuotaExceeded`: "You used today's test runs" and when they reset, **Run** disabled. `AgentExecutionFailed` / `RuntimeUnavailable`: the safe reason in an `ErrorBanner` with **Try again**. Over `inputMaxChars`: inline error under the input. | [1440](wireframes/S11-playground-error-1440.png) · [390](wireframes/S11-playground-error-390.png) |
| Success | The output (text, or Markdown when `outputType` is `markdown`), labelled "Test run: not paid, nothing on chain", with **Copy** and "N runs left today". | [1440](wireframes/S11-playground-1440.png) · [390](wireframes/S11-playground-390.png) |

**Actions:** **Run** → `testRun`. **Try again**. **Copy** output. **Close** (phone) → S07. **Deploy** → S08 (F4).

**Components:** `PlaygroundPanel`, `TestRunResultCard`, `ErrorBanner`, `SectionLabel`, `PrimaryButton`.

### S12-my-agents

**Purpose:** the builder's drafts and deployed agents, to continue, resume or edit them. **Flows:** F10, F11.

**Data:** for each row, `StudioDraft.draftId`, `manifest.name`, `manifest.price`, `StudioDraft.deployState`, the live `ManifestVersion` and `Agent.id` once deployed, and the deploy step from `DeploySession.state` / `retryFromStep` when a deploy is in progress or failed.

| State | What the user sees | Wireframe |
|---|---|---|
| Loading | Skeleton rows (`SkeletonBox`) under the **Drafts** and **Live** headers. | [1440](wireframes/S12-my-agents-loading-1440.png) · [390](wireframes/S12-my-agents-loading-390.png) |
| Empty | `EmptyState`: "No agents yet" and **Create your first agent** (→ S07). | [1440](wireframes/S12-my-agents-empty-1440.png) · [390](wireframes/S12-my-agents-empty-390.png) |
| Error | `ErrorBanner`: "Could not load your agents" and **Retry**. | [1440](wireframes/S12-my-agents-error-1440.png) · [390](wireframes/S12-my-agents-error-390.png) |
| Success | Rows grouped as **Drafts**, **Deploying or failed** and **Live**. Each `AgentVersionRow` shows the name, a state label, the version (live rows) and the price, with its action. | [1440](wireframes/S12-my-agents-1440.png) · [390](wireframes/S12-my-agents-390.png) |

**Actions:** **Continue editing** → S07 (F8). **Resume deploy** → S08 at its step. **View** → S03. **Edit** → S07 as version *n+1* (F10). **New agent** → S07.

**Components:** `MyAgentsList`, `AgentVersionRow`, `ScreenHeader`, `PriceTag`, `EmptyState`, `ErrorBanner`, `SkeletonBox`, `PrimaryButton`.

### S09-wallet-connect

**Purpose:** connect the user's Stellar wallet. **Flows:** F1, before F4, F5, F6 and F7.

**Data:** the connected address (`StellarAddress`, shortened), the network (Testnet), the wallet name.

| State | What the user sees |
|---|---|
| Loading | "Waiting for Freighter…" with a progress bar; "Waiting for wallet confirmation…" while signing. |
| Empty | Disconnected: "Connect a wallet" and **Connect Freighter**. |
| Error | Each with **Try again**: connection cancelled, signature rejected, wrong network ("Switch Freighter to Stellar Testnet"), not installed (with **Install Freighter**), locked, account changed, no answer. |
| Success | "Connected", the address with copy, the Testnet badge, **Disconnect**; "Transaction signed" after a signature. |

**Actions:** **Connect** → wallet popup. **Disconnect** → disconnected. Closing resumes the action that asked for the wallet.

**Components:** `WalletPanel`, `WalletChip` (top bar), `CopyableValueRow`, `PrimaryButton`.

### S10-rate-sheet

**Purpose:** rate a completed hire. **Flows:** F7. **Not built yet.**

**Data:** the agent's `Agent.name`, `Feedback.score` (1 to 5), `Feedback.comment` (optional, up to 500 characters).

| State | What the user sees |
|---|---|
| Loading | **Send rating** shows progress while the wallet signs and the feedback confirms. |
| Empty | No score picked: **Send rating** disabled. |
| Error | Comment too long: inline error. Rejected in the wallet: "Rating not sent", stay. Another wallet connected: "Rate with the wallet that hired". Already rated: "You already rated this hire" (→ S06). |
| Success | "Rating saved"; S06 shows the score. |

**Actions:** **Send rating** → wallet signs `give_feedback` → S06.

**Components:** `PrimaryButton`, star picker (new), text field.

---

## Component inventory

Atomic design, as in `puls3_flutter/lib/src/ui/`. Presentational widgets get their data through constructors; only screens (containers) read app state or call the server.

### Atoms

| Component | Used by | Screens |
|---|---|---|
| `AddressBadge` | `AgentDetailView`, `HirePaymentView` | S03, S04, S06 |
| `AgentAvatar` | `AgentCard`, `AgentDetailView` | S02, S03, S07 |
| `ContentWidth` | every page | S01, S02, S03, S07 |
| `PriceTag` | `AgentCard`, `AgentDetailView`, `AgentMiniCard`, `HirePaymentView` | S01, S02, S03, S04, S05, S07 |
| `PrimaryButton` | screens, `AgentDetailView`, `EmptyState`, `HirePaymentView`, `WalletPanel`, deploy panels | S01, S03, S04, S06, S07, S08, S09, S10 |
| `Puls3Logo` | `TopBar`, `SiteFooter`, landing | all |
| `PulseBackground` | landing | S01 |
| `RatingBadge` | `AgentCard`, `AgentDetailView` | S02, S03 |
| `SectionLabel` | `AgentDetailView`, `AgentForm`, landing, Studio | S01, S03, S06, S07 |
| `SkeletonBox` | `AgentCardSkeleton`, `AgentDetailSkeleton`, `CopyableValueRow`, `MyAgentsList` | S02, S03, S08, S12 |
| `SkillChip` | `AgentCard`, `AgentDetailView`, `AgentForm`, Marketplace | S02, S03, S05, S07 |

### Molecules

| Component | Used by | Screens |
|---|---|---|
| `AgentCard` | `AgentGrid`, Studio preview | S02, S07 |
| `AgentCardSkeleton` | `AgentGridSkeleton` | S02 |
| `AgentMiniCard` | landing | S01 |
| `BuiltOnStellar` | landing, `SiteFooter` | S01 and every page footer |
| `CopyableValueRow` | `WalletPanel`, deploy panels | S08, S09 |
| `EmptyState` | Marketplace, agent detail, `MyAgentsList` | S02, S03, S05, S12 |
| `ErrorBanner` | Marketplace, agent detail, `PlaygroundPanel`, `MyAgentsList` | S02, S03, S05, S06, S11, S12 |
| `FeaturePoint` | landing | S01 |
| `KeyValueRow` | `AgentDetailView`, `HirePaymentView` | S03, S04, S06 |
| `ProgressStepRow` | `DeployStepper` | S06, S08 |
| `ScreenHeader` | planned pages | S05, S06, S12 |
| `AgentVersionRow` *(new)* | `MyAgentsList` | S12 |
| `TestRunResultCard` *(new)* | `PlaygroundPanel` | S11 |
| `WalletChip` | `TopBar` | all |

### Organisms

| Component | Screens |
|---|---|
| `AgentDetailView`, `AgentDetailSkeleton` | S03 |
| `AgentForm` | S07 |
| `AgentGrid`, `AgentGridSkeleton` | S02 |
| `HirePaymentView` | S04 |
| `SiteFooter` | S01, S02, S03, S07 |
| `TopBar` | all (app shell) |
| `WalletPanel` | S09 |
| `DeployFlowView`, `DeployStepper`, `DeployPhaseCard`, `DeployErrorPanel`, `DeploySuccess` | S08 |
| `PlaygroundPanel` *(new)* | S11 |
| `MyAgentsList` *(new)* | S12 |
