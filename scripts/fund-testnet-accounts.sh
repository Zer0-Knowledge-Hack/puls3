#!/usr/bin/env bash
# Funds demo and test accounts on Stellar testnet: XLM from Friendbot, then a scripted
# test USDC asset (the PoC approach from #7: a throwaway asset whose issuer we control,
# see docs/spikes/payments-and-wallets.md). Circle's testnet USDC comes only from the
# web faucet (https://faucet.circle.com), so it cannot be scripted.
#
# Usage:
#   scripts/fund-testnet-accounts.sh [--xlm-only] <account>...
#
#   <account>   a public key (G...) or the name of a Stellar CLI identity (stellar keys ls).
#   --xlm-only  only call Friendbot; skip the test asset.
#
# Test USDC needs a trustline, and only the account's own key can sign it. For a CLI
# identity the script adds the trustline itself. A bare public key must already trust
# the asset (stellar tx new change-trust --source-account <its identity> --line <asset>).
#
# Env:
#   STELLAR_NETWORK           must be 'testnet' (default)
#   FRIENDBOT_URL             default https://friendbot.stellar.org/
#   TEST_USDC_ISSUER_ACCOUNT  Stellar CLI identity that issues the test asset
#                             (default puls3-test-usdc-issuer; created and funded if missing)
#   TEST_USDC_CODE            asset code (default PUSDC)
#   TEST_USDC_AMOUNT          amount per account in stroops, 7 decimals (default 1000000000 = 100.00)
#
# Only identity names and public keys are read: no key material is read, logged or written.
# Exit codes: 0 every account funded; 1 usage error or any account failed (the others
# are still attempted, and every tx hash obtained is printed).
set -euo pipefail

usage() {
  echo "Usage: scripts/fund-testnet-accounts.sh [--xlm-only] <account>..." >&2
  echo "  <account> is a public key (G...) or a Stellar CLI identity name." >&2
}

XLM_ONLY=0
ACCOUNTS=()
for arg in "$@"; do
  case "$arg" in
    --xlm-only) XLM_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option '$arg'." >&2; usage; exit 1 ;;
    *) ACCOUNTS+=("$arg") ;;
  esac
done
if [ "${#ACCOUNTS[@]}" -eq 0 ]; then
  usage
  exit 1
fi

NETWORK="${STELLAR_NETWORK:-testnet}"
if [ "$NETWORK" != "testnet" ]; then
  echo "error: this script only funds 'testnet' accounts (got '$NETWORK')." >&2
  echo "Unset STELLAR_NETWORK or set it to 'testnet'." >&2
  exit 1
fi
FRIENDBOT_URL="${FRIENDBOT_URL:-https://friendbot.stellar.org/}"
ISSUER_ID="${TEST_USDC_ISSUER_ACCOUNT:-puls3-test-usdc-issuer}"
ASSET_CODE="${TEST_USDC_CODE:-PUSDC}"
AMOUNT="${TEST_USDC_AMOUNT:-1000000000}"
if ! [[ "$AMOUNT" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: TEST_USDC_AMOUNT must be a positive whole number of stroops (got '$AMOUNT')." >&2
  exit 1
fi

command -v curl >/dev/null || { echo "error: 'curl' is required." >&2; exit 1; }

is_public_key() { [[ "$1" =~ ^G[A-Z2-7]{55}$ ]]; }
need_stellar() {
  command -v stellar >/dev/null || { echo "error: the Stellar CLI ('stellar') is required." >&2; exit 1; }
}
tx_hash_of() { grep -oE '(tx/|[Tt]ransaction hash is )[0-9a-f]{64}' "$1" | head -n 1 | grep -oE '[0-9a-f]{64}' || true; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LOG="$WORK/log"

# Preflight: resolve every account before any network call, so a typo funds nobody.
ADDRESSES=()
IDENTITIES=()
for account in "${ACCOUNTS[@]}"; do
  if is_public_key "$account"; then
    ADDRESSES+=("$account")
    IDENTITIES+=("")
    continue
  fi
  if [[ "$account" =~ ^S[A-Z2-7]{55}$ ]]; then
    echo "error: an argument looks like a secret key. Pass the public key (G...) or an identity name." >&2
    exit 1
  fi
  need_stellar
  if ! address="$(stellar keys address "$account" 2>/dev/null)" || ! is_public_key "$address"; then
    echo "error: '$account' is neither a public key nor a Stellar CLI identity (stellar keys ls)." >&2
    exit 1
  fi
  ADDRESSES+=("$address")
  IDENTITIES+=("$account")
done

ASSET=""
if [ "$XLM_ONLY" -eq 0 ]; then
  need_stellar
  if ! ISSUER="$(stellar keys address "$ISSUER_ID" 2>/dev/null)"; then
    echo "Creating the test asset issuer identity '$ISSUER_ID' (kept in the Stellar CLI config)."
    if ! stellar keys generate "$ISSUER_ID" --fund --network "$NETWORK" >"$LOG" 2>&1 ||
      ! ISSUER="$(stellar keys address "$ISSUER_ID" 2>/dev/null)"; then
      echo "error: could not create the issuer identity '$ISSUER_ID'." >&2
      cat "$LOG" >&2
      exit 1
    fi
  fi
  for address in "${ADDRESSES[@]}"; do
    if [ "$address" = "$ISSUER" ]; then
      echo "error: $address is the test asset issuer; it cannot receive its own asset." >&2
      exit 1
    fi
  done
  ASSET="$ASSET_CODE:$ISSUER"
fi

FAILED=0

# fund_xlm <address>: Friendbot creates and funds the account. Already funded is fine.
fund_xlm() {
  local address="$1" body="$WORK/friendbot" status hash
  status="$(curl -sS -o "$body" -w '%{http_code}' "${FRIENDBOT_URL}?addr=$address" 2>"$LOG" || true)"
  if [ "$status" = "200" ]; then
    hash="$(grep -oE '"hash" *: *"[0-9a-f]{64}"' "$body" | head -n 1 | grep -oE '[0-9a-f]{64}' || true)"
    if [ -n "$hash" ]; then
      echo "xlm   $address tx $hash"
      return 0
    fi
    echo "error: Friendbot answered 200 without a transaction hash for $address." >&2
    return 1
  fi
  if grep -qiE 'createAccountAlreadyExist|already funded|op_already_exists' "$body" 2>/dev/null; then
    echo "xlm   $address already funded"
    return 0
  fi
  echo "error: Friendbot failed for $address (HTTP ${status:-none})." >&2
  [ ! -s "$body" ] || head -c 500 "$body" >&2
  [ ! -s "$LOG" ] || cat "$LOG" >&2
  return 1
}

# run_tx <label> <address> <stellar args...>: runs a CLI transaction and prints its hash.
run_tx() {
  local label="$1" address="$2" hash
  shift 2
  if ! stellar "$@" >"$LOG" 2>&1; then
    echo "error: $label failed for $address." >&2
    cat "$LOG" >&2
    return 1
  fi
  hash="$(tx_hash_of "$LOG")"
  if [ -z "$hash" ]; then
    echo "error: $label for $address returned no transaction hash." >&2
    cat "$LOG" >&2
    return 1
  fi
  printf '%-5s %s tx %s\n' "$label" "$address" "$hash"
}

# fund_asset <address> <identity or empty>: trustline (identities only), then the payment.
fund_asset() {
  local address="$1" identity="$2"
  if [ -n "$identity" ]; then
    run_tx trust "$address" tx new change-trust --source-account "$identity" \
      --line "$ASSET" --network "$NETWORK" || return 1
  fi
  if ! run_tx usdc "$address" tx new payment --source-account "$ISSUER_ID" \
    --destination "$address" --asset "$ASSET" --amount "$AMOUNT" --network "$NETWORK"; then
    if [ -z "$identity" ]; then
      echo "hint: a bare public key must trust the asset first:" >&2
      echo "  stellar tx new change-trust --source-account <identity-of-$address> --line $ASSET --network $NETWORK" >&2
    fi
    return 1
  fi
}

if [ "$XLM_ONLY" -eq 0 ]; then
  # The SAC lets Soroban contracts move the asset. Deploying it again fails harmlessly.
  stellar contract asset deploy --asset "$ASSET" --source-account "$ISSUER_ID" \
    --network "$NETWORK" >"$LOG" 2>&1 || true
  SAC="$(stellar contract id asset --asset "$ASSET" --network "$NETWORK" 2>/dev/null || true)"
  echo "asset $ASSET (SAC ${SAC:-unknown}), $AMOUNT stroops per account"
fi

for i in "${!ADDRESSES[@]}"; do
  address="${ADDRESSES[$i]}"
  if ! fund_xlm "$address"; then
    FAILED=$((FAILED + 1))
    continue
  fi
  if [ "$XLM_ONLY" -eq 0 ] && ! fund_asset "$address" "${IDENTITIES[$i]}"; then
    FAILED=$((FAILED + 1))
  fi
done

if [ "$FAILED" -gt 0 ]; then
  echo "failed: $FAILED of ${#ADDRESSES[@]} account(s)." >&2
  exit 1
fi
echo "funded: ${#ADDRESSES[@]} account(s) on $NETWORK."
