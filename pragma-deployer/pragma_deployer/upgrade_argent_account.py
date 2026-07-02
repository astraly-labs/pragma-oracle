"""
Upgrade an Argent account v0.4.0 to the official Argent v0.5.0 class.

Since Starknet v0.13.4, the gas-metering mode of a transaction is fixed by the
Sierra version of the *account* class that executes it: classes below Sierra
1.7.0 run the whole transaction in legacy "Cairo steps" counting, which prices
compute higher than modern Sierra-gas counting. Our publisher and admin
accounts are Argent v0.4.0 (Sierra 1.5.0), so every publish overpays its
compute (l2_gas) component.

Upgrading in place to the official Argent v0.5.0 class (Sierra 1.7.0) moves
the account to Sierra-gas metering without changing its address or key, and
v0.5.0 still accepts the concise [r, s] signature for a single Starknet owner
with no guardian, so the price-pusher keeps working unchanged.

The class hashes below are the official Argent deployments, cross-checkable at
https://github.com/argentlabs/argent-contracts-starknet/blob/main/deployments/account.txt

Usage:
    # Read-only checks (no private key needed):
    STARKNET_NETWORK=sepolia uv run upgrade-argent-account \
        --account-address 0x04c1d9da...

    # Dry-run with fee estimation (signs but sends nothing):
    STARKNET_NETWORK=sepolia UPGRADE_ACCOUNT_PRIVATE_KEY=0x... \
        uv run upgrade-argent-account --account-address 0x04c1d9da...

    # Actually upgrade:
    ... uv run upgrade-argent-account --account-address 0x04c1d9da... --execute
"""

import os
import asyncio
import logging
from typing import Optional

import click
from dotenv import load_dotenv

from starknet_py.hash.selector import get_selector_from_name
from starknet_py.net.account.account import Account
from starknet_py.net.client_errors import ClientError
from starknet_py.net.client_models import Call, ResourceBounds, ResourceBoundsMapping
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.signer.stark_curve_signer import KeyPair

from pragma_utils.logger import setup_logging

from pragma_deployer.utils.constants import NETWORK

load_dotenv()

logger = logging.getLogger(__name__)

ARGENT_V040_CLASS_HASH = (
    0x036078334509B514626504EDC9FB252328D1A240E4E948BEF8D0C08DFF45927F
)
ARGENT_V050_CLASS_HASH = (
    0x073414441639DCD11D1846F287650A00C60C416B9D3BA45D31C651672125B2C2
)
REQUIRED_TARGET_SIERRA = (1, 7, 0)

# Same address on mainnet and sepolia. Used for a 0-value self-transfer that
# exercises __validate__/__execute__ end-to-end and measures l2_gas.
STRK_TOKEN_ADDRESS = 0x04718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D

PRIVATE_KEY_ENV_VAR = "UPGRADE_ACCOUNT_PRIVATE_KEY"

ZERO_RESOURCE_BOUNDS = ResourceBoundsMapping(
    l1_gas=ResourceBounds(max_amount=0, max_price_per_unit=0),
    l2_gas=ResourceBounds(max_amount=0, max_price_per_unit=0),
    l1_data_gas=ResourceBounds(max_amount=0, max_price_per_unit=0),
)


def _felt(value) -> int:
    return int(value, 16) if isinstance(value, str) else int(value)


async def _view(client: FullNodeClient, address: int, function_name: str) -> list[int]:
    # block "latest" explicitly: newer RPC specs dropped the "pending" tag
    # starknet.py defaults to.
    return await client.call_contract(
        Call(
            to_addr=address,
            selector=get_selector_from_name(function_name),
            calldata=[],
        ),
        block_number="latest",
    )


async def _sierra_version(client: FullNodeClient, class_hash: int) -> Optional[tuple]:
    contract_class = await client.get_class_by_hash(class_hash, block_number="latest")
    program = getattr(contract_class, "sierra_program", None)
    if not program:
        return None  # Cairo 0 class
    return tuple(_felt(x) for x in program[:3])


def _strk_probe_call(account_address: int) -> Call:
    return Call(
        to_addr=STRK_TOKEN_ADDRESS,
        selector=get_selector_from_name("transfer"),
        calldata=[account_address, 0, 0],
    )


def _upgrade_call(account_address: int) -> Call:
    # upgrade(new_implementation: ClassHash, data: Array<felt252>) with empty
    # data, the supported v0.4.0 -> v0.5.0 migration path.
    return Call(
        to_addr=account_address,
        selector=get_selector_from_name("upgrade"),
        calldata=[ARGENT_V050_CLASS_HASH, 0],
    )


async def _estimate(account: Account, call: Call):
    tx = await account.sign_invoke_v3(
        calls=[call], resource_bounds=ZERO_RESOURCE_BOUNDS
    )
    return await account.client.estimate_fee(tx=tx)


def _log_fee(label: str, estimate_or_resources) -> Optional[int]:
    l2_gas = getattr(estimate_or_resources, "l2_gas_consumed", None)
    if l2_gas is None:
        l2_gas = getattr(estimate_or_resources, "l2_gas", None)
    l1_data_gas = getattr(estimate_or_resources, "l1_data_gas_consumed", None)
    if l1_data_gas is None:
        l1_data_gas = getattr(estimate_or_resources, "l1_data_gas", None)
    overall = getattr(estimate_or_resources, "overall_fee", None)
    parts = [f"l2_gas={l2_gas}", f"l1_data_gas={l1_data_gas}"]
    if overall is not None:
        parts.append(f"overall_fee={overall / 1e18:.8f} STRK")
    logger.info(f"⛽ {label}: {', '.join(parts)}")
    return l2_gas


async def run_preflight_checks(client: FullNodeClient, account_address: int) -> None:
    class_hash = await client.get_class_hash_at(account_address, block_number="latest")
    if class_hash == ARGENT_V050_CLASS_HASH:
        logger.info("✅ Account is already on Argent v0.5.0, nothing to do.")
        raise SystemExit(0)
    if class_hash != ARGENT_V040_CLASS_HASH:
        raise click.ClickException(
            f"Account class {hex(class_hash)} is not Argent v0.4.0 "
            f"({hex(ARGENT_V040_CLASS_HASH)}). This script only handles the "
            "Argent v0.4.0 -> v0.5.0 path; aborting."
        )
    logger.info(f"✅ Current class is Argent v0.4.0 ({hex(class_hash)})")

    version = await _view(client, account_address, "get_version")
    if version != [0, 4, 0]:
        raise click.ClickException(
            f"Unexpected get_version() = {version}, expected [0, 4, 0]"
        )
    logger.info("✅ get_version() = 0.4.0")

    guardian = await _view(client, account_address, "get_guardian")
    if guardian != [0]:
        raise click.ClickException(
            f"Account has a guardian ({guardian}); the concise [r, s] signature "
            "flow no longer applies. Aborting, handle this account manually."
        )
    logger.info("✅ No guardian configured")

    target_sierra = await _sierra_version(client, ARGENT_V050_CLASS_HASH)
    if target_sierra != REQUIRED_TARGET_SIERRA:
        raise click.ClickException(
            f"Target class {hex(ARGENT_V050_CLASS_HASH)} has Sierra version "
            f"{target_sierra}, expected {REQUIRED_TARGET_SIERRA}. Aborting."
        )
    logger.info("✅ Target Argent v0.5.0 class is declared with Sierra 1.7.0")

    balance = await client.call_contract(
        Call(
            to_addr=STRK_TOKEN_ADDRESS,
            selector=get_selector_from_name("balanceOf"),
            calldata=[account_address],
        ),
        block_number="latest",
    )
    strk = (balance[0] + (balance[1] << 128)) / 1e18
    logger.info(f"💰 STRK balance: {strk:.4f}")
    if strk < 0.5:
        logger.warning(
            "⚠️  Low STRK balance, the upgrade transaction may fail to pay fees."
        )


def check_owner_matches_key(owner: list[int], key_pair: KeyPair) -> None:
    if owner != [key_pair.public_key]:
        raise click.ClickException(
            f"get_owner() = {[hex(o) for o in owner]} does not match the public key "
            f"{hex(key_pair.public_key)} derived from {PRIVATE_KEY_ENV_VAR}. "
            "Wrong key or wrong account; aborting."
        )
    logger.info("✅ Private key matches the account owner")


async def main(
    account_address: str,
    rpc_url: Optional[str],
    execute: bool,
    skip_signature_test: bool,
    yes: bool,
) -> None:
    network = NETWORK["name"]
    if network not in ("sepolia", "mainnet"):
        raise click.ClickException(
            f"STARKNET_NETWORK={network} is not supported, use sepolia or mainnet."
        )
    address = _felt(account_address)
    client = FullNodeClient(node_url=rpc_url or NETWORK["rpc_url"])
    logger.info(f"🌐 Network: {network} | account: {hex(address)}")

    await run_preflight_checks(client, address)

    private_key = os.getenv(PRIVATE_KEY_ENV_VAR)
    if private_key is None:
        logger.info(
            f"ℹ️  {PRIVATE_KEY_ENV_VAR} not set: read-only checks passed. "
            "Set it to estimate fees, add --execute to upgrade."
        )
        return

    key_pair = KeyPair.from_private_key(_felt(private_key))
    owner = await _view(client, address, "get_owner")
    check_owner_matches_key(owner, key_pair)

    account = Account(
        address=address,
        client=client,
        chain=NETWORK["chain_id"],
        key_pair=key_pair,
    )

    # Baseline of the legacy metering mode, comparable with the same probe
    # after the upgrade.
    baseline = await _estimate(account, _strk_probe_call(address))
    l2_gas_before = _log_fee(
        "Probe tx (0-value STRK self-transfer) BEFORE upgrade", baseline
    )

    upgrade_estimate = await _estimate(account, _upgrade_call(address))
    _log_fee("Upgrade tx estimate", upgrade_estimate)

    if not execute:
        logger.info("🏁 Dry-run complete. Re-run with --execute to send the upgrade.")
        return

    if not yes:
        if network == "mainnet":
            typed = click.prompt(
                f"⚠️  About to upgrade MAINNET account {hex(address)} to Argent v0.5.0. "
                "Type UPGRADE to confirm",
                default="",
                show_default=False,
            )
            if typed != "UPGRADE":
                raise click.ClickException("Confirmation failed, aborting.")
        elif not click.confirm(
            f"Upgrade {network} account {hex(address)} to Argent v0.5.0?"
        ):
            raise click.ClickException("Aborted.")

    logger.info(
        f"🆙 Sending upgrade to Argent v0.5.0 ({hex(ARGENT_V050_CLASS_HASH)})..."
    )
    response = await account.execute_v3(
        calls=[_upgrade_call(address)], auto_estimate=True
    )
    logger.info(f"⏳ Upgrade tx sent: {hex(response.transaction_hash)}, waiting...")
    receipt = await client.wait_for_tx(response.transaction_hash)
    logger.info(f"✅ Upgrade tx accepted (status: {receipt.execution_status})")

    new_class_hash = await client.get_class_hash_at(address, block_number="latest")
    if new_class_hash != ARGENT_V050_CLASS_HASH:
        raise click.ClickException(
            f"Post-check failed: account class is {hex(new_class_hash)}, "
            f"expected {hex(ARGENT_V050_CLASS_HASH)}. Investigate before publishing."
        )
    new_version = await _view(client, address, "get_version")
    logger.info(f"✅ Account now on Argent v0.5.0 (get_version() = {new_version})")

    if skip_signature_test:
        logger.warning(
            "⚠️  Signature test skipped: verify the price-pusher can still sign "
            "before relying on this account."
        )
        return

    logger.info(
        "🧪 Testing concise [r, s] signature under v0.5.0 (0-value STRK self-transfer)..."
    )
    try:
        test_response = await account.execute_v3(
            calls=[_strk_probe_call(address)], auto_estimate=True
        )
        test_receipt = await client.wait_for_tx(test_response.transaction_hash)
    except ClientError as err:
        raise click.ClickException(
            "Signature test FAILED after upgrade: the pusher may need to sign with "
            f"the Argent SignerSignature format. Do NOT upgrade more accounts. Error: {err}"
        )
    resources = getattr(test_receipt, "execution_resources", None)
    l2_gas_after = _log_fee("Probe tx AFTER upgrade", resources) if resources else None
    logger.info(
        f"✅ Concise signature accepted (tx {hex(test_response.transaction_hash)}), "
        "the price-pusher can keep signing unchanged."
    )
    if l2_gas_before and l2_gas_after:
        logger.info(
            f"📊 Probe l2_gas before/after: {l2_gas_before} -> {l2_gas_after} "
            f"({l2_gas_before / l2_gas_after:.2f}x cheaper on compute)"
        )
    logger.info(
        "🏁 Done. Watch the next publish from this account before upgrading others."
    )


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
    "--account-address",
    envvar="UPGRADE_ACCOUNT_ADDRESS",
    required=True,
    help="Address of the Argent v0.4.0 account to upgrade (e.g. the PRAGMA publisher)",
)
@click.option(
    "--rpc-url",
    default=None,
    help=f"Override the {NETWORK['name']} RPC url from constants.py",
)
@click.option(
    "--execute",
    is_flag=True,
    default=False,
    help="Actually send the upgrade transaction (default is dry-run)",
)
@click.option(
    "--skip-signature-test",
    is_flag=True,
    default=False,
    help="Skip the post-upgrade 0-value transfer that validates [r, s] signing",
)
@click.option(
    "--yes",
    is_flag=True,
    default=False,
    help="Skip interactive confirmations",
)
def cli_entrypoint(
    log_level: str,
    account_address: str,
    rpc_url: Optional[str],
    execute: bool,
    skip_signature_test: bool,
    yes: bool,
) -> None:
    """
    Upgrade an Argent v0.4.0 account to the official v0.5.0 class (Sierra 1.7.0)
    so its transactions use Sierra-gas metering instead of legacy Cairo steps.
    """
    setup_logging(logger, log_level)
    asyncio.run(main(account_address, rpc_url, execute, skip_signature_test, yes))


if __name__ == "__main__":
    cli_entrypoint()
