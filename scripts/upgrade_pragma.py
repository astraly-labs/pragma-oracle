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
    call
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
admin_address = 0x02356B628D108863BAF8644C945D97BAD70190AF5957031F4852D00D0F690A77


# %% Main
async def main():
    # %% Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(
        f"ℹ️  Connected to CHAIN_ID { chain_id }"
    )
    new_implementation_hash =await declare_v2('pragma_Oracle')
    tx_hash = await invoke(
                "pragma_Oracle", "upgrade", [new_implementation_hash]
            )
    logger.info(f"Upgaded the oracle contract with tx {hex(tx_hash)}")
    logger.info("✅ Upgrade Completed")


if __name__ == "__main__":
    run(main())
