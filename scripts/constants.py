import os
import re
from enum import Enum
from pathlib import Path

from dotenv import load_dotenv
from empiric.core.types import Currency, Pair
from starknet_py.net.full_node_client import FullNodeClient

load_dotenv()

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
NETWORK = os.getenv("STARKNET_NETWORK", "starknet-devnet")
NETWORK = (
    "testnet"
    if re.match(r".*(testnet|goerli)$", NETWORK, flags=re.I)
    else "testnet2"
    if re.match(r".*(testnet|goerli)-?2$", NETWORK, flags=re.I)
    else "mainnet"
    if re.match(r".*(mainnet).*", NETWORK, flags=re.I)
    else "devnet"
)
STARKSCAN_URLS = {
    "mainnet": "https://starkscan.co",
    "testnet": "https://testnet.starkscan.co",
    "testnet2": "https://testnet-2.starkscan.co",
    "devnet": "https://devnet.starkscan.co",
}
STARKSCAN_URL = STARKSCAN_URLS[NETWORK]

if not os.getenv("RPC_KEY") and NETWORK in ["mainnet", "testnet", "testnet2"]:
    raise ValueError(f"RPC_KEY env variable is required when targeting {NETWORK}")
RPC_URLS = {
    "mainnet": f"https://starknet-mainnet.infura.io/v3/{os.getenv('RPC_KEY')}",
    "testnet": f"https://starknet-goerli.infura.io/v3/{os.getenv('RPC_KEY')}",
    "testnet2": f"https://starknet-goerli2.infura.io/v3/{os.getenv('RPC_KEY')}",
    "devnet": "http://127.0.0.1:5050/rpc",
}
RPC_CLIENT = FullNodeClient(node_url=RPC_URLS[NETWORK])


class ChainId(Enum):
    mainnet = int.from_bytes(b"SN_MAIN", "big")
    testnet = int.from_bytes(b"SN_GOERLI", "big")
    testnet2 = int.from_bytes(b"SN_GOERLI2", "big")
    devnet = int.from_bytes(b"SN_GOERLI", "big")


BUILD_DIR = Path("build")
BUILD_DIR.mkdir(exist_ok=True, parents=True)
SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}


ACCOUNT_ADDRESS = os.environ.get(
    f"{NETWORK.upper()}_ACCOUNT_ADDRESS"
) or os.environ.get("ACCOUNT_ADDRESS")
PRIVATE_KEY = os.environ.get(f"{NETWORK.upper()}_PRIVATE_KEY") or os.environ.get(
    "PRIVATE_KEY"
)

DEPLOYMENTS_DIR = Path("deployments") / NETWORK
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

# TODO: get CHAIN_ID from RPC endpoint when starknet-py doesn't expect an enum
CHAIN_ID = getattr(ChainId, NETWORK)
COMPILED_CONTRACTS = [
    {"contract_name": "oracle", "is_account_contract": False},
    {"contract_name": "admin", "is_account_contract": False},
    {"contract_name": "publisher_registry", "is_account_contract": False},
    {"contract_name": "proxy", "is_account_contract": False},
]

currencies = [
    Currency("USD", 8, 1, 0, 0),
    Currency(
        "BTC",
        18,
        0,
        0x03FE2B97C1FD336E750087D68B9B867997FD64A2661FF3CA5A7C771641E8E7AC,
        0x2260FAC5E5542A773AA44FBCFEDF7C193BC2C599,
    ),
    Currency(
        "ETH",
        18,
        0,
        0x049D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7,
        0x0000000000000000000000000000000000000000,
    ),
    Currency(
        "USDC",
        6,
        0,
        0x053C91253BC9682C04929CA02ED00B3E423F6710D2EE7E0D5EBB06F3ECF368A8,
        0xA0B86991C6218B36C1D19D4A2E9EB0CE3606EB48,
    ),
    Currency(
        "USDT",
        6,
        0,
        0x068F5C6A61780768455DE69077E07E89787839BF8166DECFBF92B645209C0FB8,
        0xDAC17F958D2EE523A2206206994597C13D831EC7,
    ),
    Currency(
        "DAI",
        18,
        0,
        0x001108CDBE5D82737B9057590ADAF97D34E74B5452F0628161D237746B6FE69E,
        0x6B175474E89094C44DA98B954EEDEAC495271D0F,
    ),
]
pairs = [
    Pair("ETH/USD", "ETH", "USD"),
    Pair("BTC/USD", "BTC", "USD"),
    Pair("USDC/USD", "USDC", "USD"),
    Pair("USDT/USD", "USDT", "USD"),
    Pair("DAI/USD", "DAI", "USD"),
]
