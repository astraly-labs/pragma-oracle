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
import os 
import argparse
from dotenv import load_dotenv
from scripts.utils.starknet import (
    dump_deployments,
    get_deployments,
    get_starknet_account,
    deploy_v2,
    declare_v2,
    dump_declarations
)

load_dotenv()
logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    parser = argparse.ArgumentParser(description="Deploy contracts to Katana")
    parser.add_argument('--port', type=int, help='Port number(not required)', required=False)
    args = parser.parse_args()
    if os.getenv("STARKNET_NETWORK") == "katana" and args.port is None:
        logger.warning(
            f"⚠️  --port not set, defaulting to 5050"
        )
        args.port = 5050
    # %% Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(
        f"ℹ️  Connected to CHAIN_ID { chain_id }"
    )
    account = await get_starknet_account(port = args.port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")
    
    if args.port is not None:
        class_hash = {
            contract["contract_name"]: await declare_v2(contract["contract_name"],port = args.port)
            for contract in COMPILED_CONTRACTS
        }
        dump_declarations(class_hash)

    # %% Deployment

    deployments = get_deployments()
    deployments["pragma_ExampleRandomness"] = await deploy_v2(
        "pragma_ExampleRandomness",
        int(deployments["pragma_Randomness"]["address"], 16),
        port = args.port
    )

    dump_deployments(deployments)

    logger.info("✅ Example Randomness Deployment Completed")


if __name__ == "__main__":
    run(main())
