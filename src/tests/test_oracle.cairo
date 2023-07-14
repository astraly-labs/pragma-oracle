use array::ArrayTrait;
use option::OptionTrait;
use result::ResultTrait;
// use cheatcodes::RevertedTransactionTrait;
// use protostar_print::PrintTrait;
use starknet::ContractAddress;
use pragma::entry::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntries, FutureEntry, OptionEntry,
    AggregationMode, SimpleDataType
};
use starknet::class_hash::class_hash_const;
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
    set_caller_address, set_contract_address, set_block_timestamp, set_chain_id,
};
use starknet::syscalls::deploy_syscall;
use starknet::class_hash::{Felt252TryIntoClassHash};
use starknet::Felt252TryIntoContractAddress;
// use starknet::class_hash::class_hash_try_from_felt252;
use starknet::contract_address::contract_address_const;
use serde::Serde;
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
    let mut oracle_calldata = ArrayTrait::<felt252>::new();
    publisher_registry_address.serialize(ref oracle_calldata);
    currencies.serialize(ref oracle_calldata);
    pairs.serialize(ref oracle_calldata);
    let (oracle_address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, oracle_calldata.span(), true
    )
        .unwrap_syscall();

    let mut oracle = IOracleABIDispatcher { contract_address: oracle_address };
    set_contract_address(admin);
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
                        timestamp: now, source: 2, publisher: 1
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
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 2, publisher: 1
                    }, pair_id: 5, price: 5 * 1000000, volume: 0, expiration_timestamp: 11111110
                }
            )
        );

    (publisher_registry, oracle)
}
// #[test]
// #[available_gas(200000000000000)]
// fn test_get_decimals() {
//     let (publisher_registry, oracle) = setup();
//     let decimals_1 = oracle.get_decimals(DataType::SpotEntry(1));
//     assert(decimals_1 == 18_u32, 'wrong decimals value');
//     let decimals_2 = oracle.get_decimals(DataType::SpotEntry(2));
//     assert(decimals_2 == 6_u32, 'wrong decimals value');
//     let decimals_4 = oracle.get_decimals(DataType::FutureEntry((1, 11111110)));
//     assert(decimals_4 == 18_u32, 'wrong decimals value');
//     let decimals_5 = oracle.get_decimals(DataType::FutureEntry((2, 11111110)));
//     assert(decimals_5 == 6_u32, 'wrong decimals value');
// }
// #[test]
// #[should_panic]
// #[available_gas(200000000000)]
// fn test_get_decimals_should_fail_if_not_found() {
//     //Test should fail if the pair_id is not found 
//     let (publisher_registry, oracle) = setup();
//     let decimals_1 = oracle.get_decimals(DataType::SpotEntry(100));
// }

// #[test]
// #[should_panic]
// #[available_gas(200000000000)]
// fn test_get_decimals_should_fail_if_not_found_2() {
//     //Test should fail if the pair_id or the expiration timestamp is not related to a FutureEntry
//     let (publisher_registry, oracle) = setup();
//     let decimals_1 = oracle.get_decimals(DataType::FutureEntry((100, 110100)));
// }

// #[test]
// #[available_gas(200000000000)]
// fn test_data_entry() {
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data_entry(DataType::SpotEntry(2), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (2000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(2), 2);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (3000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(3), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (8000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(4), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (8000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(4), 2);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (3000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::SpotEntry(5), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (5000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::FutureEntry((2, 11111110)), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (2000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::FutureEntry((2, 11111110)), 2);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (2000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::FutureEntry((3, 11111110)), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (3000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::FutureEntry((4, 11111110)), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (4000000).into(), 'wrong price');
//     let entry = oracle.get_data_entry(DataType::FutureEntry((5, 11111110)), 1);
//     let (price, timestamp) = data_treatment(entry);
//     assert(price == (5000000).into(), 'wrong price');
// }

// #[test]
// #[should_panic]
// #[available_gas(200000000000)]
// fn test_data_entry_should_fail_if_not_found() {
//     //no panic because we want get_data_entry is called the first time data is published
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data_entry(DataType::SpotEntry(100), 1);
// }

// #[test]
// #[should_panic]
// #[available_gas(200000000000)]
// fn test_data_entry_should_fail_if_not_found_2() {
//     //Test should return if the pair_id or the expiration timestamp is not related to a FutureEntry
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data_entry(DataType::FutureEntry((100, 110100)), 1);
// }

// #[test]
// #[should_panic]
// #[available_gas(200000000000)]
// fn test_data_entry_should_fail_if_not_found_3() {
//     //Test should fail if the pair_id or the expiration timestamp is not related to a FutureEntry
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data_entry(DataType::FutureEntry((2, 110100)), 1);
// }

// #[test]
// #[available_gas(2000000000)]
// fn test_get_data() {
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data(DataType::SpotEntry(2), AggregationMode::Median(()));
//     assert(entry.price == (2500000).into(), 'wrong price');
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
//     let entry = oracle.get_data(DataType::FutureEntry((3, 11111110)), AggregationMode::Median(()));
//     assert(entry.price == (3 * 1000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
//     let entry = oracle.get_data(DataType::FutureEntry((4, 11111110)), AggregationMode::Median(()));
//     assert(entry.price == (4 * 1000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
//     let entry = oracle.get_data(DataType::FutureEntry((5, 11111110)), AggregationMode::Median(()));
//     assert(entry.price == (5 * 1000000).into(), 'wrong price');
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
// fn get_data_entry_for_source() {}

// #[test]
// #[available_gas(2000000000)]
// fn get_data_median() {
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data_median(DataType::SpotEntry(2));
//     assert(entry.price == (2500000).into(), 'wrong price');
//     let entry = oracle.get_data_median(DataType::SpotEntry(3));
//     assert(entry.price == (8000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
//     let entry = oracle.get_data_median(DataType::SpotEntry(4));
//     assert(entry.price == (5500000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
//     let entry = oracle.get_data_median(DataType::SpotEntry(5));
//     assert(entry.price == (5000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
//     let entry = oracle.get_data_median(DataType::FutureEntry((2, 11111110)));
//     assert(entry.price == (2 * 1000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
//     let entry = oracle.get_data_median(DataType::FutureEntry((2, 11111110)));
//     assert(entry.price == (2 * 1000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
// }

// #[test]
// #[available_gas(2000000000)]
// fn get_data_median_for_sources() {
//     let (publisher_registry, oracle) = setup();
//     let mut sources = ArrayTrait::<felt252>::new();
//     sources.append(1);
//     sources.append(2);
//     let entry = oracle.get_data_median_for_sources(DataType::SpotEntry(2), sources.span());
//     assert(entry.price == (2500000).into(), 'wrong price');
// }
// #[test]
// #[should_panic]
// #[available_gas(2000000000)]
// fn get_data_median_for_sources_should_fail_if_wrong_sources() {
//     let (publisher_registry, oracle) = setup();
//     let mut sources = ArrayTrait::<felt252>::new();
//     // sources.append(1);
//     sources.append(3);
//     let entry = oracle.get_data_median_for_sources(DataType::SpotEntry(2), sources.span());
// }
// #[test]
// #[available_gas(2000000000)]
// fn get_data_for_sources() {
//     let (publisher_registry, oracle) = setup();
//     let mut sources = ArrayTrait::<felt252>::new();
//     sources.append(1);
//     sources.append(2);
//     let entry = oracle
//         .get_data_for_sources(DataType::SpotEntry(2), AggregationMode::Median(()), sources.span());
//     assert(entry.price == (2500000).into(), 'wrong price');
//     let entry = oracle
//         .get_data_for_sources(
//             DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()), sources.span()
//         );
//     assert(entry.price == (2000000).into(), 'wrong price');
// }
// #[test]
// #[available_gas(2000000000)]
// fn test_get_data_median_multi() {
//     let (publisher_registry, oracle) = setup();
//     let mut sources = ArrayTrait::<felt252>::new();
//     sources.append(1);
//     sources.append(2);
//     let mut data_types = ArrayTrait::<DataType>::new();
//     data_types.append(DataType::SpotEntry(2));
//     data_types.append(DataType::SpotEntry(4));
//     let res = oracle.get_data_median_multi(data_types.span(), sources.span());
//     assert(*res.at(0).price == (2500000).into(), 'wrong price');
//     assert(*res.at(1).price == (5500000).into(), 'wrong price');
//     let mut data_types_2 = ArrayTrait::<DataType>::new();
//     data_types_2.append(DataType::FutureEntry((2, 11111110)));
//     data_types_2.append(DataType::FutureEntry((5, 11111110)));
//     let res_2 = oracle.get_data_median_multi(data_types_2.span(), sources.span());

//     assert(*res_2.at(0).price == (2000000).into(), 'wrong price');

//     assert(*res_2.at(1).price == (5000000).into(), 'wrong price');
// }
// #[test]
// #[available_gas(2000000000)]
// #[should_panic]
// fn test_data_median_multi_should_fail_if_wrong_sources() {
//     let (publisher_registry, oracle) = setup();
//     let mut sources = ArrayTrait::<felt252>::new();
//     sources.append(1);
//     sources.append(3);
//     let mut data_types = ArrayTrait::<DataType>::new();
//     data_types.append(DataType::SpotEntry(2));
//     data_types.append(DataType::SpotEntry(3));
//     let res = oracle.get_data_median_multi(data_types.span(), sources.span());
// }

// #[test]
// #[should_panic]
// #[available_gas(2000000000)]
// fn test_data_median_multi_should_fail_if_no_expiration_time_associated() {
//     let (publisher_registry, oracle) = setup();
//     let mut sources = ArrayTrait::<felt252>::new();
//     sources.append(1);
//     sources.append(3);
//     let mut data_types = ArrayTrait::<DataType>::new();
//     data_types.append(DataType::FutureEntry((2, 111111111)));
//     data_types.append(DataType::FutureEntry((3, 111111111)));
//     let res = oracle.get_data_median_multi(data_types.span(), sources.span());
// }
// #[test]
// #[should_panic]
// #[available_gas(2000000000)]
// fn test_data_median_multi_should_fail_if_wrong_data_types() {
//     let (publisher_registry, oracle) = setup();
//     let mut sources = ArrayTrait::<felt252>::new();
//     sources.append(1);
//     sources.append(2);
//     let mut data_types = ArrayTrait::<DataType>::new();
//     // data_types.append(DataType::SpotEntry(2));
//     data_types.append(DataType::SpotEntry(6));
//     let res = oracle.get_data_median_multi(data_types.span(), sources.span());
//     assert(*res.at(0).price == 2500000, 'wrong price');
//     assert(*res.at(1).price == 0, 'wrong price');
// }

// #[test]
// #[available_gas(2000000000)]
// fn test_get_data_with_usd_hop() {
//     let (publisher_registry, oracle) = setup();
//     let entry: PragmaPricesResponse = oracle
//         .get_data_with_USD_hop(
//             111, 222, AggregationMode::Median(()), SimpleDataType::SpotEntry(()), Option::Some(0)
//         );
//     assert(entry.price == (312500).into(), 'wrong price-usdshop');
//     assert(entry.decimals == 6, 'wrong decimals-usdshop');
//     let entry_2 = oracle
//         .get_data_with_USD_hop(
//             111,
//             222,
//             AggregationMode::Median(()),
//             SimpleDataType::FutureEntry(()),
//             Option::Some(11111110)
//         );
//     assert(entry_2.price == (666666).into(), 'wrong price-usdfhop');
//     assert(entry_2.decimals == 6, 'wrong decimals-usdfhop');
// }

// #[test]
// #[should_panic]
// #[available_gas(2000000000)]
// fn test_get_data_with_USD_hop_should_fail_if_wrong_id() {
//     let (publisher_registry, oracle) = setup();
//     let entry: PragmaPricesResponse = oracle
//         .get_data_with_USD_hop(
//             444, 222, AggregationMode::Median(()), SimpleDataType::SpotEntry(()), Option::Some(0)
//         );
// }

// #[test]
// #[available_gas(2000000000)]
// fn test_set_checkpoint() {
//     let (publisher_registry, oracle) = setup();
//     oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
//     let (idx, _) = oracle
//         .get_latest_checkpoint_index(DataType::SpotEntry(2), AggregationMode::Median(()));
//     let checkpoint: Checkpoint = oracle.get_checkpoint(DataType::SpotEntry(2), idx);
//     assert(checkpoint.value == (2500000).into(), 'wrong checkpoint');
//     assert(checkpoint.num_sources_aggregated == 2, 'wrong num sources');
//     oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
//     let (idx, _) = oracle
//         .get_latest_checkpoint_index(
//             DataType::FutureEntry((2, 11111110)), AggregationMode::Median(())
//         );
//     let checkpoint: Checkpoint = oracle.get_checkpoint(DataType::FutureEntry((2, 11111110)), idx);
//     assert(checkpoint.value == (2000000).into(), 'wrong checkpoint');
//     assert(checkpoint.num_sources_aggregated == 2, 'wrong num sources');
// }

// #[test]
// #[should_panic]
// #[available_gas(2000000000)]
// fn test_set_checkpoint_should_fail_if_wrong_data_type() {
//     let (publisher_registry, oracle) = setup();
//     oracle.set_checkpoint(DataType::SpotEntry(6), AggregationMode::Median(()));
// }

// #[test]
// #[available_gas(2000000000)]
// fn test_get_last_checkpoint_before() {
//     let (publisher_registry, oracle) = setup();
//     oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
//     oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));

//     let (checkpoint, idx) = oracle
//         .get_last_checkpoint_before(DataType::SpotEntry(2), AggregationMode::Median(()), 111111111);
//     assert(checkpoint.value == (2500000).into(), 'wrong checkpoint');
//     assert(idx == 0, 'wrong idx');
//     assert(checkpoint.timestamp <= 111111111, 'wrong timestamp');
//     let (checkpoint_2, idx_2) = oracle
//         .get_last_checkpoint_before(
//             DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()), 1111111111
//         );

//     assert(checkpoint_2.value == (2000000).into(), 'wrong checkpoint');
//     assert(idx_2 == 0, 'wrong idx');
//     assert(checkpoint_2.timestamp <= 111111111, 'wrong timestamp');
// }

// #[test]
// #[should_panic]
// #[available_gas(2000000000)]
// fn test_get_last_checkpoint_before_should_fail_if_wrong_data_type() {
//     let (publisher_registry, oracle) = setup();
//     oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
//     oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));

//     let (checkpoint, idx) = oracle
//         .get_last_checkpoint_before(DataType::SpotEntry(6), AggregationMode::Median(()), 111111111);
// }

// #[test]
// #[should_panic]
// #[available_gas(2000000000)]
// fn test_get_last_checkpoint_before_should_fail_if_timestamp_too_old() {
//     //if timestamp is before the first checkpoint
//     let (publisher_registry, oracle) = setup();
//     oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
//     oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));

//     let (checkpoint, idx) = oracle
//         .get_last_checkpoint_before(DataType::SpotEntry(6), AggregationMode::Median(()), 111);
// }

