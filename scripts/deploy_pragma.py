# %% Imports
import logging
from asyncio import run
from math import ceil, log

from scripts.constants import (
    CHAIN_ID,
    COMPILED_CONTRACTS,
    RPC_CLIENT,
    currencies,
    pairs,
)
from scripts.utils.starknet import (
    declare,
    deploy,
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_eth_contract,
    get_starknet_account,
    invoke,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Declarations
    logger.info(
        f"ℹ️  Connected to CHAIN_ID {CHAIN_ID.value.to_bytes(ceil(log(CHAIN_ID.value, 256)), 'big')} "
        f"with RPC {RPC_CLIENT.url}"
    )
    account = await get_starknet_account()
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    class_hash = {
        contract["contract_name"]: await declare(contract["contract_name"])
        for contract in COMPILED_CONTRACTS
    }
    dump_declarations(class_hash)

    # %% Deployments
    class_hash = get_declarations()
    await get_eth_contract()

    deployments = {}
    deployments["publisher_registry"] = await deploy(
        "publisher_registry",
        account.address,  # owner
    )
    deployments["proxy"] = await deploy(
        "proxy",
        class_hash["oracle"],  # owner
    )

    dump_deployments(deployments)

    logger.info("⏳ Configuring Contracts...")
    await invoke(
        "proxy",
        "initializer",
        admin.address,  # admin
        deployments["publisher_registry"]["address"],  # publisher_registry
        currencies,
        pairs,
    )
    logger.info("✅ Configuration Complete")


if __name__ == "__main__":
    run(main())
