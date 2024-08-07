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
    dump_deployments,
    get_deployments,
    get_starknet_account,
    deploy_v2,
    declare_v2,
    dump_declarations,
)

load_dotenv()

logger = logging.getLogger(__name__)


async def main(port: Optional[int]) -> None:
    """
    Main function to deploy Example Randomness contract.
    """
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID {chain_id}")
    account = await get_starknet_account(port=port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    if port is not None:
        class_hash = {
            contract["contract_name"]: await declare_v2(
                contract["contract_name"], port=port
            )
            for contract in COMPILED_CONTRACTS
        }
        dump_declarations(class_hash)

    # Deployment
    deployments = get_deployments()
    deployments["pragma_ExampleRandomness"] = await deploy_v2(
        "pragma_ExampleRandomness",
        int(deployments["pragma_Randomness"]["address"], 16),
        port=port,
    )

    dump_deployments(deployments)

    logger.info("✅ Example Randomness Deployment Completed")


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
    CLI entrypoint to deploy Example Randomness contract.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "devnet" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Devnet.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
