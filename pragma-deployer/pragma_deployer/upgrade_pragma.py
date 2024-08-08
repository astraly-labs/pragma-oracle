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
    dump_declarations,
    get_declarations,
    get_starknet_account,
    invoke,
    declare_v2,
)

load_dotenv()

logger = logging.getLogger(__name__)


async def main(port: Optional[int]) -> None:
    """
    Main function to upgrade the Oracle contract.
    """
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID {chain_id}")

    account = await get_starknet_account(port=port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as upgrader")

    declarations = get_declarations()
    cur_class_hash = declarations["pragma_Oracle"]
    logger.info(f"ℹ️  Current implementation hash: {hex(cur_class_hash)}")

    new_implementation_hash = await declare_v2("pragma_Oracle", port=port)
    logger.info(f"ℹ️  New implementation hash: {hex(new_implementation_hash)}")

    tx_hash = await invoke(
        "pragma_Oracle", "upgrade", [new_implementation_hash], port=port
    )

    declarations["pragma_Oracle"] = new_implementation_hash
    dump_declarations(declarations)

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
    CLI entrypoint to upgrade the Oracle contract.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "devnet" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Devnet.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
