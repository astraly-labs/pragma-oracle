# Pragma

**Pragma, Starknet's native provable oracle.**

What's Pragma ?
---

Pragma is a decentralized oracle built natively on Starknet. It leverages cairo to make data feeds computation fully trustless.

-  Pragma is built from the ground up to remove any trust assumptions in current oracles' design.
There isn't any off-chain infrastructure, raw-data is directly pushed on-chain by *whitelisted* data providers. Then the aggregation happens at the smart contract level.
- Pragma offers a top-notch developer experience, reviewed by key actors of DeFi on Starknet. The goal is to make the life of DeFi protocols as easy as possible.

Overview
---

- <a href="/src/account">Account contract</a> mostly use for testing purposes and as a reference.
- <a href="/src/admin">Admin contract</a> will be replaced by Argent's multisig as it gets released.
- <a href="/src/entry">Entry & Data Structures</a> defines data structures used within the protocol along with generic aggregations methods. It is designed from the ground up to ensure that adding new entry types is done seamlessly without involving any breaking changes.
- <a href="/src/admin">Operations</a> defines a few utilities libraries (time series, sorting, bits manipulation) that will be used for different aggregation methods and optimizing storage operations.
- <a href="/src/admin">Oracle</a> is the main entrypoint of the protocol. It is the contract that end developers will interact with to fetch any kind of data. It's been thought and built for retro-compatibility and heavily leverages unique aspects of Cairo, notably enums, traits and generics.
- <a href="/src/admin">Publisher Registry</a> handles the registration of different publishers along with the sources they are allowed to push data from.
- <a href="/src/admin">Summary Stats</a> acts as a proxy contract for more sophisticated kind of data aggregation such as *volatility* and *mean*.

## Testing

- <a href="/src/tests">Test suite</a>, unit tests are provided under the functions' implementations directly whereas full flow integration tests lie within this test suite. It uses cairo-test for now and test thoroughly for any edge case.

A few key testing features are missing such as *fuzzing* and proper hooks, mocking cheatcodes. This will come as cairo tooling matures and improves.

Documentation
---

More extensive documentation can be found on our [official website](https://docs.pragmaoracle.com/).


Deployment addresses
---

This repo will gradually replace the previous Pragma implementation in Cairo 0 which you can find [here](https://github.com/Astraly-Labs/pragma-contracts).

**Starknet Testnet**
- Oracle : [0x1ab2b1d9d084ed2c9fe185ac32b3bc7fa42f85e129b97459b4fe315f4247978](https://goerli.voyager.online/contract/0x01ab2b1d9d084ed2c9fe185ac32b3bc7fa42f85e129b97459b4fe315f4247978)
- Publisher Registry : [0x1d28af342cbb06eb1e5a80dae0034f6a0ca0fb0d580cc4e0799cc43c11f99e9](https://goerli.voyager.online/contract/0x1d28af342cbb06eb1e5a80dae0034f6a0ca0fb0d580cc4e0799cc43c11f99e9)
- Summary Stats : [0x7692d324980c3c7ad72198ba7a42487fd057dd97b8c89a8d71e48c28e3b8657](https://goerli.voyager.online/contract/0x7692d324980c3c7ad72198ba7a42487fd057dd97b8c89a8d71e48c28e3b8657)

**Starknet Mainnet**

🔜

Local Deployment
---

Prerequisites:
- [Scarb](https://docs.swmansion.com/scarb/)
- Python >= 3.9
- [Poetry](https://python-poetry.org/)

1. Install dependencies

```bash
poetry install
```

2. Compile contracts

```bash
scarb build
```

3. Deploy contracts & setup

Make sure your local devnet is running, see latest instructions [here](https://0xspaceshard.github.io/starknet-devnet/docs/intro).

You can also specify a different network by setting `STARKNET_NETWORK` to a different value e.g `testnet | mainnet`.

```bash

STARKNET_NETWORK=devnet poetry run python3 scripts/deploy_pragma.py
STARKNET_NETWORK=devnet poetry run python3 scripts/deploy_summary_stats.py
STARKNET_NETWORK=devnet poetry run python3 scripts/register_publishers.py

```

Once the contracts are declared/deployed you'll find them under the `deployments/` folder at the root of the repo.


Questions and feedback
---

For any question or feedback you can send an email to <matthias@pragmaoracle.com>

License
---

The code is under the GNU AFFERO GENERAL PUBLIC LICENSE v3.0, see <a href="./LICENSE">LICENSE</a>.
