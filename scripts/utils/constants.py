import os
import logging
from enum import Enum
from pathlib import Path

from dotenv import load_dotenv
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from pragma.core.types import Currency, Pair
from typing import List

load_dotenv()

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

ETH_TOKEN_ADDRESS = "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7"

NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "rpc_url": f"https://starknet-goerli.g.alchemy.com/v2/{os.getenv('RPC_KEY')}",
    },
    "testnet": {
        "name": "testnet",
        "explorer_url": "https://testnet.starkscan.co",
        "rpc_url": f"https://starknet-goerli.g.alchemy.com/v2/{os.getenv('RPC_KEY')}",
    },
    "devnet": {
        "name": "devnet",
        "explorer_url": "https://devnet.starkscan.co",
        "rpc_url": "http://127.0.0.1:5050/rpc",
    },
    "sepolia": {
        "name": "sepolia",
        "explorer_url": "https://sepolia.starkscan.co/",
        "rpc_url": "https://starknet-sepolia.public.blastapi.io/rpc/v0_6",
    },
    "katana": {
        "name": "katana",
        "explorer_url": "",
        "rpc_url": "http://127.0.0.1:5050/rpc",
    },
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
elif NETWORK["name"] == "sepolia":
    NETWORK["chain_id"] = 393402133025997798000961 #To be replaced with starknet_py upgrade
else:
    NETWORK["chain_id"] = StarknetChainId.TESTNET


FULLNODE_CLIENT = FullNodeClient(
        node_url= os.getenv("FORK_RPC_URL"),
)




BUILD_DIR = Path("target/dev")
BUILD_DIR.mkdir(exist_ok=True, parents=True)

SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}

DEPLOYMENTS_DIR = Path("deployments") / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "pragma_Oracle", "is_account_contract": False},
    {"contract_name": "pragma_Ownable", "is_account_contract": False},
    {"contract_name": "pragma_PublisherRegistry", "is_account_contract": False},
    {"contract_name": "pragma_SummaryStats", "is_account_contract": False},
    {"contract_name": "pragma_Randomness", "is_account_contract": False},
    {"contract_name": "pragma_ExampleRandomness", "is_account_contract": False},
    {"contract_name": "pragma_YieldCurve", "is_account_contract": False},
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
        "WSTETH",
        18,
        0,
        0x042B8F0484674CA266AC5D08E4AC6A3FE65BD3129795DEF2DCA5C34ECC5F96D2,
        0x7F39C581F595B53C5CB19BD0B3F8DA6C935E2CA0,
    ),
    Currency(
        "RETH",
        18,
        0,
        0x0319111a5037cbec2b3e638cc34a3474e2d2608299f3e62866e9cc683208c610,
        0xae78736cd615f374d3085123a210448e74fc6393,
    ),
    Currency(
        "LUSD",
        18,
        0,
        0x070a76fd48ca0ef910631754d77dd822147fe98a569b826ec85e3c33fde586ac,
        0x5f98805a4e8be255a32880fdec7f6728c6568ba0,
    ),
    Currency(
        "UNI",
        18,
        0,
        0x049210ffc442172463f3177147c1aeaa36c51d152c1b0630f2364c300d4f48ee,
        0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,
    ),
]
pairs = [
    Pair("ETH/USD", "ETH", "USD"),
    Pair("ETH/DAI", "ETH", "DAI"),
    Pair("BTC/USD", "BTC", "USD"),
    Pair("BTC/EUR", "BTC", "EUR"),
    Pair("WBTC/USD", "WBTC", "USD"),
    Pair("WBTC/BTC", "WBTC", "BTC"),
    Pair("WBTC/ETH", "WBTC", "ETH"),
    Pair("USDC/USD", "USDC", "USD"),
    Pair("USDT/USD", "USDT", "USD"),
    Pair("DAI/USD", "DAI", "USD"),
    Pair("LORDS/USD", "LORDS", "USD"),
    Pair("LUSD/USD", "LUSD", "USD"),
    Pair("LUSD/ETH", "LUSD", "ETH"),
    Pair("WSTETH/USD", "WSTETH", "USD"),
    Pair("WSTETH/ETH", "WSTETH", "USD"),
    Pair("UNI/USD", "UNI", "USD"),
]
