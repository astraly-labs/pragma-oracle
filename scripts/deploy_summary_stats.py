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
    deployments["pragma_SummaryStats"] = await deploy_v2(
        "pragma_SummaryStats",
        int(deployments["pragma_Oracle"]["address"], 16),  # oracle address
    )

    dump_deployments(deployments)

    logger.info("✅ Summary Stats Deployment Completed")


if __name__ == "__main__":
    run(main())
