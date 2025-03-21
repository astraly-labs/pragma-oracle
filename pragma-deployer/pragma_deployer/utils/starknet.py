# source : https://github.com/kkrt-labs/kakarot/blob/main/scripts/utils/starknet.py
# adapted to work with cairo1 contracts
import json
import logging

from pathlib import Path
from caseconverter import snakecase

from starknet_py.hash.selector import get_selector_from_name
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account
from starknet_py.net.client_models import Call
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.common import create_casm_class, create_sierra_compiled_contract
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.hash.sierra_class_hash import compute_sierra_class_hash

from pragma_deployer.utils.constants import (
    BUILD_DIR,
    DEPLOYER_ROOT,
    # CONTRACTS,
    DEPLOYMENTS_DIR,
    ETH_TOKEN_ADDRESS,
    MAX_FEE,
    NETWORK,
    FULLNODE_CLIENT,
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


def str_to_felt(text):
    if text.upper() != text:
        logger.warning(f"Converting lower to uppercase for str_to_felt: {text}")
        text = text.upper()
    b_text = bytes(text, "utf-8")
    return int.from_bytes(b_text, "big")


def get_devnet_fullnode_client(port):
    return FullNodeClient(node_url=f"http://127.0.0.1:{port}/rpc")


async def get_starknet_account(address=None, private_key=None, port=None) -> Account:
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
    if port is None:
        return Account(
            address=address,
            client=FULLNODE_CLIENT,
            chain=NETWORK["chain_id"],
            key_pair=key_pair,
        )
    else:
        return Account(
            address=address,
            client=get_devnet_fullnode_client(port=port),
            chain=NETWORK["chain_id"],
            key_pair=key_pair,
        )


async def get_eth_contract(port=None) -> Contract:
    erc_20_path = DEPLOYER_ROOT / "pragma_deployer" / "utils" / "erc20.json"
    return Contract(
        ETH_TOKEN_ADDRESS,
        json.loads(erc_20_path.read_text())["abi"],
        await get_starknet_account(port=port),
        cairo_version=0,
    )


async def get_contract(contract_name, port=None) -> Contract:
    return Contract(
        get_deployments()[contract_name]["address"],
        json.loads(get_artifact(contract_name).read_text())["abi"],
        await get_starknet_account(port=port),
        cairo_version=0,
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
                "address": (
                    hex(deployment["address"])
                    if isinstance(deployment["address"], int)
                    else deployment["address"]
                ),
                "tx": (
                    hex(deployment["tx"])
                    if isinstance(deployment["tx"], int)
                    else deployment["tx"]
                ),
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
    return create_sierra_compiled_contract(
        compiled_contract=contract_compiled_sierra
    ).abi


async def declare_v2(contract_name, port=None):
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
    sierra_class_hash = compute_sierra_class_hash(sierra_class)
    # Check has not been declared before
    fullnode_client = (
        FULLNODE_CLIENT if port is None else get_devnet_fullnode_client(port=port)
    )
    try:
        await fullnode_client.get_class_by_hash(class_hash=sierra_class_hash)
        logger.info("✅ Class already declared, skipping")
        return sierra_class_hash
    except Exception:
        pass

    # Create Declare v2 transaction
    account = await get_starknet_account(port=port)
    sign_declare_v2 = await account.sign_declare_v2(
        compiled_contract=contract_compiled_sierra,
        compiled_class_hash=casm_class_hash,
        max_fee=MAX_FEE,
    )

    # Send Declare v2 transaction
    resp = await account.client.declare(transaction=sign_declare_v2)

    logger.info(
        f"✅ {contract_name} class hash {hex(resp.class_hash)} at tx {hex(resp.transaction_hash)}"
    )
    return resp.class_hash


async def deploy_v2(contract_name, *args, port=None):
    logger.info(f"ℹ️  Deploying {contract_name}")

    account = await get_starknet_account(port=port)

    sierra_class_hash = get_declarations()[contract_name]
    abi = get_abi(contract_name)

    deploy_result = await Contract.deploy_contract_v1(
        account=account,
        class_hash=sierra_class_hash,
        abi=json.loads(abi),
        constructor_args=list(args),
        cairo_version=1,
        max_fee=MAX_FEE,
    )

    logger.info(f"Transaction hash: {hex(deploy_result.hash)}")

    await deploy_result.wait_for_acceptance()

    logger.info(
        f"✅ {contract_name} deployed at: {hex(deploy_result.deployed_contract.address)}"
    )

    return {
        "address": deploy_result.deployed_contract.address,
        "tx": deploy_result.hash,
    }


async def invoke(contract_name, function_name, inputs, address=None, port=None):
    account = await get_starknet_account(port=port)
    deployments = get_deployments()
    call = Call(
        to_addr=(
            int(deployments[contract_name]["address"], 16)
            if address is None
            else address
        ),
        selector=get_selector_from_name(function_name),
        calldata=inputs,
    )
    logger.info(f"ℹ️  Invoking {contract_name}.{function_name}")
    response = await account.execute_v1(
        calls=call,
        max_fee=MAX_FEE,
    )
    logger.info(
        f"✅ {contract_name}.{function_name} invoked at tx: %s",
        hex(response.transaction_hash),
    )
    await account.client.wait_for_tx(response.transaction_hash)
    return response.transaction_hash


async def invoke_cairo0(contract_name, function_name, *inputs, address=None):
    account = await get_starknet_account()
    deployments = get_deployments()
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.load(open(get_artifact(contract_name)))["abi"],
        account,
        cairo_version=0,
    )
    call = contract.functions[function_name].prepare(*inputs, max_fee=MAX_FEE)
    logger.info(f"ℹ️  Invoking {contract_name}.{function_name}")
    response = await account.execute_v1(call, max_fee=MAX_FEE).wait_for_acceptance()
    logger.info(
        f"✅ {contract_name}.{function_name} invoked at tx: %s",
        hex(response.transaction_hash),
    )
    return response.transaction_hash


async def call(contract_name, function_name, *inputs, address=None, port=None):
    deployments = get_deployments()
    account = await get_starknet_account(port=port)
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.loads(get_abi(contract_name=contract_name)),
        account,
        cairo_version=1,
    )
    return await contract.functions[function_name].call(*inputs)
