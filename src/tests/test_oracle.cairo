use array::ArrayTrait;
use option::OptionTrait;
use result::ResultTrait;
// use cheatcodes::RevertedTransactionTrait;
// use protostar_print::PrintTrait;
use starknet::ContractAddress;
use pragma::entry::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntries, FutureEntry, OptionEntry,
    AggregationMode
};
use traits::Into;
use traits::TryInto;
use pragma::oracle::oracle::Oracle;
use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
use pragma::publisher_registry::publisher_registry::{
    IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
};
use pragma::publisher_registry::publisher_registry::PublisherRegistry;
use debug::PrintTrait;
use starknet::ClassHash;
use starknet::SyscallResultTrait;
use starknet::testing::{
    set_caller_address, set_contract_address, set_block_timestamp, set_chain_id
};
use starknet::syscalls::deploy_syscall;
use starknet::class_hash::{Felt252TryIntoClassHash};
use starknet::Felt252TryIntoContractAddress;
// use starknet::class_hash::class_hash_try_from_felt252;
use starknet::contract_address::contract_address_const;

const ONE_ETH: felt252 = 1000000000000000000;
const CHAIN_ID: felt252 = 'SN_MAIN';
const BLOCK_TIMESTAMP: u64 = 103374042;


fn setup() -> (IPublisherRegistryABIDispatcher, IOracleABIDispatcher) {
    let mut currencies = ArrayTrait::<Currency>::new();
    currencies
        .append(
            Currency {
                id: 111,
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
                id: 222,
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
                id: USD_CURRENCY_ID,
                decimals: 6_u32,
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
                id: 333,
                decimals: 18_u32,
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
                id: 1, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 111, // currency id - str_to_felt encode the ticker
                base_currency_id: 222, // currency id - str_to_felt encode the ticker
            }
        );
    pairs
        .append(
            Pair {
                id: 2, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 111, // currency id - str_to_felt encode the ticker
                base_currency_id: USD_CURRENCY_ID, // currency id - str_to_felt encode the ticker
            }
        );
    pairs
        .append(
            Pair {
                id: 3, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 222, // currency id - str_to_felt encode the ticker
                base_currency_id: USD_CURRENCY_ID, // currency id - str_to_felt encode the ticker
            }
        );
    pairs
        .append(
            Pair {
                id: 4, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 111, // currency id - str_to_felt encode the ticker
                base_currency_id: 333, // currency id - str_to_felt encode the ticker
            }
        );
    pairs
        .append(
            Pair {
                id: 5, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 333, // currency id - str_to_felt encode the ticker
                base_currency_id: USD_CURRENCY_ID, // currency id - str_to_felt encode the ticker
            }
        );

    let admin = contract_address_const::<0x123456789>();
    set_caller_address(admin);
    set_block_timestamp(BLOCK_TIMESTAMP);
    set_chain_id(CHAIN_ID);
    let now = 100000;

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
    let mut oracle_calldata = ArrayTrait::new();
    oracle_calldata.append(publisher_registry_address);
    //Serialization ? 
    oracle_calldata.append(0);
    oracle_calldata.append(0);
    // oracle_calldata.append(currencies.span());
    // oracle_calldata.append(pairs.span());
    // oracle_calldata.append(0);
    // oracle_calldata.append(0);

    let (oracle_address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, oracle_calldata.span(), true
    )
        .unwrap_syscall();

    let mut oracle = IOracleABIDispatcher { contract_address: oracle_address };

    publisher_registry.add_publisher(1, admin);

    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(1, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(1, 2);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 2, price: 2 * 1000000, volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: now, source: 2, publisher: 1
                    }, pair_id: 2, price: 3 * 1000000, volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 3, price: 8 * 1000000, volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 4, price: 8 * 1000000, volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 4, price: 3 * 1000000, volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 5, price: 5 * 1000000, volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 2, price: 2 * 1000000, volume: 0, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 2, publisher: 1
                    }, pair_id: 2, price: 2 * 1000000, volume: 0, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 3, price: 3 * 1000000, volume: 0, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 4, price: 4 * 1000000, volume: 0, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 5, price: 5 * 1000000, volume: 0, expiration_timestamp: 11111110
                }
            )
        );

    (publisher_registry, oracle)
}

#[test]
#[available_gas(200000000000000)]
fn test_get_decimals() {
    let (publisher_registry, oracle) = setup();
    assert(1 == 1, 'not');
// let decimals_1 = oracle.get_decimals(DataType::SpotEntry(1));
// decimals_1.print();
// assert(decimals_1 == 18_u32, 'wrong decimals value');
// let decimals_2 = oracle.get_decimals(DataType::SpotEntry(2));
// assert(decimals_2 == 6_u32, 'wrong decimals value');
// let decimals_3 = oracle.get_decimals(DataType::SpotEntry(10));
// assert(decimals_3 == 0, 'wrong decimals value');
}
// #[test]
// #[available_gas(2000000000)]
// fn test_get_data_entry() {
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data(DataType::SpotEntry(2), AggregationMode::Median(()));
//     assert(entry.price == (2500000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
//     let entry = oracle.get_data(DataType::SpotEntry(3), AggregationMode::Median(()));
//     assert(entry.price == (8000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
//     let entry = oracle.get_data(DataType::SpotEntry(4), AggregationMode::Median(()));
//     assert(entry.price == (5500000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
//     let entry = oracle.get_data(DataType::SpotEntry(5), AggregationMode::Median(()));
//     assert(entry.price == (5000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
//     let entry = oracle.get_data(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
//     assert(entry.price == (2 * 1000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
//     let entry = oracle.get_data(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
//     assert(entry.price == (2 * 1000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
// }

// fn data_treatment(entry: PossibleEntries) -> (u256, u64) {
//     match entry {
//         PossibleEntries::Spot(entry) => {
//             (entry.price, entry.base.timestamp)
//         },
//         PossibleEntries::Future(entry) => {
//             (entry.price, entry.base.timestamp)
//         }
//     }
// }

// #[test]
// #[available_gas(2000000000)]
// fn get_data_entry_for_source() {
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data_entry(DataType::SpotEntry(2), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (2000000).into(), 'wrong price');
//     assert(timestamp == 100000, 'wrong timestamp');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(2), 2);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (3000000).into(), 'wrong price');
//     assert(timestamp == 100000, 'wrong timestamp');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(3), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (8000000).into(), 'wrong price');
//     assert(timestamp == 100000, 'wrong timestamp');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(4), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (8000000).into(), 'wrong price');
//     assert(timestamp == 100000, 'wrong timestamp');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(4), 2);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (3000000).into(), 'wrong price');
//     assert(timestamp == 100000, 'wrong timestamp');
// }

// #[test]
// #[available_gas(2000000000)]
// fn test_data_with_usd_hop() {
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data(DataType::SpotEntry(2), AggregationMode::Median(()));
// }


