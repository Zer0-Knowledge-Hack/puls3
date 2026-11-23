# Verifying the production live hire

The production deployment has to be hireable, not only the demo: a builder
publishes an agent from the Studio, a consumer finds it in the marketplace, pays
in testnet USDC, the agent delivers, and the consumer approves and rates. That
is the evidence [issue #313](https://github.com/Zer0-Knowledge-Hack/puls3/issues/313)
asks for. This page records the run and how to re-check it without a secret.

The hire below was driven over the public API with a throwaway testnet account,
not through the browser. The Chrome + Freighter recording is tracked separately
in [#31](https://github.com/Zer0-Knowledge-Hack/puls3/issues/31) and
[#136](https://github.com/Zer0-Knowledge-Hack/puls3/issues/136); what this page
proves is the server and on-chain side of the loop.

## Run summary

| | |
|---|---|
| Date | 2026-11-18 |
| Network | Stellar testnet |
| Server | `https://puls3-hub-on-stellar.api.serverpod.space` |
| Consumer | [`GBGBQI7OJI2WSXXRICNWVZKS32ESG4VAF777XWX5W724BXJ4RVYPCKIF`](https://stellar.expert/explorer/testnet/account/GBGBQI7OJI2WSXXRICNWVZKS32ESG4VAF777XWX5W724BXJ4RVYPCKIF) |
| Agent | Soroban Pre-Audit (`studio-4`, registry id 30) |
| Agent payment wallet | [`GDQHKMYJLDOMS5YDOS3MQ2XRTCSKK3VBUYHJAIHR4H7FSPETQCOTNFBB`](https://stellar.expert/explorer/testnet/account/GDQHKMYJLDOMS5YDOS3MQ2XRTCSKK3VBUYHJAIHR4H7FSPETQCOTNFBB) |
| Hire | 21 |
| Escrow job | 34 |
| Budget | 0.50 USDC (`5000000` stroops) |
| Asset | Circle testnet USDC, SAC `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA` |

The agent has a server-custodied payment wallet. The server signs its `submit`;
the consumer signs creation, funding and approval. The escrow is
`CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2`.

## Values

```bash
ESCROW=CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2
REGISTRY=CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ
REPUTATION=CBJZYEJ5DS7TDLA2ECRAW3ICQIYAOMTCQ5QSY7PYJ5PJ2W5EAHPBP5Q4
CONSUMER=GBGBQI7OJI2WSXXRICNWVZKS32ESG4VAF777XWX5W724BXJ4RVYPCKIF
AGENT_WALLET=GDQHKMYJLDOMS5YDOS3MQ2XRTCSKK3VBUYHJAIHR4H7FSPETQCOTNFBB
SRC=<any-identity>
```

`SRC` is only the simulation source for the contract reads; it signs nothing.

## Agent identity

The agent was deployed from the Studio on 2026-11-17, before the hire:

| Step | Transaction | Ledger | Closed (UTC) |
|---|---|---|---|
| `register_full` | [`3ddf5b2ff6b45c18089e53336124c23bc25ec8aedd82c1944d2ea273dad053b1`](https://stellar.expert/explorer/testnet/tx/3ddf5b2ff6b45c18089e53336124c23bc25ec8aedd82c1944d2ea273dad053b1) | 5774951 | 2026-11-17T06:53:21Z |
| `set_agent_wallet` | [`2bcb512daff96774e7041e799eef89d19da823e221865b9cf29e7fafb34a32a3`](https://stellar.expert/explorer/testnet/tx/2bcb512daff96774e7041e799eef89d19da823e221865b9cf29e7fafb34a32a3) | 5777533 | 2026-11-17T10:28:31Z |

The builder (`GCCB4MKFLRRD4HBXNGMXQMIIU5TSYX2TBAQIQRIGE5LSILPW77E44GOZ`)
registered the metadata and the manifest at
`https://puls3-hub-on-stellar.serverpod.space/registry/82a32ddd0ec1d3e2c742e7ae5a7b4019b0ea9c3ac91563fa18a25ed4f4904c1b`.
Registration first used the builder's own wallet as the payment wallet;
`set_agent_wallet` then moved it to the server-custodied
`GDQHKMYJLDOMS5YDOS3MQ2XRTCSKK3VBUYHJAIHR4H7FSPETQCOTNFBB`, which is what makes
the agent hireable.

The registry events at those ledgers show both steps:

```bash
stellar events --network testnet --id $REGISTRY --start-ledger 5774951 \
  --count 20 --output json | grep '"agent_id":30'
```

Expected: the `Registered` event for agent 30 (`owner` `GCCB4MKF…`,
`agent_uri` the manifest above) and the metadata written with it.

## Hire transactions

Every hash below is on [stellar.expert](https://stellar.expert/explorer/testnet)
and was confirmed `"successful": true` on Horizon testnet.

| Step | Transaction | Ledger | Closed (UTC) |
|---|---|---|---|
| `create_job` | [`3e6e6fc45376e3c04800d54c9a83f5ec53afa0d69c1895fc24a5e297619d3d48`](https://stellar.expert/explorer/testnet/tx/3e6e6fc45376e3c04800d54c9a83f5ec53afa0d69c1895fc24a5e297619d3d48) | 5797508 | 2026-11-18T14:12:59Z |
| `fund` | [`2856648d4c16ad28813f58e4b490f1f27809379eb2a2ba64cb15a5a31305e965`](https://stellar.expert/explorer/testnet/tx/2856648d4c16ad28813f58e4b490f1f27809379eb2a2ba64cb15a5a31305e965) | 5797511 | 2026-11-18T14:13:14Z |
| `submit` | [`e433d6e6436e748af2a18429a4cfdb4699fb2ec8f12e235a21712de49c48ceda`](https://stellar.expert/explorer/testnet/tx/e433d6e6436e748af2a18429a4cfdb4699fb2ec8f12e235a21712de49c48ceda) | 5797515 | 2026-11-18T14:13:34Z |
| `complete` | [`cdefa63a416a507f80e6c081551bb80b342212f2432ac70cb9d35dd65c2ec3ea`](https://stellar.expert/explorer/testnet/tx/cdefa63a416a507f80e6c081551bb80b342212f2432ac70cb9d35dd65c2ec3ea) | 5797635 | 2026-11-18T14:23:34Z |
| `give_feedback` | [`39dcc19052813f04a1710026bccc55f1a6e63bd5ccdbeedfe1cd524e4e6db531`](https://stellar.expert/explorer/testnet/tx/39dcc19052813f04a1710026bccc55f1a6e63bd5ccdbeedfe1cd524e4e6db531) | 5797639 | 2026-11-18T14:23:54Z |

What each step proves:

- The SEP-10 wallet challenge was created, signed and verified on the production
  server ([#136](https://github.com/Zer0-Knowledge-Hack/puls3/issues/136)); it
  leaves no transaction.
- `create_job` makes the consumer the job's client and evaluator and the agent's
  custodied wallet the provider.
- `fund` moves 0.50 USDC from the consumer into the escrow.
- `submit` is signed by the agent itself through the server's custody relay
  ([#208](https://github.com/Zer0-Knowledge-Hack/puls3/issues/208)).
- `complete` is the consumer's approval from the hire detail page
  ([#210](https://github.com/Zer0-Knowledge-Hack/puls3/issues/210)), which pays
  the provider.
- `give_feedback` writes the 5/5 rating to the Reputation Registry.

## Read the state back

The escrow job:

```bash
stellar contract invoke --id $ESCROW --network testnet --source-account $SRC \
  --send=no -- get_job --job-id 34
```

Expected: `agent_id` 30, `client` and `evaluator` the consumer, `provider` the
agent payment wallet, `budget` `"5000000"`, `token` the USDC SAC, and `state` 3
(`Completed`). `deliverable` is the hash the agent committed.

The wallet binding that made the agent hireable:

```bash
stellar contract invoke --id $REGISTRY --network testnet --source-account $SRC \
  --send=no -- get_agent_wallet --agent-id 30
```

Expected: `GDQHKMYJLDOMS5YDOS3MQ2XRTCSKK3VBUYHJAIHR4H7FSPETQCOTNFBB`.

The rating, tied to this paid job:

```bash
stellar contract invoke --id $REPUTATION --network testnet --source-account $SRC \
  --send=no -- read_feedback --agent-id 30 \
  --client-address $CONSUMER --feedback-index 1
```

Expected: `is_revoked` false, `value` `"5"`, `value_decimals` 0, and `tag2`
`puls3:job:v1:<escrow>:34`. The tag is the rule from
[#201](https://github.com/Zer0-Knowledge-Hack/puls3/issues/201) that only
feedback tied to a paid job counts.

## Check every transaction

```bash
for HASH in \
  3ddf5b2ff6b45c18089e53336124c23bc25ec8aedd82c1944d2ea273dad053b1 \
  2bcb512daff96774e7041e799eef89d19da823e221865b9cf29e7fafb34a32a3 \
  3e6e6fc45376e3c04800d54c9a83f5ec53afa0d69c1895fc24a5e297619d3d48 \
  2856648d4c16ad28813f58e4b490f1f27809379eb2a2ba64cb15a5a31305e965 \
  e433d6e6436e748af2a18429a4cfdb4699fb2ec8f12e235a21712de49c48ceda \
  cdefa63a416a507f80e6c081551bb80b342212f2432ac70cb9d35dd65c2ec3ea \
  39dcc19052813f04a1710026bccc55f1a6e63bd5ccdbeedfe1cd524e4e6db531; do
  echo -n "$HASH: "
  curl -s "https://horizon-testnet.stellar.org/transactions/$HASH" \
    | grep -o '"successful": *[a-z]*'
done
```

Expected: `"successful": true` seven times. General contract checks (contract
IDs, WASM hashes, configuration) are in [onchain.md](onchain.md).

## What this run does not cover

- The Chrome + Freighter path and its recording: [#31](https://github.com/Zer0-Knowledge-Hack/puls3/issues/31),
  [#136](https://github.com/Zer0-Knowledge-Hack/puls3/issues/136) and the app
  side of [#210](https://github.com/Zer0-Knowledge-Hack/puls3/issues/210) still
  need one browser run. This run proves the server side of the same loop.
- Mainnet. This is testnet evidence only.
