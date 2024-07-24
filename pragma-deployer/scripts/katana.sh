#!/bin/bash

# Find available port using Python
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

echo "Starting katana on port $PORT"
katana --chain-id SN_SEPOLIA --host 127.0.0.1 --port $PORT --accounts "1" --seed "1" &

while ! nc -z localhost $PORT; do   
  sleep 0.1 # wait for 1/10 of the second before check again
done

# Run your Python script
echo "Running deploy_pragma.py with port $PORT"
STARKNET_NETWORK=katana poetry run deploy-pragma --port $PORT
STARKNET_NETWORK=katana poetry run add-pairs --port $PORT
STARKNET_NETWORK=katana poetry run register-publishers --port $PORT
STARKNET_NETWORK=katana poetry run deploy-summary-stats --port $PORT
STARKNET_NETWORK=katana poetry run deploy-randomness --port $PORT
STARKNET_NETWORK=katana poetry run test-randomness --port $PORT
STARKNET_NETWORK=katana poetry run upgrade-pragma --port $PORT
# STARKNET_NETWORK=katana poetry run python3 scripts/remove_source.py --port $PORT
# STARKNET_NETWORK=katana poetry run python3 scripts/remove_publishers.py --port $PORT


