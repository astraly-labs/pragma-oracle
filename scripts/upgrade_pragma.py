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

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID { chain_id }")

    account = await get_starknet_account()
    logger.info(f"ℹ️  Using account {hex(account.address)} as upgrader")

    declarations = get_declarations()
    cur_class_hash = declarations["pragma_Oracle"]
    logger.info(f"ℹ️  Current implementation hash: {cur_class_hash}")

    new_implementation_hash = await declare_v2("pragma_Oracle")
    logger.info(f"ℹ️  New implementation hash: {new_implementation_hash}")

    tx_hash = await invoke("pragma_Oracle", "upgrade", [new_implementation_hash])

    declarations["pragma_Oracle"] = new_implementation_hash
    dump_declarations(declarations)

    logger.info(f"Uprgaded the oracle contract with tx {hex(tx_hash)}")

    logger.info("✅ Upgrade Completed")


if __name__ == "__main__":
    run(main())
