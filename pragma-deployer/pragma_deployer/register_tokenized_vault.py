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
    # {
    #     "name": "XSTRK",
    #     "address": 0x28d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a,
    # },
    # BTC LST tokens
    # {
    #     "name": "CONVERSION_XWBTC",
    #     "underlying_token": "BTC",
    #     "address": 0x6a567e68c805323525fe1649adb80b03cddf92c23d2629a6779f54192dffc13,
    # },
    # {
    #     "name": "CONVERSION_XTBTC",
    #     "underlying_token": "BTC",
    #     "address": 0x43a35c1425a0125ef8c171f1a75c6f31ef8648edcc8324b55ce1917db3f9b91,
    # },
    {
        "name": "CONVERSION_XLBTC",
        "underlying_token": "BTC",
        "address": 0x7dd3c80de9fcc5545f0cb83678826819c79619ed7992cc06ff81fc67cd2efe0,
    },
    # {
    #     "name": "CONVERSION_XSBTC",
    #     "underlying_token": "BTC",
    #     "address": 0x580f3dc564a7b82f21d40d404b3842d490ae7205e6ac07b1b7af2b4a5183dc9,
    # },
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
            [token["name"], token["underlying_token"], token["address"]],
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
