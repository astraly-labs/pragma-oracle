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
    dump_deployments,
    get_deployments,
    get_starknet_account,
    deploy_v2,
)

load_dotenv()

logger = logging.getLogger(__name__)


async def main(port: Optional[int]) -> None:
    """
    Main function to deploy Summary Stats contract to Starknet.
    """
    # Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID {chain_id}")
    account = await get_starknet_account(port=port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    # Deployment
    deployments = get_deployments()
    deployments["pragma_SummaryStats"] = await deploy_v2(
        "pragma_SummaryStats",
        int(deployments["pragma_Oracle"]["address"], 16),  # oracle address
        port=port,
    )

    dump_deployments(deployments)

    logger.info("✅ Summary Stats Deployment Completed")


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
    CLI entrypoint to deploy Summary Stats contract to Starknet.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "devnet" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Devnet.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
