# Verifying the on-chain evidence

How to reproduce every check in the [README evidence section](../../README.md#on-chain-evidence-testnet) on Stellar testnet. All values come from [`contracts/deployments/testnet.json`](../../contracts/deployments/testnet.json).

## Rules

- Everything here is read-only. No secret or signing key is needed, and nothing is broadcast.
- Contract reads use `--send=no`, which simulates the call. `--source-account` is only the account the simulation is built for. Use any existing testnet identity or public key (`<any-identity>`). It signs nothing.
- Replace `<any-identity>` with a Stellar CLI identity name or a `G...` address.
- Explorer base: `https://stellar.expert/explorer/testnet`. Contracts live under `/contract/<id>`, transactions under `/tx/<hash>`.

## Variables

```bash
REGISTRY=CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ
ESCROW=CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2
USDC_SAC=CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA
SRC=<any-identity>
```

## 1. Escrow contract exists and its WASM hash

Explorer: open `$ESCROW` at `https://stellar.expert/explorer/testnet/contract/CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2`. Expected: the contract page loads and shows the WASM hash.

CLI:

```bash
stellar contract fetch --id $ESCROW --network testnet --out-file escrow.wasm
sha256sum escrow.wasm   # expected 15f98ea5e667da8af4a2bda3cc7e55232e7aa7ca03032d0e1572043a6c76e12e
```

Expected: the hash matches the escrow WASM hash in the README. Also check the deployment transaction `04a98f919fdd59cdbe3bd10b8bdaa09fcafe8cbedba8e4a9a7a8e533a4737a73` (see step 6 for the Horizon check).

## 2. Escrow configuration getters

```bash
for f in fee_bps approval_window max_expiry treasury admin identity_registry; do
  echo -n "$f: "
  stellar contract invoke --id $ESCROW --network testnet --source-account $SRC --send=no -- $f
done
```

Expected: `fee_bps` 0, `approval_window` 86400, `max_expiry` 2592000, `treasury` null (none), `admin` `GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY`, `identity_registry` equal to `$REGISTRY`.

## 3. USDC is allow-listed

```bash
stellar contract invoke --id $ESCROW --network testnet --source-account $SRC --send=no \
  -- is_token_allowed --token $USDC_SAC
```

Expected: `true`. Confirm the SAC id is Circle testnet USDC:

```bash
stellar contract id asset --asset USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5 --network testnet
```

Expected: `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA`. The allow-list transaction is `d2de45534c0bd56e5759ce57c4c8380ed3e7eccfe4d03f3821b9e165df679cf9`.

## 4. Agents in the registry

```bash
stellar contract invoke --id $REGISTRY --network testnet --source-account $SRC --send=no -- total_agents
stellar contract invoke --id $REGISTRY --network testnet --source-account $SRC --send=no -- agent_uri --agent-id 7
stellar contract invoke --id $REGISTRY --network testnet --source-account $SRC --send=no -- get_agent_wallet --agent-id 7
```

Expected: `total_agents` is 15 (agents 0 to 6 are superseded orphans, agents 7 to 14 are `puls3://demo/agt-001` to `agt-008`), `agent_uri` for 7 is `puls3://demo/agt-001`, and the wallet is `GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY`. Repeat `agent_uri` with ids 8 to 14 for the other current agents. Their registration transactions are listed in the README.

## 5. Escrow job 3 (evidence of record)

```bash
stellar contract invoke --id $ESCROW --network testnet --source-account $SRC --send=no -- get_job --job-id 3
```

Expected: `agent_id` 7, budget `5000000` (0.5 USDC), token `$USDC_SAC`, client and evaluator `GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H`, provider `GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY`, and `state` printed as the number `3`, which is `Completed`.

Then check the four lifecycle transactions as in step 6:

| Step | Hash |
|---|---|
| `create_job` | `3baba1832b5a1d44330068acd41d5b09fb8e15faab1ba914829c0a0a62d054fb` |
| `fund` | `43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437` |
| `submit` | `1ffc2c1603afc5a83ba263f5c35579e4bcd379fe261f1e598ca8c204579ffd74` |
| `complete` | `ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4` |

Jobs 1 and 2 are earlier attempts on the same contract (job 1 stopped in `Submitted`, job 2 completed). They are not evidence of record. `job_count` returns 3 or more.

## 6. Any transaction: explorer and Horizon

Explorer: `https://stellar.expert/explorer/testnet/tx/<hash>`. Expected: the transaction page shows a successful result.

Horizon:

```bash
HASH=ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4
curl -s https://horizon-testnet.stellar.org/transactions/$HASH | grep '"successful"'
```

Expected: `"successful": true`. Do this for every hash in the README: the deployment transactions (`04a98f919fdd59cdbe3bd10b8bdaa09fcafe8cbedba8e4a9a7a8e533a4737a73`), the four job hashes, and the direct payment below.

## 7. Direct SAC muxed payment

Hash: `652a575b5d85814c19a4fed0f7d21f40acb35a399c4008d450877ee83e8b31ab`. Check it as in step 6.

Expected: successful, a USDC SAC `transfer` of `5000000` stroops (0.5 USDC) from `GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H` to the muxed address `MAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIAAAAAAAAAAABCW5Q`, which is the provider account plus hire id 8.

The older README entry with hire id 7 (`17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f`) moved `PUSDC`, a test asset issued by the payments spike, not Circle USDC. It is spike evidence only.

## After a testnet reset

Stellar testnet is periodically reset. After a reset, every contract ID, hash and explorer link above becomes invalid and the checks return not found. The operator can redeploy and re-record:

1. Run `scripts/deploy-testnet.sh` (registry), then `scripts/seed-demo-agents.sh`.
2. Run `scripts/deploy-escrow-testnet.sh`, then its `--test-job` and `--direct-payment` modes. See `contracts/README.md` for the required environment.
3. Update the README values from the regenerated `contracts/deployments/testnet.json`.

## Escrow TTL

Escrow state is stored as persistent entries on Soroban, with a TTL of about 60 days. Before it lapses, call `extend_ttl` for the job you want to keep (this one needs a funded identity and broadcasts a transaction, so it is an operator action, not a verification step):

```bash
stellar contract invoke --id $ESCROW --network testnet --source-account <funded-identity> \
  -- extend_ttl --job-id 3
```

A deferred payout (a `Claimable` balance) is not covered by `extend_ttl`. Anyone can keep it withdrawable with `extend_claimable_ttl`, which credits nothing and does nothing if the entry does not exist:

```bash
stellar contract invoke --id $ESCROW --network testnet --source-account <funded-identity> \
  -- extend_claimable_ttl --recipient <recipient> --token <token>
```

Expired entries can be restored with `stellar contract restore`, but a testnet reset cannot be undone.
