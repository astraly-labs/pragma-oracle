import asyncio
import logging
import os
import time
from typing import List

from pragma_deployer.utils.constants import NETWORK
from pragma_sdk.common.types.pair import Pair
from pragma_sdk.common.types.entry import Entry, SpotEntry, FutureEntry
from pragma_sdk.common.types.currency import Currency
from pragma_sdk.onchain.client import PragmaOnChainClient


logger = logging.getLogger(__name__)

FIXED = Currency(
    "FIXEDRESERVED",
    18,
    0,
    0x0,
    0x0000000000000000000000000000000000000000,
)

USD = Currency("USD", 8, 1, 0, 0)
pair = Pair(FIXED, USD)


async def publish_data():

    print(NETWORK["account_address"])

    publisher_client = PragmaOnChainClient(
        account_private_key=NETWORK["private_key"],
        account_contract_address= NETWORK["account_address"],
        network=os.environ["STARKNET_NETWORK"],  # ENV var set to `sepolia | mainnet`
    )

    # Use your own custom logic
    _entries = [ 
        SpotEntry(pair_id=pair.id, price=int(1e8), timestamp=int(time.time()), source="STARKNET", publisher="PRAGMA", volume=0)
    ]
    res = await publisher_client.publish_many(_entries)

    print("success ", hex(res[0].hash))


if __name__ == "__main__":
    asyncio.run(publish_data())
