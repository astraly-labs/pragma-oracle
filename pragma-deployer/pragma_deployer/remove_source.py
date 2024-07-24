import os
import asyncio
import click
import logging

from typing import Optional

from dotenv import load_dotenv
from pragma_utils.logger import setup_logging

from pragma_deployer.utils.constants import (
    NETWORK,
)
from pragma_deployer.utils.starknet import (
    get_starknet_account,
    invoke,
    str_to_felt,
)

load_dotenv()

logger = logging.getLogger(__name__)

PAIR_IDS = [
    "BTC/USD",
    "ETH/USD",
    "BTC/EUR",
    "WBTC/USD",
    "WBTC/BTC",
    "USDC/USD",
    "USDT/USD",
    "DAI/USD",
    "R/USD",
    "LORDS/USD",
    "WSTETH/USD",
]


async def main(port: Optional[int]) -> None:
    """
    Main function to remove AVNU source for specified pairs.
    """
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID {chain_id}")

    account = await get_starknet_account(port=port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as upgrader")

    for pair_id in PAIR_IDS:
        pair_id_felt = str_to_felt(pair_id) if isinstance(pair_id, str) else pair_id
        if not isinstance(pair_id_felt, int):
            raise TypeError(
                "Pair ID must be string (will be converted to felt) or integer"
            )

        tx_hash = await invoke(
            "pragma_Oracle", "remove_source", ["AVNU", 0, pair_id_felt], port=port
        )
        logger.info(f"Removed source for pair {pair_id} with tx {hex(tx_hash)}")

    logger.info(f"Upgraded the oracle contract with tx {hex(tx_hash)}")
    logger.info("✅ Upgrade Completed")


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
    CLI entrypoint to remove AVNU source for specified pairs.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "devnet" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Devnet.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
