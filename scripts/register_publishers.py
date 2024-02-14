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
]

DEX_SOURCES = [
    "MYSWAP",
    "MYSWAPV2",
    "EKUBO",
    "SITHSWAP",
    "JEDISWAP",
    "10KSWAP",
]

network = "mainnet"

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
        "NETHERMIND",
        "FLOWDESK",
        "CRYPTOMENTUM",
        "AVNU",
        "SPACESHARD",
    ]
    publishers_sources = [
        THIRD_PARTY_SOURCES,
        THIRD_PARTY_SOURCES,
        THIRD_PARTY_SOURCES,
        ["GEMINI"],
        ["SKYNET_TRADING", "SKYNET"],
        ["FOURLEAF"],
        THIRD_PARTY_SOURCES,
        ["FLOWDESK"],
        ["CRYPTOMENTUM"],
        ["AVNU"] + DEX_SOURCES,
        THIRD_PARTY_SOURCES,
    ]
    publisher_address = [
        0x0624EBFB99865079BD58CFCFB925B6F5CE940D6F6E41E118B8A72B7163FB435C,
        0xCF357FA043A29F7EA06736CC253D8D6D8A208C03B92FFB4B50074F8470818B,
        0x01DAA5CB5F56D96832990DDF4EB9D4F09BA72AFF39AF13028AF67DCE9934A74C,
        0x17A6F7E8196C9A7AFF90B7CC4BF98842894ECC2B9CC1A3703A1AAB948FCE208,
        0x1D8E01188C4C8984FB19F00156491787E64FD2DE1C3CE4EB9571924C540CF3B,
        0x4E2863FD0FF85803EEF98CE5DD8272AB21C6595537269A2CD855A10EBCC18CC,
        0x022641362F12D72103F3BADFBDC8E1A77FCA91EB1F3835638EEC55EBCAEAAFFD,
        0x0264CD871A4B5A6B441EB2862B3785E01C4CB82A133E3A65A01827BB8DF4B871,
        0x5B1400D876CAAA7BA7858DF28FAA73A16318AB8551397D83016FB33CB590B28,
        0x052D8E9778D026588A51595E30B0F45609B4F771EECF0E335CDEFED1D84A9D89,
        0x0271E25BF6EF39B48AB319456C7DB88767F0B38D53E1285C5B3E901C60CD878C,
    ]
    admin_address = 0x02356B628D108863BAF8644C945D97BAD70190AF5957031F4852D00D0F690A77

"""
MAINNET
"""
if network == "mainnet":
    publishers = ["PRAGMA", "FOURLEAF", "SPACESHARD", "SKYNET_TRADING"]
    publishers_sources = [
        THIRD_PARTY_SOURCES,
        ["FOURLEAF"],
        THIRD_PARTY_SOURCES,
        ["SKYNET_TRADING"],
    ]
    publisher_address = [
        0x06707675CD7DD9256667ECA8284E46F4546711EE0054BC2DD02F0CE572056CF4,
        0x073335CC71C93FE46C04C14E09E7CDE7CA7F6147BB36C72DEE7968EC3ABAF70D,
        0x035DD30E84F7D61586C6B152524F3F2519DFC11B4DCB9998176B1DE9CFF9A6EA,
        0x0155E28E1947350DAC90112F3129B74E3A58D38132C8C26F8552002D78C3656E,
    ]
    admin_address = 0x02356B628D108863BAF8644C945D97BAD70190AF5957031F4852D00D0F690A77

if network == "sepolia":
    publishers = ["PRAGMA", "EQUILIBRIUM", "FOURLEAF", "SPACESHARD", "FLOVTEC"]
    publishers_sources = [
        THIRD_PARTY_SOURCES,
        THIRD_PARTY_SOURCES,
        ["FOURLEAF"],
        THIRD_PARTY_SOURCES,
        ["FLOVTEC"],
    ]
    publisher_address = [
        0x04C1D9DA136846AB084AE18CF6CE7A652DF7793B666A16CE46B1BF5850CC739D,
        0x021D17FAF34B5E25D88C79BB1EAD9B9651C9599C49833555030EB5AC430F73DD,
        0x037A10F2808C05F4A328BDAC9A9344358547AE4676EBDDC005E24FF887B188FD,
        0x00005DE00D3720421AB00FDBC47D33D253605C1AC226AB1A0D267F7D57E23305,
        0x07CB0DCA5767F238B056665D2F8350E83A2DEE7EAC8EC65E66BBC790A4FECE8A,
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
