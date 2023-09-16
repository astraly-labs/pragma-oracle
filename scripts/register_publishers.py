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
    str_to_felt,
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
        0x0624EBFB99865079BD58CFCFB925B6F5CE940D6F6E41E118B8A72B7163FB435C,
        0xCF357FA043A29F7EA06736CC253D8D6D8A208C03B92FFB4B50074F8470818B,
        0x6BCDCF68F77A80571B55FC1651A26DC04939DFDD698485BE24FA5AC4DBF84B1,
        0x17A6F7E8196C9A7AFF90B7CC4BF98842894ECC2B9CC1A3703A1AAB948FCE208,
        0x1D8E01188C4C8984FB19F00156491787E64FD2DE1C3CE4EB9571924C540CF3B,
        0x4E2863FD0FF85803EEF98CE5DD8272AB21C6595537269A2CD855A10EBCC18CC,
    ]
    admin_address = 0x02356B628D108863BAF8644C945D97BAD70190AF5957031F4852D00D0F690A77


# %% Main
async def main():
    for publisher, sources, address in zip(
        publishers, publishers_sources, publisher_address
    ):
        (existing_address,) = await call(
            "pragma_PublisherRegistry", "get_publisher_address", publisher
        )
        if existing_address == 0:
            tx_hash = await invoke(
                "pragma_PublisherRegistry", "add_publisher", [publisher, address]
            )
            logger.info(f"Registered new publisher {publisher} with tx {hex(tx_hash)}")
        elif existing_address != address:
            logger.info(
                f"Publisher {publisher} registered with address {hex(existing_address)} but config has address {hex(address)}. Exiting..."
            )
            return

        (existing_sources,) = await call(
            "pragma_PublisherRegistry", "get_publisher_sources", publisher
        )
        new_sources = [x for x in sources if str_to_felt(x) not in existing_sources]
        if len(new_sources) > 0:
            tx_hash = await invoke(
                "pragma_PublisherRegistry",
                "add_sources_for_publisher",
                [publisher, len(new_sources), *new_sources],
            )
            logger.info(
                f"Registered sources {new_sources} for publisher {publisher} with tx {hex(tx_hash)}"
            )

    logger.info(f"ℹ️ Publisher Registry initialization completed. ")


if __name__ == "__main__":
    run(main())
