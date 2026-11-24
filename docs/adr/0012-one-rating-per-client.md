# ADR-0012: One client is one rating, and no minimum job budget

- **Status:** Proposed
- **Date:** 2026-11-21
- **Issue:** #324 (follow-up of #273 item 4 and #200)
- **Related:** [ADR-0008](0008-reputation-formula-off-chain.md) (the formula stays off chain) · [ADR-0003](0003-payment-rail-and-custody.md) (agent wallets and sweeps) · [docs/domain/reputation.md](../domain/reputation.md)

## Context

A rating counts only for a paid, completed hire (#201, #239), and never from the agent's owner (#11) or its payout wallet (R-3, #200). Nothing stops an owner from hiring their own agent from a **second wallet**: the hire is real and paid, so its rating counts.

#273 suggested a minimum job budget, to make each such rating cost more. Facts checked for this decision:

- **The money comes back.** The budget of a completed job goes to the agent's wallet, and ADR-0003 sweeps agent earnings to the builder. The owner pays themselves. What a self-hire really costs is the platform fee (`fee_bps`, **0** on testnet, `contracts/deployments/testnet.json`) and the network fee.
- **So a minimum budget costs the owner nothing while the fee is 0**, and only `fee_bps × minimum` once a fee exists. It would also stop honest agents from selling cheap jobs, which the catalog has today (0.10 USDC).
- **Ratings used to add up per hire.** `reputationOf` counted every record. With one second wallet and 20 cheap hires, an owner moved a new agent from 4.00 to **4.80**, the score of an agent with 100 reviews averaging 4.80.

## Decision

1. **No minimum job budget.** It is not a defence while earnings return to the owner, and it costs honest cheap agents their market. Revisit it only together with a non-zero platform fee. Even then, the cost of a fake rating would be the fee on it, not the budget.
2. **One client is one rating.** `reputationOf` groups the counted feedback by client and uses the mean of each client's scores. The Bayesian average then runs over clients, not hires: `R = (C·m + Σ clientMean) / (C + clients)`. With this rule:
   - one wallet with 20 five-star hires gives **4.17**, the same as a single review;
   - each further point of score needs further wallets, each funded, with a USDC trustline and a paid hire;
   - a returning client who rates again still counts, with the mean of their scores.
3. **`paidHireCount` is unchanged.** It still counts the paid hires whose rating counts, so a busy agent still shows its volume.

The rule lives in `puls3_domain`, so the server and `scripts/verify_reputation.dart` keep computing the same number (ADR-0008, #202).

## What this does not solve

- **Many wallets.** An owner with N wallets still buys N ratings. On mainnet, each needs its base reserve and a trustline. That raises the effort, not the price much. Stronger defences are separate work, all of them product decisions:
  - showing the number of distinct clients;
  - weighting a client by what they paid across agents;
  - tracing who funded a client account.
- **Existing scores move.** An agent rated more than once by the same client is re-scored when this lands. On testnet that includes Soroban Pre-Audit (agent #30), rated twice by the same wallet (hires 20 and 21).

## Consequences

- The worked examples of `docs/domain/reputation.md` keep their numbers: their scores come from distinct clients. A new row shows the one-wallet case.
- `reputationOf` no longer depends on the order of the feedback it is given.
