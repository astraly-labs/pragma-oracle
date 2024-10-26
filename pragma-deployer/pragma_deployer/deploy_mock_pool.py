import os
import asyncio
import click
import logging

from typing import Optional

from dotenv import load_dotenv
from pragma_utils.logger import setup_logging

from pragma_deployer.utils.constants import (
    COMPILED_CONTRACTS,
    NETWORK,
)
from pragma_deployer.utils.starknet import (
    declare_v2,
    dump_declarations,
    dump_deployments,
    get_deployments,
    get_starknet_account,
    deploy_v2,
)

load_dotenv()

logger = logging.getLogger(__name__)


async def main(port: Optional[int]) -> None:
    """
    Main function to deploy the mock pool to Starknet.
    """
    # Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID {chain_id}")
    account = await get_starknet_account(port=port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    # Declaration
    class_hash = {
        contract["contract_name"]: await declare_v2(contract["contract_name"], port)
        for contract in COMPILED_CONTRACTS
    }
    dump_declarations(class_hash)

    # Deployment
    deployments = get_deployments()
    deployments["pragma_MockPool"] = await deploy_v2(
        "pragma_Pool",
        int(
            "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7", 16
        ),  # ETH
        int(
            "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac", 16
        ),  # BTC
        port=port,
    )

    dump_deployments(deployments)

    logger.info("✅Mock Pool Deployment Completed")


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
    CLI entrypoint to deploy the Mock Pool contract to Starknet.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "devnet" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Devnet.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
