# Pragma Oracle - Kakarot Interface

Sample scripts to be able to deploy the PragmaCaller contract to Kakarot and verify it.

## Set up env variables

You'll need to set up the variables before doing anything:

```sh
# RPC Url - default is Sepolia
RPC_URL=https://sepolia-rpc.kakarot.org

# Etherscan URL used to verify the contract - default is Sepolia
ETHERSCAN_VERIFY_URL=https://api.routescan.io/v2/network/testnet/evm/1802203764_2/etherscan

# Cairo address of the Pragma Oracle - see deployments
CAIRO_PRAGMA_ORACLE_ADDRESS=0x0
CAIRO_PRAGMA_SUMMARY_STATS_ADDRESS=0x0

# Deployer that will be used to deploy PragmaCaller to Kakarot
EVM_PRIVATE_KEY=0x0

# Set this to the PragmaCaller deployed address on Kakarot once deployed
EVM_PRAGMA_CALLER_ADDRESS=0x0

# Set this to the pair you want to use for the PragmaAggregatorV3 interface
PAIR_ID=0
```

## Deploy

First, activate the .env variables:

```bash
source .env
```

#### PragmaCaller

```shell
forge script script/PragmaCaller.s.sol \
--broadcast --rpc-url $RPC_URL \
--verifier-url $ETHERSCAN_VERIFY_URL \
--etherscan-api-key "verifyContract"

# or just verify

forge verify-contract $EVM_PRAGMA_CALLER_ADDRESS src/PragmaCaller.sol:PragmaCaller \
--verifier-url 'https://api.routescan.io/v2/network/testnet/evm/920637907288165/etherscan' \
--etherscan-api-key "verifyContract" \
--num-of-optimizations 200 \
--compiler-version 0.8.28 \
--constructor-args $(cast abi-encode "constructor(uint256 pragmaOracleAddress, uint256 pragmaSummaryStatsAddress)" $CAIRO_PRAGMA_ORACLE_ADDRESS $CAIRO_PRAGMA_SUMMARY_STATS_ADDRESS)
```

#### CallerExample

```shell
forge script script/CallerExample.s.sol \
--broadcast --rpc-url $RPC_URL \
--verifier-url '$ETHERSCAN_VERIFY_URL' \
--etherscan-api-key "verifyContract"

# or just verify

forge verify-contract $EVM_PRAGMA_CALLER_EXAMPLE_ADDRESS src/CallerExample.sol:CallerExample \
--verifier-url 'https://api.routescan.io/v2/network/testnet/evm/920637907288165/etherscan' \
--etherscan-api-key "verifyContract" \
--num-of-optimizations 200 \
--compiler-version 0.8.28 \
--constructor-args $(cast abi-encode "constructor(address pragmaCallerAddress)" $EVM_PRAGMA_CALLER_ADDRESS)
```

#### Feeds

```shell
PAIR_ID="1407668255603079598916" forge script script/PragmaAggregatorV3.s.sol \
--broadcast --rpc-url $RPC_URL \
--verifier-url '$ETHERSCAN_VERIFY_URL' \
--etherscan-api-key "verifyContract"

# or just verify

PAIR_ID="1407668255603079598916" forge verify-contract [CONTRACT_DEPLOYED_ABOVE] src/PragmaAggregatorV3.sol:PragmaAggregatorV3 \
--verifier-url 'https://api.routescan.io/v2/network/testnet/evm/920637907288165/etherscan' \
--etherscan-api-key "verifyContract" \
--num-of-optimizations 200 \
--compiler-version 0.8.28 \
--constructor-args $(cast abi-encode "constructor(address _pragmaCaller, uint256 _pairId)" $EVM_PRAGMA_CALLER_ADDRESS $PAIR_ID)
```

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
