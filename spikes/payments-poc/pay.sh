#!/usr/bin/env bash
# Pays an agent for one hire on Stellar testnet, using the rail chosen in ADR-0003:
# a USDC transfer through the Stellar Asset Contract (SAC) to the agent's muxed
# address, whose muxed id is the hire id. Then verifies the payment the way the
# puls3 server will: one JSON-RPC call over plain HTTP, no Stellar library.
#
# Keys never touch this repo: accounts are Stellar CLI identities stored in the
# CLI's own config. See README.md.
set -euo pipefail

NETWORK="${NETWORK:-testnet}"
RPC_URL="${RPC_URL:-https://soroban-testnet.stellar.org}"
PREFIX="${IDENTITY_PREFIX:-puls3-poc}"
HIRE_ID="${HIRE_ID:-1}"                 # u64; becomes the muxed id
AMOUNT="${AMOUNT:-5000000}"             # in stroops: 5000000 = 0.50
ASSET="${ASSET:-}"                      # empty = issue a test asset (PUSDC)

for bin in stellar curl; do
  command -v "$bin" >/dev/null || { echo "missing: $bin"; exit 1; }
done

identity() {  # ensure a funded testnet identity exists, print its address
  local name="$PREFIX-$1"
  stellar keys address "$name" >/dev/null 2>&1 ||
    stellar keys generate "$name" --fund --network "$NETWORK" >/dev/null 2>&1
  stellar keys address "$name"
}

echo "1/6 accounts"
PAYER=$(identity payer)
AGENT=$(identity agent)
echo "    payer  $PAYER"
echo "    agent  $AGENT"

echo "2/6 asset"
if [ -z "$ASSET" ]; then
  ISSUER=$(identity issuer)
  ASSET="PUSDC:$ISSUER"
  OWN_ASSET=1
else
  OWN_ASSET=0
fi
echo "    $ASSET"

echo "3/6 trustlines"
for who in payer agent; do
  stellar tx new change-trust --source "$PREFIX-$who" --line "$ASSET" \
    --network "$NETWORK" --quiet >/dev/null
done

if [ "$OWN_ASSET" = 1 ]; then
  echo "4/6 mint test asset to the payer"
  stellar tx new payment --source "$PREFIX-issuer" --destination "$PAYER" \
    --asset "$ASSET" --amount "$AMOUNT" --network "$NETWORK" --quiet >/dev/null
  stellar contract asset deploy --asset "$ASSET" --source "$PREFIX-issuer" \
    --network "$NETWORK" --quiet >/dev/null 2>&1 || true   # already deployed is fine
else
  echo "4/6 using an existing asset: the payer must already hold it"
fi
SAC=$(stellar contract id asset --asset "$ASSET" --network "$NETWORK")
echo "    SAC $SAC"

echo "5/6 pay: transfer $AMOUNT stroops to the agent, muxed id = hire $HIRE_ID"
AGENT_HEX=$(stellar strkey decode "$AGENT" | sed -n 's/.*"public_key_ed25519": *"\([0-9a-f]*\)".*/\1/p')
MUXED=$(stellar strkey encode "{\"muxed_account_ed25519\":{\"id\":$HIRE_ID,\"ed25519\":\"$AGENT_HEX\"}}")
echo "    to $MUXED"
OUT=$(stellar contract invoke --id "$SAC" --source "$PREFIX-payer" --network "$NETWORK" \
  -- transfer --from "$PAYER" --to "$MUXED" --amount "$AMOUNT" 2>&1)
TX=$(printf '%s\n' "$OUT" | grep -oE 'tx/[0-9a-f]{64}' | head -1 | cut -d/ -f2)
[ -n "$TX" ] || { printf '%s\n' "$OUT"; echo "payment failed"; exit 1; }

echo "6/6 verify over plain HTTP (getTransaction, xdrFormat=json)"
RES=$(curl -s -X POST "$RPC_URL" -H 'Content-Type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getTransaction\",\"params\":{\"hash\":\"$TX\",\"xdrFormat\":\"json\"}}")
ok=1
grep -q '"status":"SUCCESS"' <<<"$RES" || { echo "    ✗ status is not SUCCESS"; ok=0; }
# The event must come from the expected asset's SAC, or any look-alike token would pass.
grep -q "\"contract_id\":\"$SAC\",\"type\":\"contract\"" <<<"$RES" || { echo "    ✗ event not emitted by $SAC"; ok=0; }
grep -q "\"address\":\"$AGENT\"" <<<"$RES" || { echo "    ✗ no transfer to the agent"; ok=0; }
grep -q "\"symbol\":\"amount\"},\"val\":{\"i128\":\"$AMOUNT\"" <<<"$RES" || { echo "    ✗ wrong amount"; ok=0; }
grep -q "\"symbol\":\"to_muxed_id\"},\"val\":{\"u64\":\"$HIRE_ID\"" <<<"$RES" || { echo "    ✗ wrong hire id"; ok=0; }
[ "$ok" = 1 ] || exit 1
echo "    ✓ SUCCESS · to $AGENT · amount $AMOUNT · hire $HIRE_ID"

echo
echo "tx hash: $TX"
echo "explorer: https://stellar.expert/explorer/$NETWORK/tx/$TX"
