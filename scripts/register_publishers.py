# %% Imports
import logging
from asyncio import run
from math import ceil, log

from scripts.utils.constants import (
    COMPILED_CONTRACTS,
    currencies,
    NETWORK,
    pairs,
)
from scripts.utils.starknet import (
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_eth_contract,
    get_starknet_account,
    invoke,
    deploy_v2,
    declare_v2,
    call,
    get_deployments,
    str_to_felt
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

THIRD_PARTY_SOURCES = [
  "ASCENDEX",
  "BITSTAMP",
  "CEX",
  "COINBASE",
  "DEFILLAMA",
  "GEMINI",
  "KAIKO",
  "OKX",
  "BINANCE",
  "BYBIT",
  "GECKOTERMINAL",
]

network = "testnet"

# TODO: load data from JSON/YAML
"""
TESTNET
"""
if network == "testnet":
    publishers = [
        "PRAGMA",
        "EQUILIBRIUM",
        "ARGENT",
        "GEMINI",
        "SKYNET_TRADING",
        "FOURLEAF",
    ]
    publishers_sources = [
        THIRD_PARTY_SOURCES,
        THIRD_PARTY_SOURCES,
        THIRD_PARTY_SOURCES,
        ["GEMINI"],
        ["SKYNET_TRADING", "SKYNET"],
        ["FOURLEAF"],
    ]
    publisher_address = [
        0x0624EBFb99865079bd58CFCFB925B6F5Ce940D6F6e41E118b8A72B7163fB435c,
        0xcf357fa043a29f7ea06736cc253d8d6d8a208c03b92ffb4b50074f8470818b,
        0x6bcdcf68f77a80571b55fc1651a26dc04939dfdd698485be24fa5ac4dbf84b1,
        0x17a6f7e8196c9a7aff90b7cc4bf98842894ecc2b9cc1a3703a1aab948fce208,
        0x1d8e01188c4c8984fb19f00156491787e64fd2de1c3ce4eb9571924c540cf3b,
        0x4e2863fd0ff85803eef98ce5dd8272ab21c6595537269a2cd855a10ebcc18cc
    ]
    admin_address = 0x02356b628D108863BAf8644c945d97bAD70190AF5957031f4852d00D0F690a77



# %% Main
async def main():

  deployments = get_deployments()

  for publisher, sources, address in zip(
        publishers, publishers_sources, publisher_address
    ):
    (existing_address,) = await call("pragma_PublisherRegistry", "get_publisher_address", publisher)
    if existing_address == 0:
        tx_hash = await invoke("pragma_PublisherRegistry", "add_publisher", [publisher, address])
        logger.info(f"Registered new publisher {publisher} with tx {hex(tx_hash)}")
    elif existing_address != address:
        logger.info(
            f"Publisher {publisher} registered with address {hex(existing_address)} but config has address {hex(address)}. Exiting..."
        )
        return

    (existing_sources,) = await call("pragma_PublisherRegistry", "get_publisher_sources", publisher)
    new_sources = [x for x in sources if str_to_felt(x) not in existing_sources]
    if len(new_sources) > 0:
        tx_hash = await invoke("pragma_PublisherRegistry", "add_sources_for_publisher", [publisher, len(new_sources), *new_sources])
        logger.info(
            f"Registered sources {new_sources} for publisher {publisher} with tx {hex(tx_hash)}"
        )
  
  logger.info(
      f"ℹ️  Sources added for publisher 'PRAGMA' "
  )

if __name__ == "__main__":
  run(main())