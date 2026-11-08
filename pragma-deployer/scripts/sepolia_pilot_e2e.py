# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = ["starknet-py==0.30.0", "pyyaml>=6"]
# ///
"""
End-to-end test of the validator pilot on Sepolia, with throwaway test accounts.

The funder (the pilot admin) funds a test staker and two oracle signers; the
staker stakes 1 STRK. Then the operator path runs with the real client
(`pragma-validator`), and this script plays the staker's wallet for the binds
and the exit. State and test keys live in ~/.pragma-pilot-e2e (chmod 700).

    S=pragma-deployer/scripts/sepolia_pilot_e2e.py
    uv run $S setup --funder 0x... --funder-keystore ~/.starkli-wallets/pragma-pilot-admin.json
    pragma-validator preflight -c ~/.pragma-pilot-e2e/validator-publisher.yaml   # registration fails
    pragma-validator register  -c ~/.pragma-pilot-e2e/validator-publisher.yaml   # declare
    uv run $S bind --signer a                                                    # staker's wallet
    pragma-validator run       -c ~/.pragma-pilot-e2e/validator-publisher.yaml   # a few minutes
    uv run $S status                                                             # own entries
    pragma-validator rotate ... (signer b), uv run $S bind --signer b, revoke, ...
    uv run $S exit            # unstake intent: the registry revokes at once
    uv run $S withdraw        # after the 5 min exit window
    uv run $S refund --funder 0x... --funder-keystore ...   # STRK back to the funder

Source-quorum failure, read as a consumer with `pragma-validator feed-status`
(VALID needs 4 markets with a fresh entry from ACTIVE operators):

    pragma-validator run ...                          # until the first push, then stop it
    pragma-validator feed-status --network sepolia --rpc-url ...    # VALID
    uv run $S sources --admin 0x... --admin-keystore ... --only BINANCE,OKX,BYBIT
    pragma-validator feed-status ...                  # WITHHELD, 3 markets
    uv run $S sources --admin 0x... --admin-keystore ...            # restore the list
    pragma-validator feed-status ...                  # VALID again
    uv run $S revoke && pragma-validator feed-status ...            # STALE at once
"""

import argparse
import asyncio
import getpass
import json
import os
import secrets
import sys
import time

from pathlib import Path

import yaml
from starknet_py.hash.address import compute_address
from starknet_py.hash.selector import get_selector_from_name
from starknet_py.net.account.account import Account
from starknet_py.net.client_models import Call
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.signer.key_pair import KeyPair

ROOT = Path(__file__).resolve().parents[2]
PILOT = json.loads(
    (ROOT / "deployments" / "sepolia" / "validator_pilot.json").read_text()
)
REGISTRY = int(PILOT["pragma_ValidatorRegistry"]["address"], 16)
ORACLE = int(PILOT["pragma_Oracle"]["address"], 16)
STAKING = int(PILOT["staking"], 16)
STRK = 0x04718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D
OZ_ACCOUNT = 0x061DAC032F228ABEF9C6626F995015233097AE253A7F72D68552DB02F2971B8F
RPC = os.getenv("STARKNET_RPC_URL", "https://starknet-sepolia-rpc.publicnode.com")
CHAIN = StarknetChainId.SEPOLIA
STATE_DIR = Path(os.getenv("PILOT_E2E_DIR", Path.home() / ".pragma-pilot-e2e"))
STATE = STATE_DIR / "state.json"
STRK_UNIT = 10**18
FUNDING = {"staker": 3 * STRK_UNIT, "a": 20 * STRK_UNIT, "b": 10 * STRK_UNIT}
STAKE = 1 * STRK_UNIT


def str_to_felt(text: str) -> int:
    return int.from_bytes(text.upper().encode(), "big")


def felt_to_str(felt: int) -> str:
    return felt.to_bytes((felt.bit_length() + 7) // 8, "big").decode(errors="replace")


def call(to: int, entrypoint: str, calldata: list) -> Call:
    return Call(
        to_addr=to, selector=get_selector_from_name(entrypoint), calldata=calldata
    )


async def read(client: FullNodeClient, to: int, entrypoint: str, calldata=()) -> list:
    return await client.call_contract(
        call(to, entrypoint, list(calldata)), block_number="latest"
    )


async def send(account: Account, *calls: Call) -> None:
    response = await account.execute_v3(calls=list(calls), auto_estimate=True)
    await account.client.wait_for_tx(response.transaction_hash)
    print(f"    tx {hex(response.transaction_hash)}")


def load_state() -> dict:
    if not STATE.exists():
        sys.exit(f"{STATE} missing, run `setup` first")
    return json.loads(STATE.read_text())


def save_state(state: dict) -> None:
    STATE_DIR.mkdir(mode=0o700, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2))
    STATE.chmod(0o600)


def test_account(client: FullNodeClient, entry: dict) -> Account:
    account = Account(
        address=int(entry["address"], 16),
        client=client,
        key_pair=KeyPair.from_private_key(int(entry["private_key"], 16)),
        chain=CHAIN,
    )
    # OZ accounts are Cairo 1: skip the get_class_at lookup (devnet forks do not serve it)
    account._cairo_version = 1
    return account


def funder_account(
    client: FullNodeClient, address: str, keystore: str | None
) -> Account:
    if keystore:
        password = getpass.getpass("Keystore password: ").encode()
        key_pair = KeyPair.from_keystore(os.path.expanduser(keystore), password)  # type: ignore[arg-type]
    elif os.getenv("PRIVATE_KEY"):
        key_pair = KeyPair.from_private_key(int(os.environ["PRIVATE_KEY"], 16))
    else:
        sys.exit("pass --funder-keystore or set PRIVATE_KEY")
    return Account(
        address=int(address, 16), client=client, key_pair=key_pair, chain=CHAIN
    )


async def strk_balance(client: FullNodeClient, account: int) -> int:
    low, high = await read(client, STRK, "balance_of", [account])
    return low + (high << 128)


async def create_account(client: FullNodeClient, funder: Account, name: str) -> dict:
    key_pair = KeyPair.generate()
    salt = secrets.randbits(250)
    address = compute_address(
        salt=salt, class_hash=OZ_ACCOUNT, constructor_calldata=[key_pair.public_key]
    )
    print(f"  {name}: funding {hex(address)} with {FUNDING[name] / STRK_UNIT:g} STRK")
    await send(funder, call(STRK, "transfer", [address, FUNDING[name], 0]))
    result = await Account.deploy_account_v3(
        address=address,
        class_hash=OZ_ACCOUNT,
        salt=salt,
        key_pair=key_pair,
        client=client,
        constructor_calldata=[key_pair.public_key],
        auto_estimate=True,
    )
    await result.wait_for_acceptance()
    print(f"  {name}: account deployed")
    return {"address": hex(address), "private_key": hex(key_pair.private_key)}


def write_operator_files(state: dict, signer: str) -> None:
    entry = state["signers"][signer]
    env = STATE_DIR / f"oracle-signer-{signer}.env"
    env.write_text(f"ORACLE_SIGNER_PRIVATE_KEY={entry['private_key']}\n")
    env.chmod(0o600)
    config = {
        "schema_version": 1,
        "network": "sepolia",
        "rpc_url": RPC,
        "staker_address": state["staker"]["address"],
        "oracle_signer_address": entry["address"],
        "private_key": "env:ORACLE_SIGNER_PRIVATE_KEY",
        "min_signer_balance_strk": 5,
    }
    if signer == "a":
        # for `pragma-validator rotate --new-private-key env:NEW_ORACLE_SIGNER_PRIVATE_KEY`
        rotation = STATE_DIR / "rotation-b.env"
        rotation.write_text(
            f"NEW_ORACLE_SIGNER_PRIVATE_KEY={state['signers']['b']['private_key']}\n"
        )
        rotation.chmod(0o600)
    path = STATE_DIR / "validator-publisher.yaml"
    path.write_text(yaml.safe_dump(config, sort_keys=False))
    path.chmod(0o600)
    print(f"  config for signer {signer}: {path} (key in {env.name})")


async def cmd_setup(args, client: FullNodeClient) -> None:
    """Resumable: each account and the stake are only created once."""
    state = json.loads(STATE.read_text()) if STATE.exists() else {"signers": {}}
    state.setdefault("operational", hex(secrets.randbits(250)))
    funder = None
    print("Test accounts")
    for name in ("staker", "a", "b"):
        done = state.get(name) if name == "staker" else state["signers"].get(name)
        if done:
            print(f"  {name}: {done['address']} already set up")
            continue
        funder = funder or funder_account(client, args.funder, args.funder_keystore)
        entry = await create_account(client, funder, name)
        if name == "staker":
            state["staker"] = entry
        else:
            state["signers"][name] = entry
        save_state(state)
    staker = test_account(client, state["staker"])
    if (await read(client, STAKING, "get_staker_info_v1", [staker.address]))[0] == 0:
        print("  staker: already staking")
    else:
        print(f"Staking {STAKE / STRK_UNIT:g} STRK")
        await send(
            staker,
            call(STRK, "approve", [STAKING, STAKE, 0]),
            call(
                STAKING, "stake", [staker.address, int(state["operational"], 16), STAKE]
            ),
        )
    write_operator_files(state, "a")


async def cmd_bind(args, client: FullNodeClient) -> None:
    state = load_state()
    staker = test_account(client, state["staker"])
    signer = state["signers"][args.signer]
    print(f"Staker binds oracle signer {args.signer} ({signer['address']})")
    await send(
        staker, call(REGISTRY, "bind_oracle_signer", [int(signer["address"], 16)])
    )
    write_operator_files(state, args.signer)


async def cmd_revoke(args, client: FullNodeClient) -> None:
    state = load_state()
    staker = test_account(client, state["staker"])
    print("Staker revokes its oracle signer")
    await send(staker, call(REGISTRY, "revoke_oracle_signer", [staker.address]))


async def cmd_status(args, client: FullNodeClient) -> None:
    state = load_state()
    staker = int(state["staker"]["address"], 16)
    (status,) = await read(client, REGISTRY, "get_publisher_status", [staker])
    (bound,) = await read(client, REGISTRY, "get_oracle_signer", [staker])
    names = {int(v["address"], 16): k for k, v in state["signers"].items()}
    print(f"registry status: {felt_to_str(status)}")
    print(f"bound signer:    {hex(bound)} ({names.get(bound, 'none')})")
    for name, entry in state["signers"].items():
        balance = await strk_balance(client, int(entry["address"], 16))
        print(f"signer {name} balance: {balance / STRK_UNIT:.3f} STRK")
    now = int(time.time())
    print("own entries on the pilot Oracle (age):")
    for pair in PILOT["pairs"]:
        ages = []
        for source in PILOT["allowed_sources"]:
            try:
                # get_data_entry(DataType::SpotEntry(pair), source, publisher)
                result = await read(
                    client,
                    ORACLE,
                    "get_data_entry",
                    [0, str_to_felt(pair), str_to_felt(source), staker],
                )
            except Exception:
                continue
            # PossibleEntries::Spot -> [0, timestamp, source, publisher, price, pair_id, volume]
            ages.append(f"{source} {now - result[1]}s")
        print(f"  {pair:9} {', '.join(ages) or 'none'}")


async def cmd_sources(args, client: FullNodeClient) -> None:
    """Admin call: restrict the allowed sources, or restore the deployed list."""
    sources = args.only.split(",") if args.only else PILOT["allowed_sources"]
    admin = funder_account(client, args.admin, args.admin_keystore)
    print(f"Admin sets the allowed sources: {', '.join(sources)}")
    await send(
        admin,
        call(
            REGISTRY,
            "set_allowed_sources",
            [len(sources), *(str_to_felt(source) for source in sources)],
        ),
    )


async def cmd_exit(args, client: FullNodeClient) -> None:
    staker = test_account(client, load_state()["staker"])
    print("Staker sends its unstake intent")
    await send(staker, call(STAKING, "unstake_intent", []))


async def cmd_withdraw(args, client: FullNodeClient) -> None:
    staker = test_account(client, load_state()["staker"])
    print("Staker withdraws its stake (after the exit window)")
    await send(staker, call(STAKING, "unstake_action", [staker.address]))


async def cmd_refund(args, client: FullNodeClient) -> None:
    state = load_state()
    funder = int(args.funder, 16)
    for name, entry in [("staker", state["staker"]), *state["signers"].items()]:
        account = test_account(client, entry)
        balance = await strk_balance(client, account.address)
        # leave room for the transfer's own fee
        amount = balance - STRK_UNIT // 2
        if amount <= 0:
            continue
        print(f"  {name}: {amount / STRK_UNIT:.3f} STRK back to the funder")
        await send(account, call(STRK, "transfer", [funder, amount, 0]))


COMMANDS = {
    "setup": cmd_setup,
    "bind": cmd_bind,
    "revoke": cmd_revoke,
    "status": cmd_status,
    "sources": cmd_sources,
    "exit": cmd_exit,
    "withdraw": cmd_withdraw,
    "refund": cmd_refund,
}


async def main(args) -> None:
    client = FullNodeClient(node_url=RPC)
    if int(await client.get_chain_id(), 16) != CHAIN.value:
        sys.exit(f"{RPC} is not Sepolia")
    await COMMANDS[args.command](args, client)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("setup", "refund"):
        p = sub.add_parser(name)
        p.add_argument("--funder", required=True, help="pilot admin address")
        if name == "setup":
            p.add_argument("--funder-keystore", help="or PRIVATE_KEY")
    sub.add_parser("bind").add_argument("--signer", choices=["a", "b"], required=True)
    p = sub.add_parser("sources")
    p.add_argument("--admin", required=True, help="pilot admin address")
    p.add_argument("--admin-keystore", help="or PRIVATE_KEY")
    p.add_argument("--only", help="comma-separated sources; default: the deployed list")
    for name in ("revoke", "status", "exit", "withdraw"):
        sub.add_parser(name)
    asyncio.run(main(parser.parse_args()))
