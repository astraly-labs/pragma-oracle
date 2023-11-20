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
    for publisher in publishers:
        await invoke(
            "pragma_PublisherRegistry",
            "remove_publisher",
            [str_to_felt(publisher)])
        logger.info(f"ℹ️ Removed publisher {publisher}.")


if __name__ == "__main__":
    run(main())
