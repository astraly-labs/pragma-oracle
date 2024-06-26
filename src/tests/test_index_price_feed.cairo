use array::ArrayTrait;
use option::OptionTrait;
use result::ResultTrait;
use starknet::ContractAddress;
use pragma::entry::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntries, FutureEntry, OptionEntry,
    AggregationMode, SimpleDataType
};
use starknet::class_hash::class_hash_const;
use traits::Into;
use serde::Serde;
use traits::TryInto;
use alexandria_math::pow;
use pragma::oracle::oracle::Oracle;
use pragma::compute_engines::summary_stats::summary_stats::SummaryStats;
use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
use pragma::publisher_registry::publisher_registry::{
    IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
};
use pragma::compute_engines::index_price_feed::index_price_feed::{IndexPriceFeed, Composition};
use pragma::compute_engines::index_price_feed::index_price_feed::{
    IIndexPriceFeedDispatcher, IIndexPriceFeedDispatcherTrait
};
use starknet::SyscallResultTrait;
use starknet::contract_address::contract_address_const;
use pragma::publisher_registry::publisher_registry::PublisherRegistry;
use starknet::testing::{
    set_caller_address, set_contract_address, set_block_timestamp, set_chain_id,
};
use starknet::syscalls::deploy_syscall;
use debug::PrintTrait;

const CHAIN_ID: felt252 = 'SN_MAIN';
const BLOCK_TIMESTAMP: u64 = 103374042;
const NOW: u64 = 100000;


impl CompositionEq of PartialEq<Composition> {
    fn eq(lhs: @Composition, rhs: @Composition) -> bool {
        (*lhs.asset == *rhs.asset)
            & (*lhs.weight == *rhs.weight)
            & (*lhs.weight_decimals == *rhs.weight_decimals)
    }

    #[inline(always)]
    fn ne(lhs: @Composition, rhs: @Composition) -> bool {
        !(lhs == rhs)
    }
}


impl PragmaPricesResponseEq of PartialEq<PragmaPricesResponse> {
    fn eq(lhs: @PragmaPricesResponse, rhs: @PragmaPricesResponse) -> bool {
        (*lhs.price == *rhs.price)
            & (*lhs.decimals == *rhs.decimals)
            & (*lhs.last_updated_timestamp == *rhs.last_updated_timestamp)
            & (*lhs.num_sources_aggregated == *rhs.num_sources_aggregated)
            & (*lhs.expiration_timestamp == *rhs.expiration_timestamp)
    }

    #[inline(always)]
    fn ne(lhs: @PragmaPricesResponse, rhs: @PragmaPricesResponse) -> bool {
        !(lhs == rhs)
    }
}

fn setup() -> (IIndexPriceFeedDispatcher, IOracleABIDispatcher) {
    let mut currencies = ArrayTrait::<Currency>::new();
    currencies
        .append(
            Currency {
                id: 'INDEX1',
                decimals: 18_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .try_into()
                    .unwrap(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.try_into().unwrap(), // optional
            }
        );

    currencies
        .append(
            Currency {
                id: 'INDEX2',
                decimals: 18_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .try_into()
                    .unwrap(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.try_into().unwrap(), // optional
            }
        );
    currencies
        .append(
            Currency {
                id: 'INDEX3',
                decimals: 18_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .try_into()
                    .unwrap(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.try_into().unwrap(), // optional
            }
        );

    currencies
        .append(
            Currency {
                id: 'USD',
                decimals: 6_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .try_into()
                    .unwrap(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.try_into().unwrap(), // optional
            }
        );

    let mut pairs = ArrayTrait::<Pair>::new();
    pairs
        .append(
            Pair {
                id: 'INDEX1/USD', // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 'INDEX1', // currency id - str_to_felt encode the ticker
                base_currency_id: 'USD', // currency id - str_to_felt encode the ticker
            }
        );
    pairs
        .append(
            Pair {
                id: 'INDEX2/USD', // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 'INDEX2', // currency id - str_to_felt encode the ticker
                base_currency_id: 'USD', // currency id - str_to_felt encode the ticker
            }
        );
    pairs
        .append(
            Pair {
                id: 'INDEX3/USD', // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 'INDEX3', // currency id - str_to_felt encode the ticker
                base_currency_id: 'USD', // currency id - str_to_felt encode the ticker
            }
        );
    pairs
        .append(
            Pair {
                id: 'INDEX3/INDEX2', // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 'INDEX3', // currency id - str_to_felt encode the ticker
                base_currency_id: 'INDEX2', // currency id - str_to_felt encode the ticker
            }
        );
    let admin = contract_address_const::<0x123456789>();
    set_contract_address(admin);
    set_block_timestamp(BLOCK_TIMESTAMP);
    set_chain_id(CHAIN_ID);
    let now = NOW;
    //Deploy the registry
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(admin.into());
    let (publisher_registry_address, _) = deploy_syscall(
        PublisherRegistry::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), true
    )
        .unwrap_syscall();
    let mut publisher_registry = IPublisherRegistryABIDispatcher {
        contract_address: publisher_registry_address
    };

    //Deploy the oracle
    let mut oracle_calldata = ArrayTrait::<felt252>::new();
    admin.serialize(ref oracle_calldata);
    publisher_registry_address.serialize(ref oracle_calldata);
    currencies.serialize(ref oracle_calldata);
    pairs.serialize(ref oracle_calldata);
    let (oracle_address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, oracle_calldata.span(), true
    )
        .unwrap_syscall();

    let mut oracle = IOracleABIDispatcher { contract_address: oracle_address };
    let mut feed_calldata = ArrayTrait::<felt252>::new();
    oracle_address.serialize(ref feed_calldata);
    let (index_price_feed_address, _) = deploy_syscall(
        IndexPriceFeed::TEST_CLASS_HASH.try_into().unwrap(), 0, feed_calldata.span(), true
    )
        .unwrap_syscall();
    let mut index_price_feed = IIndexPriceFeedDispatcher {
        contract_address: index_price_feed_address
    };

    set_contract_address(admin);
    publisher_registry.add_publisher(1, admin);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(1, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(1, 2);
    starknet::testing::set_block_timestamp(now);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 'INDEX1/USD',
                    price: 2 * 1000000,
                    volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 1 },
                    pair_id: 'INDEX1/USD',
                    price: 3 * 1000000,
                    volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 'INDEX2/USD',
                    price: 4 * 1000000,
                    volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 'INDEX3/USD',
                    price: 4 * 1000000,
                    volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 'INDEX3/INDEX2',
                    price: 6 * pow(10, 18),
                    volume: 0
                }
            )
        );

    (index_price_feed, oracle)
}


fn create_price_index(index_name: felt252) -> IIndexPriceFeedDispatcher {
    let (price_index_feed, oracle) = setup();
    let owner = contract_address_const::<0x123456789>();
    set_contract_address(owner);
    let assets = array![
        Composition {
            asset: DataType::SpotEntry('INDEX1/USD'), weight: 20000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX2/USD'), weight: 60000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX3/USD'), weight: 20000000, weight_decimals: 8
        },
    ];
    let sources = array![];
    price_index_feed.create_price_index(index_name, assets.clone(), sources.clone());
    return price_index_feed;
}

#[test]
#[available_gas(200000000000000000)]
fn test_create_price_index() {
    let index_name = 'INDEX_COMPOSITION';
    let (price_index_feed, oracle) = setup();
    let owner = contract_address_const::<0x123456789>();
    let assets = array![
        Composition {
            asset: DataType::SpotEntry('INDEX1/USD'), weight: 20000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX2/USD'), weight: 60000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX3/USD'), weight: 20000000, weight_decimals: 8
        },
    ];
    let sources = array![];
    price_index_feed.create_price_index(index_name, assets.clone(), sources.clone());
    let composition_configuration = price_index_feed.get_index_price_composition(index_name);
    assert(composition_configuration == assets, 'Wrong composition');
    let sources_configuration = price_index_feed.get_index_price_sources(index_name);
    assert(sources_configuration == sources, 'Wrong sources');
    assert(price_index_feed.get_index_price_owner(index_name) == owner, 'Wrong owner');
}

#[test]
#[should_panic(expected: ('Caller is not index owner', 'ENTRYPOINT_FAILED'))]
#[available_gas(200000000000000000)]
fn test_update_price_index_owner_should_fail_if_caller_is_not_owner() {
    let index_name = 'INDEX_COMPOSITION';
    let price_index_feed = create_price_index(index_name);
    let not_owner = contract_address_const::<0x123456781239>();
    set_contract_address(not_owner);
    price_index_feed.update_price_index_owner(index_name, not_owner);
}

#[test]
#[should_panic(expected: ('Caller is not index owner', 'ENTRYPOINT_FAILED'))]
#[available_gas(200000000000000000)]
fn test_update_price_index_sources_should_fail_if_caller_is_not_owner() {
    let index_name = 'INDEX_COMPOSITION';
    let price_index_feed = create_price_index(index_name);
    let not_owner = contract_address_const::<0x123456781239>();
    set_contract_address(not_owner);
    let new_sources = array![1, 2];
    price_index_feed.update_price_index_sources(index_name, new_sources);
}


#[test]
#[should_panic(expected: ('Caller is not index owner', 'ENTRYPOINT_FAILED'))]
#[available_gas(200000000000000000)]
fn test_update_price_index_composition_should_fail_if_caller_is_not_owner() {
    let index_name = 'INDEX_COMPOSITION';
    let price_index_feed = create_price_index(index_name);
    let not_owner = contract_address_const::<0x123456781239>();
    set_contract_address(not_owner);
    let new_composition = array![
        Composition {
            asset: DataType::SpotEntry('INDEX1/USD'), weight: 20000000, weight_decimals: 8
        }
    ];
    price_index_feed.update_price_index_composition(index_name, new_composition);
}


#[test]
#[should_panic(expected: ('Composition array is empty', 'ENTRYPOINT_FAILED'))]
#[available_gas(200000000000000000)]
fn test_update_price_index_composition_should_fail_if_composition_array_is_empty() {
    let index_name = 'INDEX_COMPOSITION';
    let price_index_feed = create_price_index(index_name);
    let not_owner = contract_address_const::<0x123456781239>();
    let new_composition = array![];
    price_index_feed.update_price_index_composition(index_name, new_composition);
}


#[test]
#[available_gas(200000000000000000)]
fn test_update_price_index_composition() {
    let index_name = 'INDEX_COMPOSITION';
    let price_index_feed = create_price_index(index_name);
    let not_owner = contract_address_const::<0x123456781239>();
    let new_composition = array![
        Composition {
            asset: DataType::SpotEntry('INDEX1/USD'), weight: 20000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX2/USD'), weight: 60000000, weight_decimals: 8
        },
    ];
    price_index_feed.update_price_index_composition(index_name, new_composition.clone());
    let composition_configuration = price_index_feed.get_index_price_composition(index_name);
    assert(composition_configuration == new_composition, 'Wrong composition');
}


#[test]
#[available_gas(200000000000000000)]
fn test_get_median_index_price() {
    let index_name = 'INDEX_COMPOSITION';
    let (price_index_feed, oracle) = setup();
    let owner = contract_address_const::<0x123456789>();
    let assets = array![
        Composition {
            asset: DataType::SpotEntry('INDEX1/USD'), weight: 20000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX2/USD'), weight: 60000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX3/USD'), weight: 20000000, weight_decimals: 8
        },
    ];
    let sources = array![];
    price_index_feed.create_price_index(index_name, assets.clone(), sources.clone());
    let median_index_price = price_index_feed.get_median_index_price(index_name);
    let expected_result = PragmaPricesResponse {
        price: 3700000,
        decimals: 6,
        last_updated_timestamp: NOW,
        num_sources_aggregated: 1,
        expiration_timestamp: Option::None,
    };
    assert(expected_result == median_index_price, 'Wrong median index price info');
}


#[test]
#[available_gas(200000000000000000)]
fn test_get_median_index_price_18_decimals() {
    let index_name = 'INDEX_COMPOSITION';
    let (price_index_feed, oracle) = setup();
    let owner = contract_address_const::<0x123456789>();
    let assets = array![
        Composition {
            asset: DataType::SpotEntry('INDEX1/USD'), weight: 20000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX2/USD'), weight: 40000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX3/USD'), weight: 20000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX3/INDEX2'), weight: 20000000, weight_decimals: 8
        },
    ];
    let sources = array![];
    price_index_feed.create_price_index(index_name, assets.clone(), sources.clone());
    let median_index_price = price_index_feed.get_median_index_price(index_name);
    let expected_result = PragmaPricesResponse {
        price: 4100000000000000000,
        decimals: 18,
        last_updated_timestamp: NOW,
        num_sources_aggregated: 1,
        expiration_timestamp: Option::None,
    };

    assert(expected_result == median_index_price, 'Wrong median index price info');
}


#[test]
#[should_panic(expected: ('Index already created', 'ENTRYPOINT_FAILED'))]
#[available_gas(200000000000000000)]
fn test_create_price_index_should_fail_if_index_already_created() {
    let index_name = 'INDEX_COMPOSITION';
    let (price_index_feed, oracle) = setup();
    let owner = contract_address_const::<0x123456789>();
    let assets = array![
        Composition {
            asset: DataType::SpotEntry('INDEX1/USD'), weight: 20000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX2/USD'), weight: 60000000, weight_decimals: 8
        },
        Composition {
            asset: DataType::SpotEntry('INDEX3/USD'), weight: 20000000, weight_decimals: 8
        },
    ];
    let sources = array![];
    price_index_feed.create_price_index(index_name, assets.clone(), sources.clone());
    price_index_feed.create_price_index(index_name, assets.clone(), sources.clone());
}
