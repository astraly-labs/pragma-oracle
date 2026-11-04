# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = ["starknet-py==0.30.0", "semver>=3"]
# ///
"""
Deploy the validator publishing pilot (DP-PRA-381, scope C): a ValidatorRegistry
and an unmodified Oracle on top of it. Nothing in production is touched.

    cd validator-registry && scarb build && cd ..
    uv run pragma-deployer/scripts/deploy_validator_pilot.py --network sepolia \
        --account 0x... --keystore ~/.starkli-wallets/admin.keystore.json

Starknet only accepts declaring Sierra 1.5.0 to 1.9.0: the registry is built with
Cairo 2.11 (validator-registry/), and the pilot Oracle is an instance of the Oracle
class already declared on the network (pragma-oracle's Cairo 2.2 build is Sierra
1.3.0). On devnet, which still accepts it, the Oracle is declared from
pragma-oracle/ and the full registration flow is replayed against a mock staking.

The admin key is read from the keystore (password prompted) or PRIVATE_KEY.
The deployer account becomes the pilot admin. Addresses are written to
deployments/<network>/validator_pilot.json, never to deployments.json.
"""

import argparse
import asyncio
import getpass
import json
import os
import sys
import urllib.request

from pathlib import Path

import semver
from starknet_py.common import create_casm_class, create_sierra_compiled_contract
from starknet_py.contract import Contract
from starknet_py.hash.casm_class_hash import (
    compute_casm_class_hash,
    get_casm_hash_method_for_starknet_version,
)
from starknet_py.hash.selector import get_selector_from_name
from starknet_py.hash.sierra_class_hash import compute_sierra_class_hash
from starknet_py.net.account.account import Account
from starknet_py.net.client_models import Call
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.signer.key_pair import KeyPair

ROOT = Path(__file__).resolve().parents[2]
REGISTRY_BUILD = ROOT / "validator-registry" / "target" / "dev"
ORACLE_BUILD = ROOT / "pragma-oracle" / "target" / "dev"

# Oracle classes already declared, the ones running in production on each network
ORACLE_CLASS = {
    "mainnet": 0x04D6370214ACCDAAC8CC249DB34A916C92464235B87CF03641A85889D2F6D8E7,
    "sepolia": 0x069F78C514B85543DBBC056A539E6B007CC37300892889BE9D7CE9D5D5A21EFB,
}

CHAINS = {
    "mainnet": StarknetChainId.MAINNET,
    "sepolia": StarknetChainId.SEPOLIA,
    "devnet": StarknetChainId.SEPOLIA,
}
DEFAULT_RPC = {
    "sepolia": "https://starknet-sepolia-rpc.publicnode.com",
    "devnet": "http://127.0.0.1:5050/rpc",
}
STAKING = {
    "mainnet": 0x00CA1702E64C81D9A07B86BD2C540188D92A2C73CF5CC0E508D949015E7E84A7,
    "sepolia": 0x03745AB04A431FC02871A139BE6B93D9260B0FF3E779AD9C8B377183B23109F1,
}
# mainnet: the protocol minimum (decision 2026-11-03); sepolia's protocol minimum is 1 STRK
MIN_SELF_STAKE = {"mainnet": 20_000 * 10**18, "sepolia": 10**18, "devnet": 10**18}
# market venues only, aggregators are not markets (scope B)
ALLOWED_SOURCES = [
    "BINANCE", "BITGET", "BITSTAMP", "BYBIT", "GATEIO", "HUOBI",
    "KUCOIN", "LBANK", "OKX", "UPBIT", "EKUBO",
]  # fmt: skip
PAIRS = ["BTC/USD", "ETH/USD", "STRK/USD", "USDC/USD", "USDT/USD"]
ETH = 0x049D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
STRK = 0x04718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D
MAINNET_TOKENS = {
    "USDC": (0x053C91253BC9682C04929CA02ED00B3E423F6710D2EE7E0D5EBB06F3ECF368A8, 0xA0B86991C6218B36C1D19D4A2E9EB0CE3606EB48),
    "USDT": (0x068F5C6A61780768455DE69077E07E89787839BF8166DECFBF92B645209C0FB8, 0xDAC17F958D2EE523A2206206994597C13D831EC7),
}  # fmt: skip


def str_to_felt(text: str) -> int:
    return int.from_bytes(text.upper().encode(), "big")


def currencies(network: str) -> list:
    def token(ticker: str) -> tuple:
        return MAINNET_TOKENS[ticker] if network == "mainnet" else (0, 0)

    rows = [
        ("USD", 8, True, 0, 0),
        ("BTC", 8, True, 0, 0),
        ("ETH", 18, False, ETH, 0),
        ("STRK", 18, False, STRK, 0),
        ("USDC", 6, False, *token("USDC")),
        ("USDT", 6, False, *token("USDT")),
    ]
    return [
        {
            "id": str_to_felt(ticker),
            "decimals": decimals,
            "is_abstract_currency": abstract,
            "starknet_address": starknet,
            "ethereum_address": ethereum,
        }
        for ticker, decimals, abstract, starknet, ethereum in rows
    ]


def pairs() -> list:
    return [
        {
            "id": str_to_felt(pair),
            "quote_currency_id": str_to_felt(pair.split("/")[1]),
            "base_currency_id": str_to_felt(pair.split("/")[0]),
        }
        for pair in PAIRS
    ]


ARTIFACTS = {
    "ValidatorRegistry": (REGISTRY_BUILD, "pragma_validator_registry_ValidatorRegistry", "contract_class", "compiled_contract_class"),
    "MockStaking": (REGISTRY_BUILD, "pragma_validator_registry_MockStaking", "contract_class", "compiled_contract_class"),
    "Oracle": (ORACLE_BUILD, "pragma_Oracle", "sierra", "casm"),
}  # fmt: skip


def artifact(name: str, casm: bool = False) -> str:
    build, stem, sierra_kind, casm_kind = ARTIFACTS[name]
    path = build / f"{stem}.{casm_kind if casm else sierra_kind}.json"
    if not path.exists():
        sys.exit(f"{path} missing, run `scarb build` in {build.parents[1].name}/")
    return path.read_text()


async def declare(account: Account, name: str, hash_method) -> int:
    sierra = artifact(name)
    class_hash = compute_sierra_class_hash(create_sierra_compiled_contract(sierra))
    try:
        await account.client.get_class_by_hash(class_hash)
        print(f"  {name}: class {hex(class_hash)} already declared")
        return class_hash
    except Exception:
        pass
    compiled_class_hash = compute_casm_class_hash(
        create_casm_class(artifact(name, casm=True)), hash_method
    )
    tx = await account.sign_declare_v3(
        compiled_contract=sierra,
        compiled_class_hash=compiled_class_hash,
        auto_estimate=True,
    )
    response = await account.client.declare(transaction=tx)
    await account.client.wait_for_tx(response.transaction_hash)
    print(f"  {name}: declared {hex(response.class_hash)} (tx {hex(response.transaction_hash)})")
    return response.class_hash


async def deploy(account: Account, name: str, class_hash: int, args: list) -> dict:
    # the ABI of the declared class, which may not be the local build
    abi = json.loads((await account.client.get_class_by_hash(class_hash)).abi)
    result = await Contract.deploy_contract_v3(
        account=account,
        class_hash=class_hash,
        abi=abi,
        constructor_args=args,
        cairo_version=1,
        auto_estimate=True,
    )
    await result.wait_for_acceptance()
    address = result.deployed_contract.address
    print(f"  {name}: deployed at {hex(address)} (tx {hex(result.hash)})")
    return {"address": hex(address), "tx": hex(result.hash), "class_hash": hex(class_hash)}


async def read(client: FullNodeClient, address: int, entrypoint: str, calldata=()) -> list:
    return await client.call_contract(
        Call(to_addr=address, selector=get_selector_from_name(entrypoint), calldata=list(calldata)),
        block_number="latest",
    )


async def verify(client: FullNodeClient, registry: int, oracle: int, admin: int, staking: int, network: str) -> None:
    sources = await read(client, registry, "get_allowed_sources")
    checks = {
        "registry admin": (await read(client, registry, "get_admin_address"))[0] == admin,
        "registry staking": (await read(client, registry, "get_staking_contract"))[0] == staking,
        "registry min self-stake": (await read(client, registry, "get_min_self_stake"))[0] == MIN_SELF_STAKE[network],
        "registry sources": sources[1:] == [str_to_felt(s) for s in ALLOWED_SOURCES],
        "oracle registry": (await read(client, oracle, "get_publisher_registry_address"))[0] == registry,
    }
    for pair in PAIRS:
        (pair_id, *_rest) = await read(client, oracle, "get_pair", [str_to_felt(pair)])
        checks[f"oracle pair {pair}"] = pair_id == str_to_felt(pair)
    for name, ok in checks.items():
        print(f"  [{'ok' if ok else 'FAIL'}] {name}")
    if not all(checks.values()):
        sys.exit("verification failed")


async def execute(account: Account, to: int, entrypoint: str, calldata: list) -> None:
    response = await account.execute_v3(
        calls=Call(to_addr=to, selector=get_selector_from_name(entrypoint), calldata=calldata),
        auto_estimate=True,
    )
    await account.client.wait_for_tx(response.transaction_hash)


async def expect_revert(account: Account, to: int, entrypoint: str, calldata: list, reason: str) -> None:
    try:
        await execute(account, to, entrypoint, calldata)
    except Exception as e:
        if reason.encode().hex() in str(e) or reason in str(e):
            return
        raise
    sys.exit(f"{entrypoint} should have reverted with {reason!r}")


def devnet_accounts(rpc: str) -> list:
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "devnet_getPredeployedAccounts", "params": {}})
    request = urllib.request.Request(rpc, body.encode(), {"content-type": "application/json"})
    return json.load(urllib.request.urlopen(request))["result"]


async def devnet_e2e(rpc: str, client: FullNodeClient, registry: int, oracle: int, staking: int) -> None:
    """The registration flow against the real Oracle class, on devnet only."""
    accounts = devnet_accounts(rpc)
    if len(accounts) < 3:
        sys.exit("start starknet-devnet with --accounts 3 or more")
    admin, staker, signer = (
        Account(address=int(a["address"], 16), client=client, key_pair=KeyPair.from_private_key(int(a["private_key"], 16)), chain=CHAINS["devnet"])
        for a in accounts[:3]
    )  # fmt: skip
    reward, operational = 0xBEEF, 0x0FE1
    btc_usd, binance = str_to_felt("BTC/USD"), str_to_felt("BINANCE")
    publisher = staker.address

    def spot(source: int, timestamp: int) -> list:
        # PossibleEntries::Spot(SpotEntry { base: { timestamp, source, publisher }, price, pair_id, volume })
        return [0, timestamp, source, publisher, 65_000 * 10**8, btc_usd, 0]

    await execute(admin, staking, "set_staker", [staker.address, reward, operational, 10 * 10**18])
    await execute(signer, registry, "declare_oracle_signer", [staker.address])
    await execute(staker, registry, "bind_oracle_signer", [signer.address])
    (status,) = await read(client, registry, "get_publisher_status", [staker.address])
    checks = {"bound validator is ACTIVE": status == str_to_felt("ACTIVE")}

    now = (await client.get_block(block_number="latest")).timestamp
    await execute(signer, oracle, "publish_data", spot(binance, now))
    entry = await read(client, oracle, "get_data_entry", [0, btc_usd, binance, publisher])
    checks["oracle accepts the bound validator"] = 65_000 * 10**8 in entry
    await expect_revert(signer, oracle, "publish_data", spot(str_to_felt("PYTH"), now), "Not allowed for source")
    checks["oracle rejects a source outside the whitelist"] = True
    await expect_revert(staker, oracle, "publish_data", spot(binance, now + 1), "Transaction not from publisher")
    checks["oracle rejects the staker key"] = True

    await execute(admin, staking, "set_unstake_time", [staker.address, now + 300])
    await expect_revert(signer, oracle, "publish_data", spot(binance, now + 2), "Publisher is not registered")
    checks["oracle rejects an exiting validator"] = True
    await execute(admin, registry, "prune", [staker.address])
    (bound,) = await read(client, registry, "get_oracle_signer", [staker.address])
    checks["exiting validator pruned"] = bound == 0
    for name, ok in checks.items():
        print(f"  [{'ok' if ok else 'FAIL'}] {name}")
    if not all(checks.values()):
        sys.exit("end-to-end flow failed")


def load_key(keystore: str | None) -> KeyPair:
    if keystore:
        # eth-keyfile >= 0.9 decodes the password as bytes, starknet.py forwards it as is
        password = getpass.getpass("Keystore password: ").encode()
        return KeyPair.from_keystore(os.path.expanduser(keystore), password)  # type: ignore[arg-type]
    if os.getenv("PRIVATE_KEY"):
        return KeyPair.from_private_key(int(os.environ["PRIVATE_KEY"], 16))
    sys.exit("pass --keystore or set PRIVATE_KEY")


async def main(args: argparse.Namespace) -> None:
    rpc = args.rpc_url or DEFAULT_RPC.get(args.network)
    if rpc is None:
        sys.exit(f"--rpc-url is required for {args.network}")
    staking = int(args.staking, 16) if args.staking else STAKING.get(args.network)
    out = ROOT / "deployments" / args.network / "validator_pilot.json"
    if out.exists() and not args.force:
        sys.exit(f"{out} exists, pass --force to deploy a new pilot")

    client = FullNodeClient(node_url=rpc)
    chain_id = int(await client.get_chain_id(), 16)
    if chain_id != CHAINS[args.network].value:
        sys.exit(f"{rpc} is on chain {hex(chain_id)}, not {args.network}")
    admin = int(args.account, 16)
    account = Account(address=admin, client=client, key_pair=load_key(args.keystore), chain=CHAINS[args.network])
    block = await client.get_block(block_number="latest")
    hash_method = get_casm_hash_method_for_starknet_version(semver.Version.parse(block.starknet_version))
    print(f"{args.network} (Starknet {block.starknet_version}), admin {hex(admin)}")

    print("Declaring")
    registry_class = await declare(account, "ValidatorRegistry", hash_method)
    if args.network == "devnet":
        oracle_class = await declare(account, "Oracle", hash_method)
    else:
        oracle_class = ORACLE_CLASS[args.network]
        await client.get_class_by_hash(oracle_class)
        print(f"  Oracle: using the declared production class {hex(oracle_class)}")

    print("Deploying")
    if staking is None:
        mock_class = await declare(account, "MockStaking", hash_method)
        staking = int((await deploy(account, "MockStaking", mock_class, []))["address"], 16)
    registry = await deploy(
        account, "ValidatorRegistry", registry_class,
        [admin, staking, MIN_SELF_STAKE[args.network], [str_to_felt(s) for s in ALLOWED_SOURCES]],
    )  # fmt: skip
    oracle = await deploy(
        account, "Oracle", oracle_class,
        [admin, int(registry["address"], 16), currencies(args.network), pairs()],
    )  # fmt: skip

    print("Verifying")
    await verify(client, int(registry["address"], 16), int(oracle["address"], 16), admin, staking, args.network)
    if args.network == "devnet":
        print("End-to-end (devnet)")
        await devnet_e2e(rpc, client, int(registry["address"], 16), int(oracle["address"], 16), staking)

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps(
            {
                "admin": hex(admin),
                "staking": hex(staking),
                "min_self_stake": str(MIN_SELF_STAKE[args.network]),
                "allowed_sources": ALLOWED_SOURCES,
                "pairs": PAIRS,
                "pragma_ValidatorRegistry": registry,
                "pragma_Oracle": oracle,
            },
            indent=2,
        )
        + "\n"
    )
    print(f"Written {out.relative_to(ROOT)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument("--network", choices=sorted(CHAINS), required=True)
    parser.add_argument("--account", required=True, help="admin account address")
    parser.add_argument("--keystore", help="starkli keystore of the admin account")
    parser.add_argument("--rpc-url", help="JSON-RPC 0.10 endpoint")
    parser.add_argument("--staking", help="staking contract (devnet: a mock is deployed)")
    parser.add_argument("--force", action="store_true")
    asyncio.run(main(parser.parse_args()))
