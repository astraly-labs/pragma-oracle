# source : https://github.com/kkrt-labs/kakarot/blob/main/scripts/utils/starknet.py
# adapted to work with cairo1 contracts

import json
import logging
from pathlib import Path

import requests
from caseconverter import snakecase
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account
from starknet_py.net.client_models import Call
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starkware.starknet.public.abi import get_selector_from_name

from starknet_py.common import create_casm_class, create_sierra_compiled_contract
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.hash.sierra_class_hash import compute_sierra_class_hash
from starknet_py.contract import Contract

from utils.constants import (
    BUILD_DIR,
    # CONTRACTS,
    DEPLOYMENTS_DIR,
    ETH_TOKEN_ADDRESS,
    NETWORK,
    GATEWAY_CLIENT,
    # SOURCE_DIR,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def int_to_uint256(value):
    value = int(value)
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return {"low": low, "high": high}


async def get_starknet_account(
    address=None,
    private_key=None,
) -> Account:
    address = address or NETWORK["account_address"]
    if address is None:
        raise ValueError(
            "address was not given in arg nor in env variable, see README.md#Deploy"
        )
    address = int(address, 16)
    private_key = private_key or NETWORK["private_key"]
    if private_key is None:
        raise ValueError(
            "private_key was not given in arg nor in env variable, see README.md#Deploy"
        )
    key_pair = KeyPair.from_private_key(int(private_key, 16))

    return Account(
        address=address,
        client=GATEWAY_CLIENT,
        chain=NETWORK["chain_id"],
        key_pair=key_pair,
    )


async def get_eth_contract() -> Contract:
    return Contract(
        ETH_TOKEN_ADDRESS,
        json.loads((Path("scripts") / "utils" / "erc20.json").read_text())["abi"],
        await get_starknet_account(),
    )


async def get_contract(contract_name) -> Contract:
    return Contract(
        get_deployments()[contract_name]["address"],
        json.loads(get_artifact(contract_name).read_text())["abi"],
        await get_starknet_account(),
    )

def dump_declarations(declarations):
    json.dump(
        {name: hex(class_hash) for name, class_hash in declarations.items()},
        open(DEPLOYMENTS_DIR / "declarations.json", "w"),
        indent=2,
    )


def get_declarations():
    return {
        name: int(class_hash, 16)
        for name, class_hash in json.load(
            open(DEPLOYMENTS_DIR / "declarations.json")
        ).items()
    }


def dump_deployments(deployments):
    json.dump(
        {
            name: {
                **deployment,
                "address": hex(deployment["address"]),
                "tx": hex(deployment["tx"]),
            }
            for name, deployment in deployments.items()
        },
        open(DEPLOYMENTS_DIR / "deployments.json", "w"),
        indent=2,
    )


def get_deployments():
    return json.load(open(DEPLOYMENTS_DIR / "deployments.json", "r"))


def get_artifact(contract_name):
    return BUILD_DIR / f"{contract_name}.json"


def get_alias(contract_name):
    return snakecase(contract_name)


def get_tx_url(tx_hash: int) -> str:
    return f"{NETWORK['explorer_url']}/tx/0x{tx_hash:064x}"

def get_sierra_artifact(contract_name):
    return BUILD_DIR / f"{contract_name}.sierra.json"

def get_casm_artifact(contract_name):
    return BUILD_DIR / f"{contract_name}.casm.json"

def get_abi(contract_name):
    sierra_artifact = get_sierra_artifact(contract_name)
    contract_compiled_sierra = Path(sierra_artifact).read_text()
    return create_sierra_compiled_contract(compiled_contract = contract_compiled_sierra).abi

async def declare_v2(contract_name):
    logger.info(f"ℹ️  Declaring {contract_name}")

     # contract_compiled_casm is a string containing the content of the starknet-sierra-compile (.casm file)
    casm_artifact = get_casm_artifact(contract_name)
    contract_compiled_casm = Path(casm_artifact).read_text()
    casm_class = create_casm_class(contract_compiled_casm)
    casm_class_hash = compute_casm_class_hash(casm_class)

    # get sierra artifact
    sierra_artifact = get_sierra_artifact(contract_name)
    contract_compiled_sierra = Path(sierra_artifact).read_text()
    sierra_class = create_sierra_compiled_contract(contract_compiled_sierra)
    sierra_class_hash= compute_sierra_class_hash(sierra_class)
    # Check has not been declared before
    try:
        await GATEWAY_CLIENT.get_class_by_hash(class_hash=sierra_class_hash)
        logger.info(f"✅ Class already declared, skipping")
        return sierra_class_hash
    except Exception:
        pass

    # Create Declare v2 transaction
    account = await get_starknet_account()
    declare_v2_transaction = await account.sign_declare_v2_transaction(
        compiled_contract=contract_compiled_sierra,
        compiled_class_hash=casm_class_hash,
        max_fee=int(1e17),
    )

    # Send Declare v2 transaction
    resp = await account.client.declare(transaction=declare_v2_transaction)
    await account.client.wait_for_tx(resp.transaction_hash)

    logger.info(f"✅ {contract_name} class hash: {hex(resp.class_hash)}")
    return resp.class_hash

async def deploy_v2(contract_name, *args):
    logger.info(f"ℹ️  Deploying {contract_name}")

    account = await get_starknet_account()

    sierra_class_hash = get_declarations()[contract_name]
    abi = get_abi(contract_name)
    
    deploy_result = await Contract.deploy_contract(
        account=account,
        class_hash=sierra_class_hash,
        abi=json.loads(abi),
        constructor_args=list(args),
        cairo_version=1,
        max_fee=int(1e17),
    )

    await deploy_result.wait_for_acceptance()
    print("deploy_result", deploy_result)

    logger.info(
        f"✅ {contract_name} deployed at: {hex(deploy_result.deployed_contract.address)}"
    )

    return {
        "address": deploy_result.deployed_contract.address,
        "tx": deploy_result.hash,
    }


async def invoke(contract_name, function_name, inputs, address=None):
    account = await get_starknet_account()
    deployments = get_deployments()
    call = Call(
        to_addr=int(deployments[contract_name]["address"], 16) if address is None else address, 
        selector=get_selector_from_name(function_name), 
        calldata=inputs
    )
    print("call", call)
    logger.info(f"ℹ️  Invoking {contract_name}.{function_name}({json.dumps(inputs)})")
    response = await account.execute(calls=call, max_fee=int(1e17))
    await account.client.wait_for_tx(response.transaction_hash)
    logger.info(
        f"✅ {contract_name}.{function_name} invoked at tx: %s",
        hex(response.transaction_hash),
    )
    return response.transaction_hash

async def invoke_cairo0(contract_name, function_name, *inputs, address=None):
    account = await get_starknet_account()
    deployments = get_deployments()
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.load(open(get_artifact(contract_name)))["abi"],
        account,
    )
    call = contract.functions[function_name].prepare(*inputs, max_fee=int(1e17))
    logger.info(f"ℹ️  Invoking {contract_name}.{function_name}({json.dumps(inputs)})")
    response = await account.execute(call, max_fee=int(1e17)).wait_for_acceptance()
    logger.info(
        f"✅ {contract_name}.{function_name} invoked at tx: %s",
        hex(response.transaction_hash),
    )
    return response.transaction_hash