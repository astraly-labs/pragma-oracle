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
import os
from dotenv import load_dotenv
import argparse
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

load_dotenv()
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
    "STARKNET",
    "PROPELLER",
    "KUCOIN",
    "BINANCE",
    "HUOBI",
    "BYBIT",
    "INDEXCOOP",
    "MEXC",
    "GATEIO",
]

DEX_SOURCES = [
    "MYSWAP",
    "MYSWAPV2",
    "EKUBO",
    "SITHSWAP",
    "JEDISWAP",
    "10KSWAP",
]

network = "sepolia"


"""
MAINNET
"""
if network == "mainnet":
    publishers = [
        "PRAGMA",
        "FOURLEAF",
        "SPACESHARD",
        "SKYNET_TRADING",
        "AVNU",
        "FLOWDESK",
    ]
    publishers_sources = [
        THIRD_PARTY_SOURCES,
        ["FOURLEAF"],
        THIRD_PARTY_SOURCES,
        ["SKYNET_TRADING"],
        ["AVNU"],
        ["FLOWDESK"],
    ]
    publisher_address = [
        0x06707675CD7DD9256667ECA8284E46F4546711EE0054BC2DD02F0CE572056CF4,
        0x073335CC71C93FE46C04C14E09E7CDE7CA7F6147BB36C72DEE7968EC3ABAF70D,
        0x035DD30E84F7D61586C6B152524F3F2519DFC11B4DCB9998176B1DE9CFF9A6EA,
        0x0155E28E1947350DAC90112F3129B74E3A58D38132C8C26F8552002D78C3656E,
        0x00D8219CFB9927C3BABA540AB6684E94A58844EAE0C170F568BA4620BC10050F,
        0x077567C3F2B43FA349EF2CCDF3F928D53A7FC4EE38C2411E8330F0E558568BB9,
    ]
    admin_address = 0x02356B628D108863BAF8644C945D97BAD70190AF5957031F4852D00D0F690A77

if network == "sepolia":
    publishers = ["PRAGMA", "FOURLEAF", "AVNU"]
    publishers_sources = [
        THIRD_PARTY_SOURCES,
        ["FOURLEAF"],
        ["AVNU"],
    ]
    publisher_address = [
        0x04C1D9DA136846AB084AE18CF6CE7A652DF7793B666A16CE46B1BF5850CC739D,
        0x037A10F2808C05F4A328BDAC9A9344358547AE4676EBDDC005E24FF887B188FD,
        0x0279FDE026E3E6CCEACB9C263FECE0C8D66A8F59E8448F3DA5A1968976841C62,
    ]


# %% Main
async def main():
    parser = argparse.ArgumentParser(description="Deploy contracts to Katana")
    parser.add_argument("--port", type=int, help="Port number", required=False)
    args = parser.parse_args()
    if os.getenv("STARKNET_NETWORK") == "katana" and args.port is None:
        logger.warning(f"⚠️  --port not set, defaulting to 5050")
        args.port = 5050
    for publisher, sources, address in zip(
        publishers, publishers_sources, publisher_address
    ):
        (existing_address,) = await call(
            "pragma_PublisherRegistry",
            "get_publisher_address",
            publisher,
            port=args.port,
        )
        if existing_address == 0:
            tx_hash = await invoke(
                "pragma_PublisherRegistry",
                "add_publisher",
                [publisher, address],
                port=args.port,
            )
            logger.info(f"Registered new publisher {publisher} with tx {hex(tx_hash)}")
        elif existing_address != address:
            logger.info(
                f"Publisher {publisher} registered with address {hex(existing_address)} but config has address {hex(address)}. Exiting..."
            )
            return

        (existing_sources,) = await call(
            "pragma_PublisherRegistry",
            "get_publisher_sources",
            publisher,
            port=args.port,
        )
        new_sources = [x for x in sources if str_to_felt(x) not in existing_sources]
        if len(new_sources) > 0:
            tx_hash = await invoke(
                "pragma_PublisherRegistry",
                "add_sources_for_publisher",
                [publisher, len(new_sources), *new_sources],
                port=args.port,
            )
            logger.info(
                f"Registered sources {new_sources} for publisher {publisher} with tx {hex(tx_hash)}"
            )

    logger.info(f"ℹ️ Publisher Registry initialization completed. ")


if __name__ == "__main__":
    run(main())
