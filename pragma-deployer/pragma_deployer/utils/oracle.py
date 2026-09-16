"""Idempotent helpers for the Oracle currency / pair registry.

Each helper reads the on-chain state first and only sends a transaction when
something has to change, so the deployer scripts can be re-run safely on any
network, including a fresh devnet.
"""

import logging

from pragma_sdk.common.types.currency import Currency

from pragma_deployer.utils.starknet import call, invoke, str_to_felt

logger = logging.getLogger(__name__)

ORACLE = "pragma_Oracle"


async def ensure_currency(currency: Currency, port=None) -> bool:
    """Register `currency` unless it already exists. Returns True if a tx was sent."""
    currency_id = str_to_felt(currency.id)
    (existing,) = await call(ORACLE, "get_currency", currency_id, port=port)
    if existing["id"] != 0:
        return False
    tx_hash = await invoke(
        ORACLE,
        "add_currency",
        [
            currency_id,
            currency.decimals,
            int(currency.is_abstract_currency),
            currency.starknet_address,
            currency.ethereum_address,
        ],
        port=port,
    )
    logger.info(f"Added currency {currency.id} with tx {hex(tx_hash)}")
    return True


async def ensure_pair(
    pair_id: int, quote_currency_id: str, base_currency_id: str, port=None
) -> bool:
    """Register the pair, or fix its currencies if it exists with other ones.

    Arguments follow the on-chain `Pair` layout: (id, quote_currency_id, base_currency_id).
    Returns True if a tx was sent.
    """
    quote, base = str_to_felt(quote_currency_id), str_to_felt(base_currency_id)
    (existing,) = await call(ORACLE, "get_pair", pair_id, port=port)
    if existing["id"] == 0:
        tx_hash = await invoke(ORACLE, "add_pair", [pair_id, quote, base], port=port)
        logger.info(f"Added pair {hex(pair_id)} with tx {hex(tx_hash)}")
        return True
    if (existing["quote_currency_id"], existing["base_currency_id"]) == (quote, base):
        return False
    tx_hash = await invoke(
        ORACLE, "update_pair", [pair_id, pair_id, quote, base], port=port
    )
    logger.info(
        f"Updated pair {hex(pair_id)} (quote={quote_currency_id}, base={base_currency_id}) with tx {hex(tx_hash)}"
    )
    return True


async def ensure_conversion_rate_pair(pair_id: int, port=None) -> bool:
    """Flag `pair_id` as conversion-rate compatible unless it already is.

    The contract appends blindly, so the check here is what keeps re-runs from
    registering duplicates. Returns True if a tx was sent.
    """
    (registered,) = await call(
        ORACLE, "get_registered_conversion_rate_pairs", port=port
    )
    if pair_id in registered:
        return False
    tx_hash = await invoke(
        ORACLE, "add_registered_conversion_rate_pair", [pair_id], port=port
    )
    logger.info(
        f"Registered conversion rate pair {hex(pair_id)} with tx {hex(tx_hash)}"
    )
    return True
