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
```

#### CallerExample

```shell
forge script script/CallerExample.s.sol \
--broadcast --rpc-url $RPC_URL \
--verifier-url '$ETHERSCAN_VERIFY_URL' \
--etherscan-api-key "verifyContract"
```

#### Feeds

```shell
PAIR_ID="24011449254105924" forge script script/PragmaAggregatorV3.s.sol \
--broadcast --rpc-url $RPC_URL \
--verifier-url '$ETHERSCAN_VERIFY_URL' \
--etherscan-api-key "verifyContract"
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
