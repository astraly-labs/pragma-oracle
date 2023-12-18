# %% Imports
import logging
from asyncio import run
from math import ceil, log
import argparse
from scripts.utils.constants import (
    COMPILED_CONTRACTS,
    currencies,
    NETWORK,
    pairs,
)
import os 
from dotenv import load_dotenv
from scripts.utils.starknet import (
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_eth_contract,
    get_starknet_account,
    invoke,
    deploy_v2,
    declare_v2,
    call
)

load_dotenv()
logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():

    #Retrieve port from parser
    parser = argparse.ArgumentParser(description="Deploy contracts to Katana")
    parser.add_argument('--port', type=int, help='Port number(not required)', required=False)
    args = parser.parse_args()
    if os.getenv("STARKNET_NETWORK") == "katana" and args.port is None:
        logger.warning(
            f"⚠️  --port not set, defaulting to 5050"
        )
        args.port = 5050
    # %% Declarations
    chain_id = NETWORK["chain_id"]
    print(f" the principal chain is : {chain_id}")
    logger.info(
        f"ℹ️  Connected to CHAIN_ID { chain_id }"
    )
    account = await get_starknet_account(port= args.port)
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    class_hash = {
        contract["contract_name"]: await declare_v2(contract["contract_name"], args.port)
        for contract in COMPILED_CONTRACTS
    }
    dump_declarations(class_hash)

    # %% Deployments
    class_hash = get_declarations()
    await get_eth_contract(port= args.port)

    deployments = {}
    deployments["pragma_PublisherRegistry"] = await deploy_v2(
        "pragma_PublisherRegistry",
        account.address,  # owner, 
        port =args.port
    )

    new_currencies = [currency.to_dict() for currency in currencies]
    new_pairs = [pair.to_dict() for pair in pairs]

    deployments["pragma_Oracle"] = await deploy_v2(
        "pragma_Oracle",
        account.address, # admin
        deployments["pragma_PublisherRegistry"]["address"],  # publisher_registry
        new_currencies, 
        new_pairs, 
        port =args.port
    )
   
    dump_deployments(deployments)

    logger.info("✅ Deployment Completed")


if __name__ == "__main__":
    run(main())
