import os
import asyncio
import click
import logging

from typing import Optional

from dotenv import load_dotenv
from pragma_utils.logger import setup_logging

from pragma_deployer.utils.constants import (
    NETWORK,
)
from pragma_deployer.utils.starknet import (
    invoke,
    call,
    str_to_felt,
)

load_dotenv()

logger = logging.getLogger(__name__)

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
    "EKUBO",
    "DEXSCREENER",
    "PYTH",
    "UPBIT",
    "LBANK",
    "BITGET",
    "RE7_ONCHAIN",
    "CHAINLINK",
    "REDSTONE",
    "USN_ORACLE",
    "SUSN_VAULT",
    "WSTETH_RATE",
    "LIDO",
    "CHAINLINK_WSTETH",
    "REDSTONE_WSTETH",
    "ERC4626",
    "CUSTOM"
]

BTCFI_SOURCES = [
    "RE7_ONCHAIN",
    "CHAINLINK",
    "REDSTONE",
    "PYTH",
    "BYBIT",
    "BINANCE",
    "HUOBI",
    "OKX",
    "KUCOIN",
    "MEXC",
    "GATEIO",
    "EKUBO",
    "DEXSCREENER",
    "UPBIT",
    "LBANK",
    "BITGET",
    "BITSTAMP",
    "COINBASE",
    "DEFILLAMA",
    "STARKNET",
    "USN_ORACLE",
    "SUSN_VAULT",
    "WSTETH_RATE",
    "LIDO",
    "CHAINLINK_WSTETH",
    "REDSTONE_WSTETH",
    "ERC4626",
    "CUSTOM"
]

DEX_SOURCES = ["MYSWAP", "MYSWAPV2", "EKUBO", "SITHSWAP", "JEDISWAP", "10KSWAP"]

PUBLISHERS = []
PUBLISHERS_SOURCES = []
PUBLISHER_ADDRESS = []

if NETWORK["name"] == "mainnet":
    PUBLISHERS = [
        "PRAGMA",
        "AVNU",
        "ARGENT",
        "STARKWARE",
        "STARKNET_FOUNDATION",
    ]
    PUBLISHERS_SOURCES = [
        THIRD_PARTY_SOURCES,
        ["AVNU"],
        BTCFI_SOURCES,
        BTCFI_SOURCES,
        BTCFI_SOURCES,
    ]
    PUBLISHER_ADDRESS = [
        0x06707675CD7DD9256667ECA8284E46F4546711EE0054BC2DD02F0CE572056CF4,
        0x00D8219CFB9927C3BABA540AB6684E94A58844EAE0C170F568BA4620BC10050F,
        0x03235745f167c21fdc2cc2b17f54b55b73d7f2a399cc10df06d5c7f2a5dd6515,
        0x05753e99d2fc3132465704a7cc5c2ec8458b17c00aaf3c4deabdc65c29280641,
        0x049f7cd6661e0d5df1e27f4636e310b055c6ebbf2d5a87d6514d68b496134903,
    ]
    admin_address = 0x02356B628D108863BAF8644C945D97BAD70190AF5957031F4852D00D0F690A77

if NETWORK["name"] == "sepolia":
    PUBLISHERS = [
        "PRAGMA",
        "PRAGMA_MERKLE",
        "AVNU",
        "ARGENT_NEW",
        "STARKNET_FOUNDATION",
    ]
    PUBLISHERS_SOURCES = [
        THIRD_PARTY_SOURCES,
        ["DERIBIT"],
        ["AVNU"],
        BTCFI_SOURCES,
        BTCFI_SOURCES,
    ]
    PUBLISHER_ADDRESS = [
        0x04C1D9DA136846AB084AE18CF6CE7A652DF7793B666A16CE46B1BF5850CC739D,
        0x064B4DACEA78C6394572F4534400ABB74A872A059B68630FBA80895C646AA97F,
        0x0279FDE026E3E6CCEACB9C263FECE0C8D66A8F59E8448F3DA5A1968976841C62,
        0x02a4870252a657e94c839ea4a575d3a6ae98abd8f06d7946b92fff650a8c6756,
        0x0553561437e2c2644afd8a1c49276552bb8e3b3209bb534a1b35ea38e13254aa,
    ]

async def main(port: Optional[int]) -> None:
    """
    Main function to initialize the Publisher Registry.
    """
    logger.info("🚀 Initializing Publisher Registry...")
    for publisher, sources, address in zip(
        PUBLISHERS, PUBLISHERS_SOURCES, PUBLISHER_ADDRESS
    ):
        (existing_address,) = await call(
            "pragma_PublisherRegistry",
            "get_publisher_address",
            publisher,
            port=port,
        )
        if existing_address == 0:
            tx_hash = await invoke(
                "pragma_PublisherRegistry",
                "add_publisher",
                [publisher, address],
                port=port,
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
            port=port,
        )
        new_sources = [x for x in sources if str_to_felt(x) not in existing_sources]
        if len(new_sources) > 0:
            tx_hash = await invoke(
                "pragma_PublisherRegistry",
                "add_sources_for_publisher",
                [publisher, len(new_sources), *new_sources],
                port=port,
            )
            logger.info(
                f"Registered sources {new_sources} for publisher {publisher} with tx {hex(tx_hash)}"
            )

    logger.info("ℹ️ Publisher Registry initialization completed.")


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
    "-p",
    "--port",
    type=click.IntRange(min=0),
    required=False,
    help="Port number (required for Devnet network)",
)
def cli_entrypoint(log_level: str, port: Optional[int]) -> None:
    """
    CLI entrypoint to initialize the Publisher Registry.
    """
    setup_logging(logger, log_level)

    if os.getenv("STARKNET_NETWORK") == "devnet" and port is None:
        raise click.UsageError('⛔ "--port" must be set for Devnet.')

    asyncio.run(main(port))


if __name__ == "__main__":
    cli_entrypoint()
