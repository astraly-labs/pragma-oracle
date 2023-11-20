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
    dump_deployments,
    get_deployments,
    get_starknet_account,
    deploy_v2,
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

    # %% Deployment

    deployments = get_deployments()
    deployments["pragma_Randomness"] = await deploy_v2(
        "pragma_Randomness",
        int("0x03e437FB56Bb213f5708Fcd6966502070e276c093ec271aA33433b89E21fd31f", 16),
        int("0xfcfc1eda34191fdb06acb883c4b5d8a70db47711252c26d77094053160ba5e", 16),
    )

    dump_deployments(deployments)

    logger.info("✅ Randomness Deployment Completed")


if __name__ == "__main__":
    run(main())
