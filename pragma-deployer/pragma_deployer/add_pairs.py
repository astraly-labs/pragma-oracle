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

CURRENCIES_TO_ADD = [
    Currency(
        "DPI",
        18,
        False,
        0,
        0x1494CA1F11D487C2BBE4543E90080AEBA4BA3C2B,
    )
]
PAIRS_TO_ADD = [
    Pair("DPI/USD", "DPI", "USD"),
]

PAIRS_TO_UPDATE = [
    # Pair("WSTETH/ETH", "WSTETH", "ETH"),
    # Pair("WSTETH/USD", "WSTETH", "USD"),
]


async def main(port: Optional[int]) -> None:
    """
    Main function to add currencies and pairs, and update pairs.
    """
    # Add Currencies
    for currency in CURRENCIES_TO_ADD:
        print(currency.to_dict())
        tx_hash = await invoke(
            "pragma_Oracle", "add_currency", currency.serialize(), port=port
        )
        logger.info(f"Added currency {currency} with tx hash {hex(tx_hash)}")

    # Update Pairs
    for pair in PAIRS_TO_UPDATE:
        tx_hash = await invoke(
            "pragma_Oracle", "update_pair", [pair.id] + pair.serialize(), port=port
        )
        logger.info(f"Updated pair {pair} with tx hash {hex(tx_hash)}")

    # Add Pairs
    for pair in PAIRS_TO_ADD:
        tx_hash = await invoke("pragma_Oracle", "add_pair", pair.serialize(), port=port)
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
    help="Port number (required for Katana network)",
)
def cli_entrypoint(log_level: str, port: Optional[int]) -> None:
    """
    CLI entrypoint to add currencies and pairs, and update pairs.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "katana" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Katana.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
