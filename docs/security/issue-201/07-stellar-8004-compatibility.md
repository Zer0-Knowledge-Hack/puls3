# 07 · Stellar 8004 compatibility

## Current ABI (unchanged by this analysis)

| Item | puls3 today | Notes |
|---|---|---|
| `give_feedback(caller, agent_id: u32, value: i128, value_decimals: u32, tag1, tag2, endpoint, feedback_uri: String, feedback_hash: BytesN<32>) -> Result<(), ReputationError>` | `reputation-registry/src/lib.rs:199` | Same names, order and types as the Stellar 8004 subset in ADR-0002 |
| `FeedbackData { value, value_decimals, is_revoked, tag1, tag2 }` | `:35` | Returned by `read_feedback` |
| `NewFeedback { agent_id, client_address, tag1 (topics); feedback_index, value, value_decimals, tag2, endpoint, feedback_uri, feedback_hash }` | `:113` | Unchanged shape |
| `ReputationError` 1..12 | `:85` | Values kept identical to Stellar 8004 |
| Recorded deviations | ADR-0002 | #199: stricter value bound, `get_summary` skips unnormalizable records |

History: ADR-0002 first designed a payment-backed `give_feedback(…, hire_id, …)`
plus a trusted `authorize_feedback`. ADR-0005 D5 superseded it: "the paid-hire
gate leaves the registry … proven by a completed ERC-8183 escrow job and
applied by readers", to keep the interface drop-in.

## Can #201 be met with the existing fields?

Yes, without any ABI change.

| Field | Stored? | Fit for the job reference | Notes |
|---|---|---|---|
| `feedback_uri` | No (event only) | Yes, as the ERC-8004 pointer to the feedback document / job | ERC-8004 intends `feedbackURI` to point at an off-chain feedback file, which may carry proof of payment. Not readable with `read_feedback`; ~7 days on public RPC |
| `feedback_hash` | No (event only) | Yes, as the commitment to that document | Integrity, not proof of payment |
| `tag2` | **Yes** | Yes, as the durable, machine-readable reference | Free-form in ERC-8004. Using a unique value per job makes `get_summary`'s `tag2` filter useless for puls3 records, which puls3 does not use |
| `tag1` | Yes, and an event topic | Possible, but better kept for a category (it is indexed as a topic) | — |
| `endpoint` | No | No | Meant for the agent endpoint rated |

Using these fields is a **convention**, not a change of the interface:
another ERC-8004 client can still call `give_feedback` with any values, and
the record is still valid ERC-8004 data. What changes is how puls3 **reads**:
records without a verifiable job reference stop counting in puls3's rating.
This is a reader rule, exactly what ADR-0005 D5 decided.

## If the contract had to enforce the rule (alternative C)

| Question | Answer |
|---|---|
| What would change | `give_feedback` would need the job id (a new argument, or parsed from `tag2`/`feedback_uri`), the escrow address in storage, a cross-contract `get_job`, the checks `client == caller`, `agent_id`, `state == Completed`, and a stored "job already rated" flag |
| Why it could be wanted | Rejects bad records at write time; `get_summary` becomes paid-only on chain |
| Impact | A new argument breaks the drop-in ABI. Parsing a string keeps the signature but makes valid Stellar 8004 calls fail (a behavioral deviation larger than #199's). It couples the registry to one escrow, reverses ADR-0005 D5, adds cost to every write, needs an upgrade of the deployed registry and a migration for existing records |
| Alternatives that keep compatibility | Reader rule (alternative B), or a separate puls3 "attestation" contract that the escrow or the client calls, leaving the registry untouched |
| Is it a Stellar 8004 deviation | Yes: behavioral (string parsing) or ABI (new argument) |
| What ADR-0002 would need | A new amendment, and ADR-0005 D5 superseded; it also depends on #203 (formula on chain vs off chain) |

Not recommended for #201: the issue explicitly asks for no ABI break, and the
reader rule already gives third-party verifiability.

## What ADR-0002 should record for the recommended design

An "Amended by #201" note in the Reputation Registry section:

1. ABI unchanged. puls3 writes a canonical job reference: `tag2 =
   "puls3:job:<escrow C…>:<job_id>"` (exact format to be fixed in the
   implementation), `feedback_uri` = the same reference (or a document URI
   that contains it), `feedback_hash` = SHA-256 of a canonical document that
   includes it.
2. puls3's rating counts a record only if the referenced job on the
   **pinned** escrow is `Completed`, `job.client` equals the record's client,
   and `job.agent_id` equals the record's agent; at most one record per job.
3. Records without a valid reference are valid ERC-8004 data but do not count
   in puls3's rating (or count as unverified, per the decision in [09](09-technical-proposal.md)).
4. The `tag2` filter of `get_summary` is not meaningful for puls3 records.
5. ADR-0005 D5's implementation note ("reads are unfiltered in the MVP") is
   closed by this rule.
