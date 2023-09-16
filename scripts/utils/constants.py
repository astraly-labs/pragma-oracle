import os
import logging
from enum import Enum
from pathlib import Path

from dotenv import load_dotenv
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId
from pragma.core.types import Currency, Pair
from typing import List

load_dotenv()

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

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


currencies = [
    Currency("USD", 8, 1, 0, 0),
    Currency("EUR", 8, 1, 0, 0),
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
    Currency(
        "LORDS",
        18,
        0,
        0x0124AEB495B947201F5FAC96FD1138E326AD86195B98DF6DEC9009158A533B49,
        0x686F2404E77AB0D9070A46CDFB0B7FECDD2318B0,
    ),
    Currency(
        "R",
        18,
        0,
        0x01FA2FB85F624600112040E1F3A848F53A37ED5A7385810063D5FE6887280333,
        0x183015A9BA6FF60230FDEADC3F43B3D788B13E21,
    ),
    Currency(
        "WSTETH",
        18,
        0,
        0x042B8F0484674CA266AC5D08E4AC6A3FE65BD3129795DEF2DCA5C34ECC5F96D2,
        0x7F39C581F595B53C5CB19BD0B3F8DA6C935E2CA0,
    ),
]
pairs = [
    Pair("ETH/USD", "ETH", "USD"),
    Pair("ETH/USDT", "ETH", "USDT"),
    Pair("BTC/USD", "BTC", "USD"),
    Pair("BTC/USDT", "BTC", "USDT"),
    Pair("BTC/EUR", "BTC", "EUR"),
    Pair("WBTC/USD", "WBTC", "USD"),
    Pair("WBTC/BTC", "WBTC", "BTC"),
    Pair("USDC/USD", "USDC", "USD"),
    Pair("USDT/USD", "USDT", "USD"),
    Pair("DAI/USD", "DAI", "USD"),
    Pair("LORDS/USD", "LORDS", "USD"),
    Pair("R/USD", "R", "USD"),
    Pair("WSTETH/USD", "WSTETH", "USD"),
]
