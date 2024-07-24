import os
import asyncio
import click
import logging

from typing import Optional

from pragma_utils.logger import setup_logging

from pragma_deployer.utils.constants import (
    COMPILED_CONTRACTS,
    currencies,
    NETWORK,
    pairs,
)
from pragma_deployer.utils.starknet import (
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_eth_contract,
    get_starknet_account,
    declare_v2,
    deploy_v2,
)


logger = logging.getLogger(__name__)


async def main(port: Optional[int]) -> None:
    """
    Main function to deploy contracts to Starknet.
    """
    # Declarations
    chain_id = NETWORK["chain_id"]
    logger.info(f"ℹ️  Connected to CHAIN_ID {chain_id}")
    account = await get_starknet_account(port=port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    class_hash = {
        contract["contract_name"]: await declare_v2(contract["contract_name"], port)
        for contract in COMPILED_CONTRACTS
    }
    dump_declarations(class_hash)

    # Deployments
    class_hash = get_declarations()
    await get_eth_contract(port=port)

    deployments = {}
    deployments["pragma_PublisherRegistry"] = await deploy_v2(
        "pragma_PublisherRegistry",
        account.address,  # owner
        port=port,
    )

    new_currencies = [currency.to_dict() for currency in currencies]
    new_pairs = [pair.to_dict() for pair in pairs]

    deployments["pragma_Oracle"] = await deploy_v2(
        "pragma_Oracle",
        account.address,  # admin
        deployments["pragma_PublisherRegistry"]["address"],  # publisher_registry
        new_currencies,
        new_pairs,
        port=port,
    )
    dump_deployments(deployments)

    logger.info("✅ Deployment Completed")


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
    CLI entrypoint to deploy contracts to Starknet.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "katana" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Katana.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
