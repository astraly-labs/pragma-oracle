import os
import logging

from dotenv import load_dotenv
from pathlib import Path

from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId

from pragma_sdk.common.types.currency import Currency
from pragma_sdk.common.types.pair import Pair

load_dotenv()

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

MAX_FEE = 70000000000000000  # 0.07 ETH

ETH_TOKEN_ADDRESS = "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7"

NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "rpc_url": "https://starknet-mainnet.public.blastapi.io/rpc/v0_7",
        "chain_id": StarknetChainId.MAINNET,
    },
    "sepolia": {
        "name": "sepolia",
        "explorer_url": "https://sepolia.starkscan.co/",
        "rpc_url": "https://starknet-sepolia.public.blastapi.io/rpc/v0_7",
        "chain_id": StarknetChainId.SEPOLIA,
    },
    "devnet": {
        "name": "devnet",
        "explorer_url": "https://devnet.starkscan.co",
        "rpc_url": "http://127.0.0.1:5050/rpc",
        "chain_id": StarknetChainId.SEPOLIA,
    },
    "pragma_devnet": {
        "name": "pragma-devnet",
        "explorer_url": "",
        "rpc_url": "http://pragma-devnet.karnot.xyz/",
        "chain_id": 93395501017206423887893332,
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

FULLNODE_CLIENT = FullNodeClient(
    node_url=NETWORK["rpc_url"],
)


CURRENT_FILE = Path(__file__).resolve()
REPO_ROOT = CURRENT_FILE.parent.parent.parent
PROJECT_ROOT = REPO_ROOT.parent / "pragma-oracle"

BUILD_DIR = PROJECT_ROOT / "target" / "dev"
BUILD_DIR.mkdir(exist_ok=True, parents=True)

SOURCE_DIR = PROJECT_ROOT / "src"
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}

DEPLOYMENTS_DIR = REPO_ROOT / "deployments" / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)


COMPILED_CONTRACTS = [
    {"contract_name": "pragma_Oracle", "is_account_contract": False},
    {"contract_name": "pragma_Ownable", "is_account_contract": False},
    {"contract_name": "pragma_PublisherRegistry", "is_account_contract": False},
    {"contract_name": "pragma_SummaryStats", "is_account_contract": False},
    {"contract_name": "pragma_Randomness", "is_account_contract": False},
    {"contract_name": "pragma_ExampleRandomness", "is_account_contract": False},
    {"contract_name": "pragma_YieldCurve", "is_account_contract": False},
    {"contract_name": "pragma_Pool", "is_account_contract": False},
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
        0x0319111A5037CBEC2B3E638CC34A3474E2D2608299F3E62866E9CC683208C610,
        0xAE78736CD615F374D3085123A210448E74FC6393,
    ),
    Currency(
        "LUSD",
        18,
        0,
        0x070A76FD48CA0EF910631754D77DD822147FE98A569B826EC85E3C33FDE586AC,
        0x5F98805A4E8BE255A32880FDEC7F6728C6568BA0,
    ),
    Currency(
        "UNI",
        18,
        0,
        0x049210FFC442172463F3177147C1AEAA36C51D152C1B0630F2364C300D4F48EE,
        0x1F9840A85D5AF5BF1D1762F925BDADDC4201F984,
    ),
]

# TODO: This should be a global Pragma configuration.
pairs = [
    Pair.from_tickers("ETH", "USD"),
    # Pair.from_tickers("ETH", "DAI"),
    Pair.from_tickers("BTC", "USD"),
    Pair.from_tickers("BTC", "EUR"),
    Pair.from_tickers("WBTC", "USD"),
    Pair.from_tickers("WBTC", "BTC"),
    Pair.from_tickers("WBTC", "ETH"),
    Pair.from_tickers("USDC", "USD"),
    Pair.from_tickers("USDT", "USD"),
    # Pair.from_tickers("DAI", "USD"),
    # Pair.from_tickers("LORDS", "USD"),
    Pair.from_tickers("LUSD", "USD"),
    Pair.from_tickers("LUSD", "ETH"),
    Pair.from_tickers("WSTETH", "USD"),
    Pair.from_tickers("WSTETH", "ETH"),
    # Pair.from_tickers("UNI", "USD"),
]
