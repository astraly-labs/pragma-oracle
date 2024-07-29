# PragmaCaller deployer

Sample scripts to be able to deploy the PragmaCaller contract to Kakarot and verify it.

## Set up env variables

You'll need to set up the variables before doing anything:
```sh
# RPC Url - default is Sepolia
RPC_URL=https://sepolia-rpc.kakarot.org

# Etherscan URL used to verify the contract - default is Sepolia
ETHERSCAN_VERIFY_URL=https://api.routescan.io/v2/network/testnet/evm/1802203764_2/etherscan

# Deployer that will be used to deploy PragmaCaller to Kakarot
DEPLOYER_PRIVATE_KEY=0x0

# Address of the pre-deployed PragmaOracle cairo contract
PRAGMA_ORACLE_DEPLOYED_CAIRO_ADDRESS=0x3a99b4b9f711002f1976b3973f4b2031fe6056518615ff0f4e6dd829f972764

# Once PragmaCaller has been deployed, write the address here and call `verify.sh`
PRAGMA_CALLER_DEPLOYED_ADDRESS=0x7491cA3699701a187C1a17308338Ad0bA258B082
```

## Deploy

#### PragmaCaller

```shell
forge create \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY \
src/PragmaCaller.sol:PragmaCaller \
--constructor-args $PRAGMA_ORACLE_DEPLOYED_CAIRO_ADDRESS
```

and verify with:

```sh
forge verify-contract $PRAGMA_CALLER_DEPLOYED_ADDRESS src/PragmaCaller.sol:PragmaCaller \
--rpc-url $RPC_URL \
--verifier-url $ETHERSCAN_VERIFY_URL \
--etherscan-api-key "verifyContract" \
--num-of-optimizations 200 \
--compiler-version v0.8.26+commit.8a97fa7a \
--constructor-args $(cast abi-encode "constructor(uint256 pragmaOracleAddress)" $PRAGMA_ORACLE_DEPLOYED_CAIRO_ADDRESS)
```

#### Feeds

```shell
forge create \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY \
src/PragmaAggregatorV3.sol:PragmaAggregatorV3 \
--constructor-args $PRAGMA_CALLER_DEPLOYED_ADDRESS 18669995996566340 # BTC/USD
```

and verify it:

```shell
forge verify-contract [THE_DEPLOYED_ADDRESS_ABOVE] src/CallerExample.sol:CallerExample \
--rpc-url $RPC_URL \
--verifier-url $ETHERSCAN_VERIFY_URL \
--etherscan-api-key "verifyContract" \
--num-of-optimizations 200 \
--compiler-version v0.8.26+commit.8a97fa7a \
--constructor-args $(cast abi-encode "constructor(address _pragmaCaller, uint256 _pairId)" $PRAGMA_CALLER_DEPLOYED_ADDRESS 18669995996566340)
```

#### CallerExample

```shell
forge create \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY \
src/CallerExample.sol:CallerExample \
--constructor-args $PRAGMA_CALLER_DEPLOYED_ADDRESS
```

and verify with:

```sh
forge verify-contract $EXAMPLE_ADDRESS src/CallerExample.sol:CallerExample \
--rpc-url $RPC_URL \
--verifier-url $ETHERSCAN_VERIFY_URL \
--etherscan-api-key "verifyContract" \
--num-of-optimizations 200 \
--compiler-version v0.8.26+commit.8a97fa7a \
--constructor-args $(cast abi-encode "constructor(uint256 pragmaOracleAddress)" $PRAGMA_CALLER_DEPLOYED_ADDRESS)
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
