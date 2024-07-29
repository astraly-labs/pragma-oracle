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
]

DEX_SOURCES = ["MYSWAP", "MYSWAPV2", "EKUBO", "SITHSWAP", "JEDISWAP", "10KSWAP"]

PUBLISHERS = []
PUBLISHERS_SOURCES = []
PUBLISHER_ADDRESS = []

if NETWORK['name'] == "mainnet":
    PUBLISHERS = [
        "PRAGMA",
        "FOURLEAF",
        "SPACESHARD",
        "SKYNET_TRADING",
        "AVNU",
        "FLOWDESK",
    ]
    PUBLISHERS_SOURCES = [
        THIRD_PARTY_SOURCES,
        ["FOURLEAF"],
        THIRD_PARTY_SOURCES,
        ["SKYNET_TRADING"],
        ["AVNU"],
        ["FLOWDESK"],
    ]
    PUBLISHER_ADDRESS = [
        0x06707675CD7DD9256667ECA8284E46F4546711EE0054BC2DD02F0CE572056CF4,
        0x073335CC71C93FE46C04C14E09E7CDE7CA7F6147BB36C72DEE7968EC3ABAF70D,
        0x035DD30E84F7D61586C6B152524F3F2519DFC11B4DCB9998176B1DE9CFF9A6EA,
        0x0155E28E1947350DAC90112F3129B74E3A58D38132C8C26F8552002D78C3656E,
        0x00D8219CFB9927C3BABA540AB6684E94A58844EAE0C170F568BA4620BC10050F,
        0x077567C3F2B43FA349EF2CCDF3F928D53A7FC4EE38C2411E8330F0E558568BB9,
    ]
    admin_address = 0x02356B628D108863BAF8644C945D97BAD70190AF5957031F4852D00D0F690A77

if NETWORK['name'] == "sepolia":
    PUBLISHERS = ["PRAGMA", "FOURLEAF", "AVNU", "ALENO"]
    PUBLISHERS_SOURCES = [THIRD_PARTY_SOURCES, ["FOURLEAF"], ["AVNU"], ["ALENO"]]
    PUBLISHER_ADDRESS = [
        0x04C1D9DA136846AB084AE18CF6CE7A652DF7793B666A16CE46B1BF5850CC739D,
        0x037A10F2808C05F4A328BDAC9A9344358547AE4676EBDDC005E24FF887B188FD,
        0x0279FDE026E3E6CCEACB9C263FECE0C8D66A8F59E8448F3DA5A1968976841C62,
        0x06C58C048FC1483362D6AB56A542B74ADF5FD5C00706AEDA32EAD142E38B8646,
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
