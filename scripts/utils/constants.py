import os
import re
from enum import Enum
from pathlib import Path

from dotenv import load_dotenv
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId
from typing import List

load_dotenv()

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7

NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "feeder_gateway_url": "https://alpha-mainnet.starknet.io/feeder_gateway",
        "gateway_url": "https://alpha-mainnet.starknet.io/gateway",
    },
    "testnet": {
        "name": "testnet",
        "explorer_url": "https://testnet.starkscan.co",
        "rpc_url": f"https://starknet-goerli.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "feeder_gateway_url": "https://alpha4.starknet.io/feeder_gateway",
        "gateway_url": "https://alpha4.starknet.io/gateway",
    },
    "devnet": {
        "name": "devnet",
        "explorer_url": "https://devnet.starkscan.co",
        "rpc_url": "http://127.0.0.1:5050/rpc",
        "feeder_gateway_url": "http://localhost:5050/feeder_gateway",
        "gateway_url": "http://localhost:5050/gateway",
    },
    # "katana": {
    #     "name": "katana",
    #     "explorer_url": "",
    #     "rpc_url": "http://127.0.0.1:5050",
    #     "devnet": True,
    #     "check_interval": 0.1,
    #     "max_wait": 1,
    # },
}

NETWORK = NETWORKS[os.getenv("STARKNET_NETWORK", "devnet")]
NETWORK["account_address"] = os.environ.get(
    f"{NETWORK['name'].upper()}_ACCOUNT_ADDRESS"
)
if NETWORK["account_address"] is None:
    logger.warning(
        f"⚠️ {NETWORK['name'].upper()}_ACCOUNT_ADDRESS not set, defaulting to ACCOUNT_ADDRESS"
    )
    NETWORK["account_address"] = os.getenv("ACCOUNT_ADDRESS")
NETWORK["private_key"] = os.environ.get(f"{NETWORK['name'].upper()}_PRIVATE_KEY")
if NETWORK["private_key"] is None:
    logger.warning(
        f"⚠️  {NETWORK['name'].upper()}_PRIVATE_KEY not set, defaulting to PRIVATE_KEY"
    )
    NETWORK["private_key"] = os.getenv("PRIVATE_KEY")
if NETWORK["name"] == "mainnet":
    NETWORK["chain_id"] = StarknetChainId.MAINNET
elif NETWORK["name"] == "testnet2":
    StarknetChainId.TESTNET2
else:
    NETWORK["chain_id"] = StarknetChainId.TESTNET


GATEWAY_CLIENT = GatewayClient(
    net={
        "feeder_gateway_url": NETWORK["feeder_gateway_url"],
        "gateway_url": NETWORK["gateway_url"],
    }
)




BUILD_DIR = Path("target/dev")
BUILD_DIR.mkdir(exist_ok=True, parents=True)
SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}

DEPLOYMENTS_DIR = Path("deployments") / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "pragma_Oracle", "is_account_contract": False},
    {"contract_name": "pragma_Admin", "is_account_contract": False},
    {"contract_name": "pragma_PublisherRegistry", "is_account_contract": False},
    {"contract_name": "pragma_SummaryStats", "is_account_contract": False},
]

def str_to_felt(text):
    if text.upper() != text:
        logger.warning(f"Converting lower to uppercase for str_to_felt: {text}")
        text = text.upper()
    b_text = bytes(text, "utf-8")
    return int.from_bytes(b_text, "big")

class Currency:
    id: int
    decimals: int
    is_abstract_currency: bool
    starknet_address: int
    ethereum_address: int

    def __init__(
        self,
        id,
        decimals,
        is_abstract_currency,
        starknet_address=None,
        ethereum_address=None,
    ):
        if type(id) == str:
            id = str_to_felt(id)
        self.id = id

        self.decimals = decimals

        if type(is_abstract_currency) == int:
            is_abstract_currency = bool(is_abstract_currency)
        self.is_abstract_currency = is_abstract_currency

        if starknet_address is None:
            starknet_address = 0
        self.starknet_address = starknet_address

        if ethereum_address is None:
            ethereum_address = 0
        self.ethereum_address = ethereum_address

    def serialize(self) -> List[str]:
        return [
            self.id,
            self.decimals,
            self.is_abstract_currency,
            self.starknet_address,
            self.ethereum_address,
        ]

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "decimals": self.decimals,
            "is_abstract_currency": self.is_abstract_currency,
            "starknet_address": self.starknet_address,
            "ethereum_address": self.ethereum_address,
        }


class Pair:
    id: int
    quote_currency_id: int
    base_currency_id: int

    def __init__(self, id, quote_currency_id, base_currency_id):
        if type(id) == str:
            id = str_to_felt(id)
        self.id = id

        if type(quote_currency_id) == str:
            quote_currency_id = str_to_felt(quote_currency_id)
        self.quote_currency_id = quote_currency_id

        if type(base_currency_id) == str:
            base_currency_id = str_to_felt(base_currency_id)
        self.base_currency_id = base_currency_id

    def serialize(self) -> List[str]:
        return [self.id, self.quote_currency_id, self.base_currency_id]

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "quote_currency_id": self.quote_currency_id,
            "base_currency_id": self.base_currency_id,
        }


currencies = [
    Currency("USD", 8, 1, 0, 0),
    Currency(
        "BTC",
        8,
        1,
        0,
        0,
    ),
    Currency(
        "WBTC",
        8,
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
    Pair("WBTC/USD", "WBTC", "USD"),
    Pair("USDC/USD", "USDC", "USD"),
    Pair("USDT/USD", "USDT", "USD"),
    Pair("DAI/USD", "DAI", "USD"),
]
