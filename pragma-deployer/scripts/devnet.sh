#!/bin/bash
# Runs every deployer script against a fresh local starknet-devnet.
# Used by .github/workflows/run_scripts.yml; runnable locally as-is.
set -euo pipefail

PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

echo "Starting starknet-devnet on port $PORT"
starknet-devnet --chain-id TESTNET --host 127.0.0.1 --port "$PORT" --accounts 1 --seed 1 &
DEVNET_PID=$!
trap 'kill "$DEVNET_PID" 2>/dev/null || true' EXIT

until nc -z 127.0.0.1 "$PORT"; do sleep 0.1; done

# Use the first predeployed account as deployer/admin instead of hardcoding
# an address that depends on the devnet account class.
ACCOUNTS=$(curl -s -X POST "http://127.0.0.1:$PORT/" -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"devnet_getPredeployedAccounts","params":{}}')
DEVNET_ACCOUNT_ADDRESS=$(echo "$ACCOUNTS" | python3 -c 'import sys, json; print(json.load(sys.stdin)["result"][0]["address"])')
DEVNET_PRIVATE_KEY=$(echo "$ACCOUNTS" | python3 -c 'import sys, json; print(json.load(sys.stdin)["result"][0]["private_key"])')
export DEVNET_ACCOUNT_ADDRESS DEVNET_PRIVATE_KEY
export STARKNET_NETWORK=devnet
echo "Using predeployed account $DEVNET_ACCOUNT_ADDRESS"

for script in \
  deploy-pragma \
  add-pairs \
  register-publishers \
  deploy-summary-stats \
  deploy-randomness \
  deploy-randomness-example \
  upgrade-pragma; do
  echo "Running $script on port $PORT"
  uv run "$script" --port "$PORT"
done
