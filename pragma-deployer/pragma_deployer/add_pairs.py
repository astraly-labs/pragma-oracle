import os
import asyncio
import click
import logging

from typing import Optional

from dotenv import load_dotenv
from pragma_sdk.common.types.pair import Pair
from pragma_sdk.common.types.currency import Currency
from pragma_utils.logger import setup_logging

from pragma_deployer.utils.starknet import (
    invoke,
)

logger = logging.getLogger(__name__)

load_dotenv()

FIXED = Currency(
    "FIXEDRESERVED",
    18,
    0,
    0x0,
    0x0000000000000000000000000000000000000000,
)
SSTRK = Currency(
    "SSTRK",
    18,
    0,
    0x28d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a,
    0x0000000000000000000000000000000000000000,
)
RETH = Currency(
    "RETH",
    18,
    0,
    0x0319111a5037cbec2b3e638cc34a3474e2d2608299f3e62866e9cc683208c610,
    0xae78736cd615f374d3085123a210448e74fc6393,
)
USD = Currency("USD", 8, 1, 0, 0)
XSTRK = Currency(
    "XSTRK",
    18,
    0,
    0x028d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a,
    0x0000000000000000000000000000000000000000,
)
DOG = Currency(
    "DOG",
    5,
    0,
    0x0,
    0x0000000000000000000000000000000000000000,
)
CONVERSION_SSTRK = Currency(
    "CONVERSION_SSTRK",
    18,
    0,
    0x0000000000000000000000000000000000000000,
    0x0000000000000000000000000000000000000000,
)
XWBTC = Currency(
    "CONVERSION_xWBTC",
    8,
    0,
    0x6a567e68c805323525fe1649adb80b03cddf92c23d2629a6779f54192dffc13,
    0x0000000000000000000000000000000000000000,
)
XTBTC = Currency(
    "CONVERSION_xtBTC",
    18,
    0,
    0x43a35c1425a0125ef8c171f1a75c6f31ef8648edcc8324b55ce1917db3f9b91,
    0x0000000000000000000000000000000000000000,
)
XLBTC = Currency(
    "CONVERSION_xLBTC",
    8,
    0,
    0x7dd3c80de9fcc5545f0cb83678826819c79619ed7992cc06ff81fc67cd2efe0,
    0x0000000000000000000000000000000000000000,
)
XSBTC = Currency(
    "CONVERSION_xsBTC",
    18,
    0,
    0x580f3dc564a7b82f21d40d404b3842d490ae7205e6ac07b1b7af2b4a5183dc9,
    0x0000000000000000000000000000000000000000,
)

# BTC LST pairs
xwbtc_usd_pair = Pair(XWBTC, USD)
xtbtc_usd_pair = Pair(XTBTC, USD)
xlbtc_usd_pair = Pair(XLBTC, USD)
xsbtc_usd_pair = Pair(XSBTC, USD)

CURRENCIES_TO_ADD = [XWBTC, XTBTC, XLBTC, XSBTC]

PAIRS_TO_ADD = [xwbtc_usd_pair, xtbtc_usd_pair, xlbtc_usd_pair, xsbtc_usd_pair]

PAIRS_TO_UPDATE = [
#     {
#     "pair_id": "1629317993172502401860",
#     "pair": ["1629317993172502401860", USD.id, XSTRK.id]
# }
    # Pair(XSTRK, USD),
    # Pair("SSTRK/USD", "SSTRK", "USD"),
    # Pair("WSTETH/USD", "WSTETH", "USD"),
]


async def main(port: Optional[int]) -> None:
    """
    Main function to add currencies and pairs, and update pairs.
    """
    # Add Currencies
    for currency in CURRENCIES_TO_ADD:
        tx_hash = await invoke(
            "pragma_Oracle",
            "add_currency",
            currency.serialize(),
            port=port,
        )
        logger.info(f"Added currency {currency} with tx hash {hex(tx_hash)}")

    # Update Pairs
    for pair in PAIRS_TO_UPDATE:
        tx_hash = await invoke(
            "pragma_Oracle",
            "update_pair",
            [pair["pair_id"]] + pair["pair"],
            port=port,
        )
        logger.info(f"Updated pair {pair} with tx hash {hex(tx_hash)}")

    # Add Pairs
    for pair in PAIRS_TO_ADD:
        tx_hash = await invoke(
            "pragma_Oracle",
            "add_pair",
            pair.serialize(),
            port=port,
        )
        logger.info(f"Added pair {pair} with tx hash {hex(tx_hash)}")


@click.command()
@click.option(
    "--log-level",
    type=click.Choice(
        ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], case_sensitive=False
    ),
    default="INFO",
    help="Set the logging level",
)
@click.option(
    "-p",
    "--port",
    type=click.IntRange(min=0),
    required=False,
    help="Port number (required for Devnet network)",
)
def cli_entrypoint(log_level: str, port: Optional[int]) -> None:
    """
    CLI entrypoint to add currencies and pairs, and update pairs.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "devnet" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Devnet.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
