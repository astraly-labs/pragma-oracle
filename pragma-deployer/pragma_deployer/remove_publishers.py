import os
import asyncio
import click
import logging

from typing import Optional

from dotenv import load_dotenv
from pragma_utils.logger import setup_logging

from pragma_deployer.utils.starknet import (
    invoke,
    str_to_felt,
)

load_dotenv()

logger = logging.getLogger(__name__)

PUBLISHERS = [
    "SKYNET_TRADING",
    "FOURLEAF",
    "NETHERMIND",
    "FLOWDESK",
    "CRYPTOMENTUM",
]


async def main(port: Optional[int]) -> None:
    """
    Main function to remove publishers from the Publisher Registry.
    """
    for publisher in PUBLISHERS:
        await invoke(
            "pragma_PublisherRegistry",
            "remove_publisher",
            [str_to_felt(publisher)],
            port=port,
        )
        logger.info(f"ℹ️ Removed publisher {publisher}.")


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
    CLI entrypoint to remove publishers from the Publisher Registry.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "katana" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Katana.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
