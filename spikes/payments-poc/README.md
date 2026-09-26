# Payments PoC (#7)

One real testnet payment on the rail chosen in [ADR-0003](../../docs/adr/0003-payment-rail-and-custody.md): the consumer transfers USDC through the Stellar Asset Contract (SAC) to the agent's **muxed address**, whose muxed id is the **hire id**. The script then verifies the payment the way the puls3 server will, with one JSON-RPC call over plain HTTP.

This is a throwaway proof of concept. Product code must not import it.

## Requirements

- Stellar CLI 25.2.0 or newer (`stellar --version`)
- `bash` and `curl` (on Windows, use Git Bash)

No npm, no Node, no Stellar SDK.

## Run

```bash
cd spikes/payments-poc
bash pay.sh                 # hire id 1, 0.50 of the test asset
HIRE_ID=7 bash pay.sh       # another hire
```

Optional settings are listed in [`.env.example`](.env.example). To use them: `cp .env.example .env`, edit, then `set -a; . ./.env; set +a` before running.

The script:

1. Creates three funded testnet identities with Friendbot (`puls3-poc-payer`, `-agent`, `-issuer`), unless they already exist
2. Issues a test asset `PUSDC` (or uses the `ASSET` you set)
3. Adds the trustlines the payer and the agent need
4. Mints the price to the payer and deploys the asset's SAC (skipped if already deployed)
5. **Pays:** `transfer(from = payer, to = M… (agent + hire id), amount)` on the SAC
6. **Verifies** with `getTransaction` (`xdrFormat: "json"`): status `SUCCESS`, a `transfer` event emitted by the expected SAC to the agent, the exact amount, and `to_muxed_id` equal to the hire id

It ends by printing the transaction hash and its stellar.expert link. It exits with an error if any check fails.

## Keys

No key is ever written to this folder. The accounts are Stellar CLI identities kept in the CLI's own config (`stellar keys ls`). They hold only testnet funds. Remove them with `stellar keys rm puls3-poc-payer` (and `-agent`, `-issuer`).

## Real testnet USDC

To pay in Circle's testnet USDC instead of the test asset:

1. Run `bash pay.sh` once, so the payer account exists
2. Add the USDC trustline: `stellar tx new change-trust --source puls3-poc-payer --line USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5 --network testnet`
3. Fund the payer at [faucet.circle.com](https://faucet.circle.com) (Stellar Testnet, 20 USDC every 2 hours)
4. `ASSET=USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5 bash pay.sh`

The rail is the same; only the asset changes.

## Evidence

Run on 2026-09-26:

```
5/6 pay: transfer 5000000 stroops to the agent, muxed id = hire 7
    to MAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUOAAAAAAAAAAAA4A5I
6/6 verify over plain HTTP (getTransaction, xdrFormat=json)
    ✓ SUCCESS · to GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK · amount 5000000 · hire 7

tx hash: 17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f
```

[View on stellar.expert](https://stellar.expert/explorer/testnet/tx/17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f)
