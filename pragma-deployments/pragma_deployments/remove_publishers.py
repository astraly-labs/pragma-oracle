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
    declare_v2,
    call,
    get_deployments,
    str_to_felt,
)
import os 
import argparse 
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

publishers = [
        "SKYNET_TRADING",
        "FOURLEAF",
        "NETHERMIND",
        "FLOWDESK",
        "CRYPTOMENTUM",
    ]

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
    for publisher in publishers:
        await invoke(
            "pragma_PublisherRegistry",
            "remove_publisher",
            [str_to_felt(publisher)], 
            port = args.port)
        logger.info(f"ℹ️ Removed publisher {publisher}.")


if __name__ == "__main__":
    run(main())
