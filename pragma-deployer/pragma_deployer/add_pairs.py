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
USD = Currency("USD", 8, 1, 0, 0)
XSTRK = Currency(
    "XSTRK",
    18,
    0,
    0x028d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a,
    0x0000000000000000000000000000000000000000,
)
CONVERSION_XSTRK = Currency(
    "CONVERSION_XSTRK",
    18,
    0,
    0x0000000000000000000000000000000000000000,
    0x0000000000000000000000000000000000000000,
)
pair = Pair(CONVERSION_XSTRK, USD)


CURRENCIES_TO_ADD = [CONVERSION_XSTRK]

PAIRS_TO_ADD = [pair]

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
