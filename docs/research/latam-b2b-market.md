# MVP: puls3 — AI Agent Hub on Stellar for Latin America

**Problem audit, product architecture, and source rigor**

Market Intelligence Consulting
**Author:** Anahi Rocio Llanos Tarqui
**Date:** September 24, 2026

---

## PHASE 1: B2B Problem Audit

### 1. It is specific

The problem is not "Latin American companies need AI." The exact niche is:

Operations and Finance departments at fintechs and digital services companies in Brazil, Mexico, and Colombia (with 50 to 500 employees) that need to automate high-volume operational tasks —cross-border payment reconciliation, on-chain vault analysis, invoice parsing, and liquidity monitoring— but face three simultaneous barriers:

- **(a)** they cannot pay for AI micro-services without opening accounts or subscriptions with each provider;
- **(b)** they have no verifiable traceability of the work performed by AI agents; and
- **(c)** their traditional payment flows (bank transfers, Stripe, SaaS subscriptions) are too slow and costly to settle per-task payments in USDC.

### 2. It hurts someone

The decision-maker is the Head of Operations or CFO of a fintech in Mexico City or São Paulo. Their operational pain is concrete: every month, their team spends between 40 and 80 person-hours manually reconciling payments that pass through multiple digital service providers (*internal estimate based on a mid-size Brazilian company processing 500 Boletos per month, which requires roughly one full-time equivalent for reconciliation*) (ImageToTable, 2026). They cannot demonstrate to audit or compliance that the tasks executed by AI were performed correctly, because the agents operate as black boxes with no verifiable record. Their emotional pain is loss of control: they feel that AI is a promise they can neither audit nor integrate into their financial workflows without exposing themselves to regulatory risk.

### 3. It happens often

This is not an isolated case. 72% of Latin American companies are in the early stages of AI adoption, and 47% of large companies already run solutions in production (IBM, 2026, as cited in Imagen Radio, 2026). Payment friction is an everyday reality: in Brazil, the 3.5% IOF tax on stablecoins (effective October 2026) makes every micropayment more expensive (KuCoin, 2026), and companies lack a programmable settlement infrastructure suited to the fractional nature of AI tasks. The LATAM AI agent market will grow from USD 401.2 million in 2025 to USD 3,990 million in 2030 (CAGR 38.8%) (MarketsandMarkets, 2026), which implies that thousands of companies will be hiring agents on a recurring basis over the next 24 months. Payment friction is not an "early adopter" problem; it is a structural barrier that will intensify as the market grows.

### 4. It costs money or time today

The real cost is quantifiable across three dimensions:

- **Person-hours:** An operations team of 5 people spending 30 hours per week on manual payment reconciliation and AI task verification represents approximately USD 3,500–5,000 per month in labor cost (at USD 15–20/hour in LATAM) (*internal estimate based on regional salary data*). This is a direct cost that companies are already paying.
- **Bank and processor fees:** Traditional international transfers (SWIFT) cost between USD 25 and 50 per transaction, with settlement times of 2 to 5 business days (Arp Digital, 2026; Routefusion, 2026). SaaS subscriptions (Stripe, AWS Marketplace) charge fees of 2.9% + USD 0.30 per transaction (Stripe, 2026; Vendr, 2026), which is prohibitive for per-task micropayments of USD 0.10 to USD 0.50.
- **Opportunity cost:** Every day a company cannot integrate AI agents into its operational workflows is a day it loses competitiveness against competitors that can. Gartner estimates that 40% of enterprise applications will incorporate intelligent agents by the end of 2026 (Gartner, 2025). Being left out of that wave carries a strategic cost that does not appear on the P&L, but is real.

### 5. Stellar solves it better

Stellar offers a combination that no traditional or Web2 infrastructure can replicate:

- **Settlement in ~5 seconds** versus 2–5 business days for SWIFT or 1–3 days for Stripe (Stellar Development Foundation, 2026a).
- **Transaction cost of 100 stroops (0.00001 XLM)**, which makes per-task micropayments of USD 0.10–0.50 viable (Stellar Development Foundation, 2026a). Neither Stripe nor AWS Marketplace can offer this.
- **Native USDC on Stellar**, with real fiat ramps: MoneyGram (~500,000 cash points) (Gate News, 2026), Mercado Bitcoin, and Bitso operate on Stellar in LATAM.
- **Soroban for on-chain escrow and reputation:** payment is verified on-chain before the agent executes the task, eliminating counterparty risk. The agent's identity and reputation are portable and auditable.
- **MPP (Machine Payments Protocol) and x402:** Stellar has implemented first-class protocols for agentic payments (Stellar Development Foundation, 2026a; Stellar Development Foundation, 2026b). x402 turns the HTTP 402 "Payment Required" status code into a real payment mechanism, and MPP Session enables payment channels for high-frequency micropayments without an on-chain transaction per payment. This is exactly what a company hiring 50 AI tasks per day needs.

No competing chain (Base, Solana) has the combination of LATAM fiat ramps, native USDC, and agentic protocols that Stellar has built over a decade.

---

## PHASE 2: MVP Definition

### Project Name (Tentative)

**puls3 — B2B Agent Marketplace on Stellar**

### Core Value Proposition (Elevator Pitch)

> "puls3 lets Latin American companies hire verified AI agents and pay them per task in USDC on Stellar, with 5-second settlement, fractions-of-a-cent costs, and complete on-chain traceability."

### Target User Persona

- **B2B Buyer (demand side):** Head of Operations or CFO at fintechs and digital services companies in Brazil, Mexico, and Colombia. Needs to automate recurring operational tasks (payment reconciliation, vault analysis, invoice parsing) and cannot justify a SaaS subscription for each agent. Values traceability and regulatory compliance.
- **Agent Builder (supply side):** Independent developers or small teams in LATAM who already build AI agents (using Claude, GPT, Gemini, Llama) and want to monetize them without depending on global platforms that do not understand the regional context.

### Core MVP Features

- **Curated catalog of 8–10 high-value agents for B2B:** Based on the UI already designed (Ledger Scout, Remit Pilot, Soroban Auditor, Invoice Clerk, Market Pulse, Copy Forge, Support Relay, Data Weaver), the MVP should prioritize the agents that solve payment and on-chain analysis pain points. Ledger Scout and Invoice Clerk are the clearest candidates for pilots with anchor companies.
- **Per-task payment system in USDC on Stellar:** The buyer deposits USDC into a Soroban escrow. Payment is released to the agent only when the task is completed and verified on-chain. Price per task is visible (0.10–4.50 USDC depending on the agent). Settlement in ~5 seconds.
- **On-chain agent reputation and identity:** Each agent has a Stellar wallet and an identity record on Soroban with structured metadata (model used, capabilities, reputation level). The buyer sees the rating (4.4–4.9 stars), skills, and transaction history before hiring.
- **History and audit dashboard for the buyer:** The Head of Ops can see all contracted tasks, the amount paid in USDC, the Stellar transaction hash, and the output generated by the agent. This solves the traceability problem for compliance.
- **Frictionless onboarding for the buyer:** Integration with existing wallets (Freighter, xBull) or direct connection through the puls3 UI. The buyer does not need to know what Soroban is; they just connect their wallet, choose an agent, and pay.

### Stellar Integration (The "How")

| Component | Role in the MVP |
|---|---|
| **Native USDC on Stellar** | Per-task payment currency. Circle issues USDC on Stellar; the buyer deposits USDC into escrow and the agent receives it upon task completion. |
| **Soroban Smart Contracts** | Escrow logic and Job Lifecycle: creation → acceptance → execution → verification → settlement. The contract releases payment only when the completion condition is met. |
| **MPP (Machine Payments Protocol)** | *Charge* mode for one-time per-task payments. *Session* mode for companies that hire agents at high frequency (e.g., continuous liquidity monitoring). Session mode enables off-chain micropayments with accumulated settlement, reducing operating costs. |
| **x402** | For per-HTTP-request payments to agent APIs. If an agent exposes an API, the buyer pays per request with Soroban authorization. |
| **On-chain identity and reputation (Soroban)** | On-chain agent metadata (model, skills, rating) built on the appropriate Stellar identity standard (see "Alignment with current decisions"). Reputation is built from verifiable on-chain transactions. |
| **Sponsored accounts** | The buyer does not need XLM for gas. Stellar allows network fees to be sponsored, removing a critical barrier to entry for non-crypto companies. |

**Why not another chain?** Base (used by Virtuals) has higher theoretical throughput, but lacks the LATAM fiat ramps (MoneyGram, Bitso, Mercado Bitcoin) that Stellar has. Solana has speed, but does not have native USDC with the LATAM anchor integration that Stellar offers. For a B2B marketplace that needs a Mexican fintech to be able to convert USDC to pesos at a MoneyGram location, Stellar is the only viable option.

### Cold Start Resolution Strategy

The report correctly identifies that the critical risk is two-sided adoption. The MVP strategy should follow the principle of "start with the side that is hardest to acquire and retain": the supply of high-quality agents.

**Phase 0 (Q4 2026) — Supply seeding:**

- Manually recruit 8–10 agent builders in LATAM (Soroban communities, Stellar hackathons, developer Discords). Offer free listings and visibility in the marketplace.
- Curate the agents: only list agents that solve concrete B2B pain points (Ledger Scout, Invoice Clerk, Remit Pilot). No entertainment agents.

**Phase 1 (Q1 2027) — Demand seeding:**

- Select 10–15 anchor companies in Brazil and Mexico (fintechs, payment processors, digital services companies). Offer a free pilot: the first 100 tasks of Ledger Scout or Invoice Clerk are free, subsidized by puls3.
- The goal is not revenue, but to validate that the USDC → Soroban escrow → task → settlement payment flow works without friction for a non-crypto user.

**Phase 2 (Q2 2027) — Manual matchmaking:**

- The puls3 team acts as a human "market maker": it connects companies with specific agents, sets up the escrow manually, and monitors the transaction through to settlement. This builds trust and generates real usage data.
- Only when organic transaction volume exceeds 50 tasks per week is matching automated.

### Success Metrics (KPIs)

| KPI | MVP Target (6 months) | Why it matters |
|---|---|---|
| Active agents in the marketplace | 8–10 | Minimum viable supply. Fewer than 8 does not generate enough value for the buyer. |
| Anchor companies in pilot | 10–15 | Minimum viable demand. Validates that the problem hurts enough for a company to dedicate time to a pilot. |
| Tasks executed per month | 200–500 | Validates that the payment flow works and that agents solve real tasks. |
| Task completion rate | > 95% | Measures the reliability of the escrow system and the agents. A low rate indicates technical problems or poor agent quality. |
| Average settlement time | < 10 seconds | Validates Stellar's value proposition. If it is longer, the competitive advantage is diluted. |
| Anchor company retention (month 3) | > 70% | Measures whether the problem is painful enough for companies to keep using puls3 after the pilot. |
| Transaction volume in USDC | USD 500,000 cumulative | Financial traction metric. It is the threshold the report identifies for scaling to production. |

### Risks and Assumptions

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Low two-sided adoption | High | High | Pilots with anchor companies before scaling. Subsidize initial supply (free listings) and initial demand (first 100 tasks free). |
| Regulatory (3.5% IOF in Brazil) | High | Medium | Prioritize Colombia and Mexico first. In Brazil, partner with a licensed VASP and structure payments as "digital services" to avoid eFX classification (KuCoin, 2026). |
| Global competition (Virtuals, OKX) | Medium | High | Go deep on the LATAM niche: language, local fiat ramps, local regulatory compliance. Virtuals has 18,000 global agents (TipRanks, 2026), but zero presence in LATAM. |
| Technical failure in Soroban | Medium | High | External audits of the escrow contracts. Per-transaction exposure limits (max. USD 10,000 per task in the MVP phase). |
| Malicious or low-quality agents | Medium | Medium | Mandatory agent verification before listing. On-chain reputation system (the agent loses its deposit if it fails to deliver — see "Alignment with current decisions"). |
| Dependence on partners (MoneyGram, Bitso) | Medium | High | Diversify ramps: integrate multiple anchors in each country. Do not depend on a single partner to operate in a market. |

**Critical assumptions:**

- Anchor companies are willing to pay per task in USDC instead of paying a monthly subscription.
- Agent builders in LATAM are willing to list their agents on a regional marketplace instead of building their own distribution channel.
- Stablecoin regulation in Colombia and Mexico allows operating a per-task payment marketplace without a full VASP license (under the Colombian regulatory sandbox and as a non-financial entity in Mexico).

---

## PHASE 3: Academic Rigor and Sources

All market claims, projections, and regulatory data in this analysis are backed by verifiable and up-to-date sources (2024–2026). APA 7th edition standards are applied for in-text citations and the reference list.

**Limitations of the analysis:**

- Market projections come from commercial research firms with unaudited methodologies. MarketsandMarkets (2026) projects USD 401.2M → USD 3,990M (CAGR 38.8%), while Grand View Research (2025) projects a CAGR of 50.8% for the same period. The discrepancy reflects methodological differences in how scope is defined (autonomous agents vs. multi-agent systems).
- There is no verifiable public series on the percentage of Latin American companies actively using autonomous agents. The available data measure AI adoption in general, not agents specifically (IBM, 2026, as cited in Imagen Radio, 2026).
- Stellar on-chain data come from quarterly reports by the Stellar Development Foundation and third parties (Nansen, Blockworks), not from independent audits.
- The regulatory analysis summarizes rules in force as of September 2026, a highly changing environment. Brazil's BCB Resolutions 519–521 (effective February 2026) (Global Legal Insights, 2026) and Mexico's AVE initiative (under legislative discussion) (Legal Paradox, 2026) are examples of an evolving framework.
- There is a risk of confirmation bias when evaluating a product built on Stellar from a perspective that favors Stellar. The competitive analysis acknowledges that Virtuals (Base) and OKX (OKX Chain) have significant traction: Virtuals has 18,000 active agents and USD 479M in economic activity in Q1 2026 (TipRanks, 2026), and OKX AI has 10,000 registered agent identities and more than 4,000 approved provider listings since July 2026 (OKX, 2026).

---

## Alignment with current decisions

This section lists where the proposal differs from the existing ADRs. It does **not** modify the ADRs; divergences are recorded here so they can be discussed or promoted to their own issues.

- **x402 and MPP Session are not part of the MVP (ADR-0003, ADR-0005).** This proposal describes x402 and MPP Session as part of the Stellar integration, but the current MVP scope does not include them. They should be treated as post-MVP or optional integrations.
- **Slashing of an agent deposit is not defined in any ADR.** The "Risks and Assumptions" section mentions slashing as a mitigation for low-quality agents, but no ADR establishes slashing mechanics. This is a new proposal, not a current decision.
- **Ledger Scout and Market Pulse read on-chain data, but MVP agents are prompt-only (ADR-0004).** This proposal assumes agents can read on-chain data; ADR-0004 restricts MVP agents to prompt-only behavior. The on-chain reading capability is therefore out of scope for the MVP.
- **Agent identity follows ERC-8004 / Stellar 8004 (ADR-0002, ADR-0005); SEP-41 is the fungible token interface, not an NFT standard.** The original wording referred to "SEP-41 NFTs", which is inaccurate. Agent identity must use the ERC-8004 / Stellar 8004 standard. SEP-41 remains the fungible token interface and should not be used to describe NFTs.

---

## References

Arp Digital. (2026, July 10). *The true cost of SWIFT for GCC businesses: Fees, delays and hidden charges*. https://www.arpdigital.io

Gate News. (2026, June 23). *MoneyGram launches dollar-backed MGUSD stablecoin on Stellar with 500K cash points*. https://miniapp.gate.com/es/news/detail/moneygram-launches-dollar-backed-mgusd-stablecoin-on-stellar-with-500k-cash-22054255

Gartner. (2025, August 26). *Gartner predicts 40% of enterprise apps will feature task-specific AI agents by 2026, up from less than 5% in 2025* [Press release]. https://www.gartner.com/en/newsroom/press-releases/2025-08-26-gartner-predicts-40-percent-of-enterprise-apps-will-feature-task-specific-ai-agents-by-2026-up-from-less-than-5-percent-in-2025

Global Legal Insights. (2026). *Blockchain & cryptocurrency laws and regulations 2026 – Brazil*. https://www.globallegalinsights.com/practice-areas/blockchain-cryptocurrency-laws-and-regulations/brazil/

Grand View Research. (2025, December 15). *Latin America AI agents market size & outlook, 2026–2033*. https://www.grandviewresearch.com/horizon/outlook/ai-agents-market/latin-america

ImageToTable. (2026, September 18). *Why Boleto reconciliation costs more than most finance teams realize*. https://imagetotable.ai/blog/brazil-boleto-reconciliation-manual-problem

Imagen Radio. (2026, September 8). *Empresas en América Latina aumentarán inversión en IA para ser más competitivos*. https://www.imagenradio.com.mx/finanzas/empresas-america-latina-aumentaran-inversion-ia-para-ser-mas-competitivos

KuCoin. (2026, September 15). *Brazil didn't ban stablecoins. It did something more consequential*. https://www.kucoin.com

Legal Paradox. (2026, May 6). *Stablecoin regulation in Mexico: Guide for foreign issuers*. https://www.legalparadox.com

MarketsandMarkets. (2026, August 18). *Latin America agentic AI market (2025–2030)*. https://www.marketsandmarkets.com/Market-Reports/geography/agentic-ai-market/latinamerica

OKX. (2026, September 9). *From code runs to security scans: OKX AI's agent-to-agent marketplace takes shape*. https://www.okx.com/en-au/learn/okx-ai-2

Routefusion. (2026, February 7). *Multi-rail payments: SWIFT vs local rails vs stablecoin settlement (2026)*. https://routefusion.com

Stellar Development Foundation. (2026a, April 1). *Agentic payments: HTTP-native payment protocols for AI agents and APIs*. Stellar Docs. https://developers.stellar.org/docs/build/agentic-payments

Stellar Development Foundation. (2026b, March 9). *x402 on Stellar: unlocking payments for the new agent economy*. https://stellar.org/blog/foundation-news/x402-on-stellar

Stripe. (2026). *Pricing & fees*. https://stripe.com/pricing

TipRanks. (2026, August 5). *Virtuals Protocol is turning AI agents into an economy*. Business Insider. https://markets.businessinsider.com/news/stocks/virtuals-protocol-is-turning-ai-agents-into-an-economy-1036415052

Vendr. (2026). *Stripe software pricing & plans 2026*. https://www.vendr.com
