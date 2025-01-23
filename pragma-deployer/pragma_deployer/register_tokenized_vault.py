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
    invoke,
    call,
    str_to_felt,
)

load_dotenv()

logger = logging.getLogger(__name__)

# Tokens to register
TOKENS_TO_REGISTER = [
    {
        "name": "XSTRK",
        "address": 0x28d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a,
    },
    # {
    #     "name": "SSTRK",
    #     "address": 0x076c4b7bb1ce744e4aae2278724adedd4906ab89998623fe1715877ecb583bde,
    # },
    # {
    #     "name": "KSTRK",
    #     "address": 0x045cd05ee2caaac3459b87e5e2480099d201be2f62243f839f00e10dde7f500c,
    # },
]

async def main(port: Optional[int]) -> None:
    """
    Main function to register tokenized vaults.
    """
    logger.info("🚀 Registering tokenized vaults...")
    
    for token in TOKENS_TO_REGISTER:
        tx_hash = await invoke(
            "pragma_Oracle",
            "register_tokenized_vault",
            [token["name"], token["address"]],
            port=port,
        )
        logger.info(f"Registered tokenized vault {token['name']} with tx {hex(tx_hash)}")
        await asyncio.sleep(1)

    logger.info("ℹ️ Tokenized vault registration completed.")


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
    CLI entrypoint to register a tokenized vault.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "devnet" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Devnet.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
