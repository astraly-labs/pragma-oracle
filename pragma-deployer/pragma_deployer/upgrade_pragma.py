# %% Imports
import logging
from asyncio import run
from math import ceil, log

from scripts.utils.constants import (
    COMPILED_CONTRACTS,
    NETWORK,
)
from scripts.utils.starknet import (
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_eth_contract,
    get_starknet_account,
    invoke,
    deploy_v2,
    declare_v2,
    call,
)
import os 
import argparse 
from dotenv import load_dotenv


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
    logger.info(f"ℹ️  Connected to CHAIN_ID { chain_id }")

    account = await get_starknet_account(port = args.port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as upgrader")

    declarations = get_declarations()
    cur_class_hash = declarations["pragma_Oracle"]
    logger.info(f"ℹ️  Current implementation hash: {cur_class_hash}")

    new_implementation_hash = await declare_v2("pragma_Oracle", port = args.port)
    logger.info(f"ℹ️  New implementation hash: {new_implementation_hash}")

    tx_hash = await invoke("pragma_Oracle", "upgrade", [new_implementation_hash], port = args.port)

    declarations["pragma_Oracle"] = new_implementation_hash
    dump_declarations(declarations)

    logger.info(f"Upgraded the oracle contract with tx {hex(tx_hash)}")

    logger.info("✅ Upgrade Completed")


if __name__ == "__main__":
    run(main())
