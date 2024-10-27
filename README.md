# Pragma

**Pragma, Starknet's native provable oracle.**

## What's Pragma ?

Pragma is a decentralized oracle built natively on Starknet. It leverages cairo to make data feeds computation fully trustless.

- Pragma is built from the ground up to remove any trust assumptions in current oracles' design.
  There isn't any off-chain infrastructure, raw-data is directly pushed on-chain by _whitelisted_ data providers. Then the aggregation happens at the smart contract level.
- Pragma offers a top-notch developer experience, reviewed by key actors of DeFi on Starknet. The goal is to make the life of DeFi protocols as easy as possible.

## Overview

- <a href="/src/account">Account contract</a> mostly use for testing purposes and as a reference.
- <a href="/src/admin">Ownable contract</a> used for access control.
- <a href="/src/entry">Entry & Data Structures</a> defines data structures used within the protocol along with generic aggregations methods. It is designed from the ground up to ensure that adding new entry types is done seamlessly without involving any breaking changes.
- <a href="/src/operations">Operations</a> defines a few utilities libraries (time series, sorting, bits manipulation) that will be used for different aggregation methods and optimizing storage operations.
- <a href="/src/oracle">Oracle</a> is the main entrypoint of the protocol. It is the contract that end developers will interact with to fetch any kind of data. It's been thought and built for retro-compatibility and heavily leverages unique aspects of Cairo, notably enums, traits and generics.
- <a href="/src/publisher_registry">Publisher Registry</a> handles the registration of different publishers along with the sources they are allowed to push data from.
- <a href="/src/compute_engines">Summary Stats</a> acts as a proxy contract for more sophisticated kind of data aggregation such as _volatility_ and _mean_.
- <a href="/src/randomness">Randomness</a> is the VRF requestor implementation, also includes an example on how to request random words.

## Testing

- <a href="/src/tests">Test suite</a>, unit tests are provided under the functions' implementations directly whereas full flow integration tests lie within this test suite. It uses cairo-test for now and test thoroughly for any edge case.

A few key testing features are missing such as _fuzzing_ and proper hooks, mocking cheatcodes. This will come as cairo tooling matures and improves.

## Documentation

More extensive documentation can be found on our [official website](https://docs.pragma.build/).

## Audit

Pragma Starknet has been peer-reviewed by many other key-projects in the industries.
It has also been audited by Nethermind, you can find the full report under the <a href='/audits'>audits</a> folder.

## Deployment addresses

This repo will gradually replace the previous Pragma implementation in Cairo 0 which you can find [here](https://github.com/Astraly-Labs/pragma-contracts).

**Starknet Sepolia**

- Oracle : [0x36031daa264c24520b11d93af622c848b2499b66b41d611bac95e13cfca131a](https://sepolia.voyager.online/contract/0x36031daa264c24520b11d93af622c848b2499b66b41d611bac95e13cfca131a)
- Publisher Registry : [0x1b08e27ab436cd491631156da5f3aa7ff04aee1e6ca925eb2ca84397c22b74d](https://sepolia.voyager.online/contract/0x1b08e27ab436cd491631156da5f3aa7ff04aee1e6ca925eb2ca84397c22b74d)
- Summary Stats : [0x54563a0537b3ae0ba91032d674a6d468f30a59dc4deb8f0dce4e642b94be15c](https://sepolia.voyager.online/contract/0x54563a0537b3ae0ba91032d674a6d468f30a59dc4deb8f0dce4e642b94be15c)
- VRF : [0x60c69136b39319547a4df303b6b3a26fab8b2d78de90b6bd215ce82e9cb515c](https://sepolia.voyager.online/contract/0x60c69136b39319547a4df303b6b3a26fab8b2d78de90b6bd215ce82e9cb515c)

**Starknet Mainnet**

- Oracle : [0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b](https://voyager.online/contract/0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b)
- Publisher Registry : [0x24a55b928496ef83468fdb9a5430fe031ac386b8f62f5c2eb7dd20ef7237415](https://voyager.online/contract/0x24a55b928496ef83468fdb9a5430fe031ac386b8f62f5c2eb7dd20ef7237415)
- Summary Stats : [0x49eefafae944d07744d07cc72a5bf14728a6fb463c3eae5bca13552f5d455fd](https://voyager.online/contract/0x49eefafae944d07744d07cc72a5bf14728a6fb463c3eae5bca13552f5d455fd)
- VRF : [0x4fb09ce7113bbdf568f225bc757a29cb2b72959c21ca63a7d59bdb9026da661](https://voyager.online/contract/0x4fb09ce7113bbdf568f225bc757a29cb2b72959c21ca63a7d59bdb9026da661)

**Pragma Devnet**

- Oracle : [0x5bec6ca0be39624d95818d17857428c9995d4db5ddd088aefbf218b6d280f2a](https://pragma-voyager.karnot.xyz/contract/0x5bec6ca0be39624d95818d17857428c9995d4db5ddd088aefbf218b6d280f2a)
- Publisher Registry :
[0x1051e6a2110d4b9d18344214180415f8d524867e42794f09e4ca975668db541](https://pragma-voyager.karnot.xyz/contract/0x1051e6a2110d4b9d18344214180415f8d524867e42794f09e4ca975668db541)

## Local Deployment

Prerequisites:

- [Scarb](https://docs.swmansion.com/scarb/)
- 3.12 <= Python < 3.13
- [Poetry](https://python-poetry.org/)

1. Compile contracts

```bash
cd pragma-oracle
scarb build
```

2. Install dependencies

```bash
cd ../pragma-deployer
python -m venv .venv && source .venv/bin/activate
poetry install
```

3. Setup env file

```bash
# Make sure you are in the pragma-deployer folder
cp .env.example .env
```

Populate the variables depending on where you wish to deploy.

4. Deploy contracts & setup

Make sure your local devnet is running, see latest instructions [here](https://0xspaceshard.github.io/starknet-devnet-rs/).

You can also specify a different network by setting `STARKNET_NETWORK` to a different value e.g `sepolia`, `mainnet` or `pragma_devnet`.

```bash

STARKNET_NETWORK=devnet poetry run deploy-pragma --port [DEVNET_PORT]
STARKNET_NETWORK=devnet poetry run deploy-summary-stats --port [DEVNET_PORT]
STARKNET_NETWORK=devnet poetry run register-publishers --port [DEVNET_PORT]

```

Once the contracts are declared/deployed you'll find them under the `deployments/` folder at the root of the repo.

## Questions and feedback

For any question or feedback you can send an email to <matthias@pragma.build>

## License

The code is under the MIT LICENSE, see <a href="./LICENSE">LICENSE</a>.
