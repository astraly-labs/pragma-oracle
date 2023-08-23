# %% Imports
import logging
from asyncio import run
from math import ceil, log

from scripts.utils.constants import (
    COMPILED_CONTRACTS,
    currencies,
    NETWORK,
    pairs,
)
from scripts.utils.starknet import (
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_eth_contract,
    get_starknet_account,
    invoke,
    deploy_v2,
    declare_v2
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(
        f"ℹ️  Connected to CHAIN_ID { chain_id }"
    )
    account = await get_starknet_account()
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    class_hash = {
        contract["contract_name"]: await declare_v2(contract["contract_name"])
        for contract in COMPILED_CONTRACTS
    }
    dump_declarations(class_hash)

    # %% Deployments
    class_hash = get_declarations()
    await get_eth_contract()

    deployments = {}
    deployments["pragma_PublisherRegistry"] = await deploy_v2(
        "pragma_PublisherRegistry",
        account.address,  # owner
    )

    new_currencies = [currency.to_dict() for currency in currencies]
    new_pairs = [pair.to_dict() for pair in pairs]

    deployments["pragma_Oracle"] = await deploy_v2(
        "pragma_Oracle", # 
        account.address, # admin
        deployments["pragma_PublisherRegistry"]["address"],  # publisher_registry
        new_currencies, 
        new_pairs, 
    )

    dump_deployments(deployments)

    logger.info("✅ Deployment Completed")


if __name__ == "__main__":
    run(main())
