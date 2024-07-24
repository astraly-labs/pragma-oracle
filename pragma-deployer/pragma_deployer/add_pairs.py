import os
import asyncio
import click
import logging

from typing import Optional

from dotenv import load_dotenv
from pragma_sdk.common.types.pair import Pair
from pragma_sdk.common.types.currency import Currency
from pragma_sdk.common.utils import str_to_felt
from pragma_utils.logger import setup_logging

from pragma_deployer.utils.starknet import (
    invoke,
)

logger = logging.getLogger(__name__)

load_dotenv()
ETH = Currency(
    "ETH",
    18,
    0,
    0x049D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7,
    0x0000000000000000000000000000000000000000,
)
DAI = Currency(
    "DAI",
    18,
    0,
    0x001108CDBE5D82737B9057590ADAF97D34E74B5452F0628161D237746B6FE69E,
    0x6B175474E89094C44DA98B954EEDEAC495271D0F,
)
CURRENCIES_TO_ADD = [DAI]
pair = Pair(ETH, DAI)
pair.id = str_to_felt("ETH/DAI")
PAIRS_TO_ADD = [pair]

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
