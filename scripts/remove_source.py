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
    str_to_felt
)

from pragma.core.types import DataType, DataTypes
from starknet_py.serialization.data_serializers.enum_serializer import EnumSerializer


logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

pair_ids = ['BTC/USD', 'ETH/USD', 'BTC/EUR','WBTC/USD','WBTC/BTC','USDC/USD','USDT/USD','DAI/USD','R/USD','LORDS/USD','WSTETH/USD']


# %% Main
async def main():
    # %% Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID { chain_id }")

    account = await get_starknet_account()
    logger.info(f"ℹ️  Using account {hex(account.address)} as upgrader")

    for pair_id in pair_ids:

        if isinstance(pair_id, str):
            pair_id = str_to_felt(pair_id)
        elif not isinstance(pair_id, int):
            raise TypeError(
                "Pair ID must be string (will be converted to felt) or integer"
            )

        tx_hash = await invoke("pragma_Oracle", "remove_source", ["AVNU", 0, pair_id])
        logger.info(f"Removed source for pair {pair_id} with tx {hex(tx_hash)}")

    logger.info(f"Upgraded the oracle contract with tx {hex(tx_hash)}")

    logger.info("✅ Upgrade Completed")


if __name__ == "__main__":
    run(main())
