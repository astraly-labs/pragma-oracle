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
)
from pragma.core.types import Currency, Pair
import argparse
import os
from dotenv import load_dotenv

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


load_dotenv()
currencies_to_add = [
    # Currency(
    #     "STRK",
    #     18,
    #     False,
    #     0x04718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D,
    #     0xCA14007EFF0DB1F8135F4C25B34DE49AB0D42766,
    # )
]
pairs_to_add = [
    # Pair("STRK/USD", "STRK", "USD"),
]

pairs_to_update = [
    Pair("WSTETH/ETH", "WSTETH", "ETH"),
    Pair("WSTETH/USD", "WSTETH", "USD"),
]


async def main():
    parser = argparse.ArgumentParser(description="Deploy contracts to Katana")
    parser.add_argument(
        "--port", type=int, help="Port number(not required)", required=False
    )
    args = parser.parse_args()
    if os.getenv("STARKNET_NETWORK") == "katana" and args.port is None:
        logger.warning(f"⚠️  --port not set, defaulting to 5050")
        args.port = 5050
    # Add Currencies
    for currency in currencies_to_add:
        print(currency.to_dict())
        tx_hash = await invoke(
            "pragma_Oracle", "add_currency", currency.serialize(), port=args.port
        )
        logger.info(f"Added currency {currency} with tx hash {hex(tx_hash)}")

    # Update Pairs
    for pair in pairs_to_update:
        tx_hash = await invoke(
            "pragma_Oracle", "update_pair", [pair.id] + pair.serialize(), port=args.port
        )
        logger.info(f"Updated pair {pair} with tx hash {hex(tx_hash)}")

    # Add Pairs
    for pair in pairs_to_add:
        tx_hash = await invoke(
            "pragma_Oracle", "add_pair", pair.serialize(), port=args.port
        )
        logger.info(f"Added pair {pair} with tx hash {hex(tx_hash)}")


if __name__ == "__main__":
    run(main())
