# %% Imports
import logging
from asyncio import run
from math import ceil, log
import os
from dotenv import load_dotenv
import argparse
from scripts.utils.constants import (
    COMPILED_CONTRACTS,
    currencies,
    NETWORK,
    pairs,
    ETH_TOKEN_ADDRESS,
)
from scripts.utils.starknet import (
    dump_deployments,
    get_deployments,
    get_starknet_account,
    deploy_v2,
    declare_v2,
    dump_declarations,
)

load_dotenv()

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    parser = argparse.ArgumentParser(description="Deploy contracts to Katana")
    parser.add_argument(
        "--port", type=int, help="Port number(not required)", required=False
    )
    args = parser.parse_args()
    if os.getenv("STARKNET_NETWORK") == "katana" and args.port is None:
        logger.warning(f"⚠️  --port not set, defaulting to 5050")
        args.port = 5050
    # %% Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID { chain_id }")
    account = await get_starknet_account(port=args.port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    if args.port is not None:
        class_hash = {
            contract["contract_name"]: await declare_v2(
                contract["contract_name"], port=args.port
            )
            for contract in COMPILED_CONTRACTS
        }
        dump_declarations(class_hash)

    # %% Deployment

    deployments = get_deployments()
    deployments["pragma_Randomness"] = await deploy_v2(
        "pragma_Randomness",
        int(os.getenv("TESTNET_ACCOUNT_ADDRESS"), 16),
        2061139992776959994838533810929826594222370735645675137341826408353556487187,
        int(ETH_TOKEN_ADDRESS, 16),
        int(deployments["pragma_Oracle"]["address"], 16),
        port=args.port,
    )
    # deployments = get_deployments()
    # deployments["pragma_ExampleRandomness"] = await deploy_v2(
    #     "pragma_ExampleRandomness",
    #     int("0x5faa12cb652c1ec3cf667e651d001d8155653d8d8ad2d1ab92bd965e081a605", 16),
    #     port=args.port,
    # )

    dump_deployments(deployments)

    logger.info("✅ Randomness Deployment Completed")


if __name__ == "__main__":
    run(main())
