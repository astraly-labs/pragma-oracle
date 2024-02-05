use array::{ArrayTrait, SpanTrait};
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
use traits::TryInto;
use pragma::oracle::oracle::Oracle;
use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
use pragma::publisher_registry::publisher_registry::{
    IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
};
use pragma::publisher_registry::publisher_registry::PublisherRegistry;
use starknet::ClassHash;
use starknet::SyscallResultTrait;
use starknet::testing::{set_contract_address, set_block_timestamp, set_chain_id,};
use starknet::get_caller_address;
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
    currencies
        .append(
            Currency {
                id: 'hop',
                decimals: 10_u32,
                is_abstract_currency: false,
                starknet_address: 0.try_into().unwrap(),
                ethereum_address: 0.try_into().unwrap(),
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
    pairs.append(Pair { id: 6, quote_currency_id: 'hop', base_currency_id: USD_CURRENCY_ID, });
    let admin = contract_address_const::<0x123456789>();
    set_contract_address(admin);
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
    admin.serialize(ref oracle_calldata);
    publisher_registry_address.serialize(ref oracle_calldata);
    currencies.serialize(ref oracle_calldata);
    pairs.serialize(ref oracle_calldata);
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
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 2,
                    price: 2 * 1000000,
                    volume: 100
                }
            )
        );

    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 1 },
                    pair_id: 2,
                    price: 3 * 1000000,
                    volume: 50
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 3,
                    price: 8 * 1000000,
                    volume: 100
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 4,
                    price: 8 * 1000000,
                    volume: 20
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 1 },
                    pair_id: 4,
                    price: 3 * 1000000,
                    volume: 10
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 5,
                    price: 5 * 1000000,
                    volume: 20
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 2,
                    price: 2 * 1000000,
                    volume: 40,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 1 },
                    pair_id: 2,
                    price: 2 * 1000000,
                    volume: 30,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 3,
                    price: 3 * 1000000,
                    volume: 1000,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 4,
                    price: 4 * 1000000,
                    volume: 2321,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 5,
                    price: 5 * 1000000,
                    volume: 231,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 1 },
                    pair_id: 5,
                    price: 5 * 1000000,
                    volume: 232,
                    expiration_timestamp: 11111110
                }
            )
        );

    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 6,
                    price: 2 * 1000000,
                    volume: 440
                }
            )
        );

    (publisher_registry, oracle)
}
#[test]
#[available_gas(200000000000000)]
fn test_get_decimals() {
    let (publisher_registry, oracle) = setup();
    let decimals_1 = oracle.get_decimals(DataType::SpotEntry(1));
    assert(decimals_1 == 18_u32, 'wrong decimals value');
    let decimals_2 = oracle.get_decimals(DataType::SpotEntry(2));
    assert(decimals_2 == 6_u32, 'wrong decimals value');
    let decimals_4 = oracle.get_decimals(DataType::FutureEntry((1, 11111110)));
    assert(decimals_4 == 18_u32, 'wrong decimals value');
    let decimals_5 = oracle.get_decimals(DataType::FutureEntry((2, 11111110)));
    assert(decimals_5 == 6_u32, 'wrong decimals value');
}
#[test]
#[should_panic]
#[available_gas(200000000000)]
fn test_get_decimals_should_fail_if_not_found() {
    //Test should fail if the pair_id is not found 
    let (publisher_registry, oracle) = setup();
    let decimals_1 = oracle.get_decimals(DataType::SpotEntry(100));
}

#[test]
#[should_panic]
#[available_gas(200000000000)]
fn test_get_decimals_should_fail_if_not_found_2() {
    //Test should fail if the pair_id or the expiration timestamp is not related to a FutureEntry
    let (publisher_registry, oracle) = setup();
    let decimals_1 = oracle.get_decimals(DataType::FutureEntry((100, 110100)));
}

#[test]
#[available_gas(200000000000)]
fn test_data_entry() {
    let (publisher_registry, oracle) = setup();
    let entry = oracle.get_data_entry(DataType::SpotEntry(2), 1, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (2000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::SpotEntry(2), 2, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (3000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::SpotEntry(3), 1, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (8000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::SpotEntry(4), 1, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (8000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::SpotEntry(4), 2, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (3000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::SpotEntry(5), 1, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (5000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::FutureEntry((2, 11111110)), 1, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (2000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::FutureEntry((2, 11111110)), 2, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (2000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::FutureEntry((3, 11111110)), 1, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (3000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::FutureEntry((4, 11111110)), 1, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (4000000), 'wrong price');
    let entry = oracle.get_data_entry(DataType::FutureEntry((5, 11111110)), 1, 1);
    let (price, timestamp, volume) = data_treatment(entry);
    assert(price == (5000000), 'wrong price');
}

#[test]
#[should_panic]
#[available_gas(200000000000)]
fn test_data_entry_should_fail_if_not_found() {
    //no panic because we want get_data_entry is called the first time data is published
    let (publisher_registry, oracle) = setup();
    let entry = oracle.get_data_entry(DataType::SpotEntry(100), 1, 1);
}

#[test]
#[should_panic]
#[available_gas(200000000000)]
fn test_data_entry_should_fail_if_not_found_2() {
    //Test should return if the pair_id or the expiration timestamp is not related to a FutureEntry
    let (publisher_registry, oracle) = setup();
    let entry = oracle.get_data_entry(DataType::FutureEntry((100, 110100)), 1, 1);
}

#[test]
#[should_panic]
#[available_gas(200000000000)]
fn test_data_entry_should_fail_if_not_found_3() {
    //Test should fail if the pair_id or the expiration timestamp is not related to a FutureEntry
    let (publisher_registry, oracle) = setup();
    let entry = oracle.get_data_entry(DataType::FutureEntry((2, 110100)), 1, 1);
}

#[test]
#[available_gas(20000000000)]
fn test_get_data() {
    let (publisher_registry, oracle) = setup();
    let entry = oracle.get_data(DataType::SpotEntry(2), AggregationMode::Median(()));
    assert(entry.price == (2500000), 'wrong price');
    let entry = oracle.get_data(DataType::SpotEntry(3), AggregationMode::Median(()));
    assert(entry.price == (8000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data(DataType::SpotEntry(4), AggregationMode::Median(()));
    assert(entry.price == (5500000), 'wrong price');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data(DataType::SpotEntry(5), AggregationMode::Median(()));
    assert(entry.price == (5000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (2 * 1000000), 'wrong price');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (2 * 1000000), 'wrong price');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((3, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (3 * 1000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((4, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (4 * 1000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((5, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (5 * 1000000), 'wrong price');
}
fn data_treatment(entry: PossibleEntries) -> (u128, u64, u128) {
    match entry {
        PossibleEntries::Spot(entry) => {
            (entry.price, entry.base.timestamp, entry.volume)
        },
        PossibleEntries::Future(entry) => {
            assert(entry.expiration_timestamp == 11111110, 'wrong expiration timestamp');
            (entry.price, entry.base.timestamp, entry.volume)
        },
        PossibleEntries::Generic(entry) => {
            (entry.value, entry.base.timestamp, 0)
        }
    }
}
#[test]
#[available_gas(10000000000)]
fn test_get_admin_address() {
    let admin = contract_address_const::<0x123456789>();
    let (publisher_registry, oracle) = setup();
    let admin_address = oracle.get_admin_address();
    assert(admin_address == admin, 'wrong admin address');
}

#[test]
#[available_gas(2000000000)]
fn get_data_median() {
    let (publisher_registry, oracle) = setup();
    let entry = oracle.get_data_median(DataType::SpotEntry(2));
    assert(entry.price == (2500000), 'wrong price');

    let entry = oracle.get_data_median(DataType::SpotEntry(3));
    assert(entry.price == (8000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data_median(DataType::SpotEntry(4));
    assert(entry.price == (5500000), 'wrong price');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data_median(DataType::SpotEntry(5));
    assert(entry.price == (5000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data_median(DataType::FutureEntry((2, 11111110)));
    assert(entry.price == (2 * 1000000), 'wrong price');
    assert(entry.expiration_timestamp.unwrap() == 11111110, 'wrong expiration timestamp');

    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data_median(DataType::FutureEntry((2, 11111110)));
    assert(entry.price == (2 * 1000000), 'wrong price');
    assert(entry.expiration_timestamp.unwrap() == 11111110, 'wrong expiration timestamp');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
}

#[test]
#[available_gas(2000000000)]
fn get_data_median_for_sources() {
    let (publisher_registry, oracle) = setup();
    let mut sources = ArrayTrait::<felt252>::new();
    sources.append(1);
    sources.append(2);
    let entry = oracle.get_data_median_for_sources(DataType::SpotEntry(2), sources.span());
    assert(entry.price == (2500000), 'wrong price');
}
#[test]
#[should_panic]
#[available_gas(2000000000)]
fn get_data_median_for_sources_should_fail_if_wrong_sources() {
    let (publisher_registry, oracle) = setup();
    let mut sources = ArrayTrait::<felt252>::new();
    // sources.append(1);
    sources.append(3);
    let entry = oracle.get_data_median_for_sources(DataType::SpotEntry(2), sources.span());
}
#[test]
#[available_gas(2000000000)]
fn get_data_for_sources() {
    let (publisher_registry, oracle) = setup();
    let mut sources = array![1, 2];
    let entry = oracle
        .get_data_for_sources(DataType::SpotEntry(2), AggregationMode::Median(()), sources.span());
    assert(entry.price == (2500000), 'wrong price');
    let entry = oracle
        .get_data_for_sources(
            DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()), sources.span()
        );
    assert(entry.expiration_timestamp.unwrap() == 11111110, 'wrong expiration timestamp');

    assert(entry.price == (2000000), 'wrong price');
}

#[test]
#[available_gas(100000000000)]
fn test_publish_multiple_entries() {
    let (publish_registry, oracle) = setup();
    let now = 100000;
    let entries = array![
        PossibleEntries::Spot(
            SpotEntry {
                base: BaseEntry { timestamp: now + 100, source: 1, publisher: 1 },
                pair_id: 1,
                price: 2 * 1000000,
                volume: 150
            }
        ),
        PossibleEntries::Spot(
            SpotEntry {
                base: BaseEntry { timestamp: now + 100, source: 1, publisher: 1 },
                pair_id: 4,
                price: 2 * 1000000,
                volume: 150
            }
        ),
        PossibleEntries::Spot(
            SpotEntry {
                base: BaseEntry { timestamp: now + 100, source: 1, publisher: 1 },
                pair_id: 3,
                price: 2 * 1000000,
                volume: 20
            }
        ),
        PossibleEntries::Spot(
            SpotEntry {
                base: BaseEntry { timestamp: now + 100, source: 2, publisher: 1 },
                pair_id: 4,
                price: 3 * 1000000,
                volume: 30
            }
        ),
        PossibleEntries::Spot(
            SpotEntry {
                base: BaseEntry { timestamp: now + 100, source: 2, publisher: 1 },
                pair_id: 2,
                price: 3 * 1000000,
                volume: 30
            }
        ),
        PossibleEntries::Spot(
            SpotEntry {
                base: BaseEntry { timestamp: now + 100, source: 2, publisher: 1 },
                pair_id: 3,
                price: 3 * 1000000,
                volume: 30
            }
        ),
    ];
    let sources = array![1, 2];
    oracle.publish_data_entries(entries.span());
    let (entries, _) = oracle.get_data_entries_for_sources(DataType::SpotEntry(4), sources.span());
    let entry_1 = *entries.at(0);
    let (price, timestamp, volume) = data_treatment(entry_1);
    assert(price == 2 * 1000000, 'wrong price(0)');
    assert(timestamp == now + 100, 'wrong  timestamp(0)');
    assert(volume == 150, 'wrong volume(0)');
    let entry_2 = *entries.at(1);
    let (price_2, timestamp_2, volume_2) = data_treatment(entry_2);
    assert(price_2 == 3 * 1000000, 'wrong price(1)');
    assert(timestamp_2 == now + 100, 'wrong timestamp(1)');
    assert(volume_2 == 30, 'wrong volume(1)');
    let (entries_2, _) = oracle
        .get_data_entries_for_sources(DataType::SpotEntry(3), sources.span());
    let entry_3 = *entries_2.at(0);
    let (price_3, timestamp_3, volume_3) = data_treatment(entry_3);
    assert(price_3 == 2 * 1000000, 'wrong price(3)');
    assert(timestamp_3 == now + 100, 'wrong  timestamp(3)');
    assert(volume_3 == 20, 'wrong volume(3)');
    let entry_4 = *entries_2.at(1);
    let (price_4, timestamp_4, volume_4) = data_treatment(entry_4);
    assert(price_4 == 3 * 1000000, 'wrong price(4)');
    assert(timestamp_4 == now + 100, 'wrong timestamp(4)');
    assert(volume_4 == 30, 'wrong volume(4)');
}

#[test]
#[available_gas(100000000000)]
fn test_max_publish_multiple_entries() {
    let (publish_registry, oracle) = setup();
    let MAX: u32 = 10;
    let now = 100000;
    let mut entries = ArrayTrait::<PossibleEntries>::new();
    let mut cur_idx: u32 = 0;
    loop {
        if (cur_idx == MAX) {
            break ();
        }
        entries
            .append(
                PossibleEntries::Spot(
                    SpotEntry {
                        base: BaseEntry {
                            timestamp: now + (cur_idx + 1).into() * 100, source: 1, publisher: 1
                        },
                        pair_id: 3,
                        price: 3 * 1000000 + (cur_idx + 1).into(),
                        volume: 30
                    }
                )
            );
        entries
            .append(
                PossibleEntries::Spot(
                    SpotEntry {
                        base: BaseEntry {
                            timestamp: now + (cur_idx + 1).into() * 100, source: 2, publisher: 1
                        },
                        pair_id: 2,
                        price: 3 * 1000000 + (cur_idx + 1).into(),
                        volume: 30
                    }
                )
            );
        entries
            .append(
                PossibleEntries::Spot(
                    SpotEntry {
                        base: BaseEntry {
                            timestamp: now + (cur_idx + 1).into() * 100, source: 1, publisher: 1
                        },
                        pair_id: 4,
                        price: 3 * 1000000 + (cur_idx + 1).into(),
                        volume: 30
                    }
                )
            );
        cur_idx = cur_idx + 1;
    };
    //let sources = array![1, 2];
    oracle.publish_data_entries(entries.span());
    return ();
}

#[test]
#[available_gas(2000000000)]
fn test_get_data_median_multi() {
    let (publisher_registry, oracle) = setup();
    let mut sources = ArrayTrait::<felt252>::new();
    sources.append(1);
    sources.append(2);
    let mut data_types = ArrayTrait::<DataType>::new();
    data_types.append(DataType::SpotEntry(2));
    data_types.append(DataType::SpotEntry(4));
    let res = oracle.get_data_median_multi(data_types.span(), sources.span());
    assert(*res.at(0).price == (2500000), 'wrong price');
    assert(*res.at(1).price == (5500000), 'wrong price');
    let mut data_types_2 = ArrayTrait::<DataType>::new();
    data_types_2.append(DataType::FutureEntry((2, 11111110)));
    data_types_2.append(DataType::FutureEntry((5, 11111110)));
    let res_2 = oracle.get_data_median_multi(data_types_2.span(), sources.span());

    assert(*res_2.at(0).price == (2000000), 'wrong price');

    assert(*res_2.at(1).price == (5000000), 'wrong price');
}
#[test]
#[available_gas(2000000000)]
#[should_panic]
fn test_data_median_multi_should_fail_if_wrong_sources() {
    let (publisher_registry, oracle) = setup();
    let mut sources = ArrayTrait::<felt252>::new();
    sources.append(1);
    sources.append(3);
    let mut data_types = ArrayTrait::<DataType>::new();
    data_types.append(DataType::SpotEntry(2));
    data_types.append(DataType::SpotEntry(3));
    let res = oracle.get_data_median_multi(data_types.span(), sources.span());
}

#[test]
#[should_panic]
#[available_gas(2000000000)]
fn test_data_median_multi_should_fail_if_no_expiration_time_associated() {
    let (publisher_registry, oracle) = setup();
    let mut sources = ArrayTrait::<felt252>::new();
    sources.append(1);
    sources.append(3);
    let mut data_types = ArrayTrait::<DataType>::new();
    data_types.append(DataType::FutureEntry((2, 111111111)));
    data_types.append(DataType::FutureEntry((3, 111111111)));
    let res = oracle.get_data_median_multi(data_types.span(), sources.span());
}
#[test]
#[should_panic]
#[available_gas(2000000000)]
fn test_data_median_multi_should_fail_if_wrong_data_types() {
    let (publisher_registry, oracle) = setup();
    let mut sources = ArrayTrait::<felt252>::new();
    sources.append(1);
    sources.append(2);
    let mut data_types = ArrayTrait::<DataType>::new();
    // data_types.append(DataType::SpotEntry(2));
    data_types.append(DataType::SpotEntry(6));
    let res = oracle.get_data_median_multi(data_types.span(), sources.span());
    assert(*res.at(0).price == 2500000, 'wrong price');
    assert(*res.at(1).price == 0, 'wrong price');
}

#[test]
#[available_gas(2000000000)]
fn test_get_data_with_usd_hop() {
    let (publisher_registry, oracle) = setup();
    let entry: PragmaPricesResponse = oracle
        .get_data_with_USD_hop(
            111, 222, AggregationMode::Median(()), SimpleDataType::SpotEntry(()), Option::Some(0)
        );
    assert(entry.price == (312500), 'wrong price-usdshop');
    assert(entry.decimals == 6, 'wrong decimals-usdshop');
    let entry_2 = oracle
        .get_data_with_USD_hop(
            111,
            222,
            AggregationMode::Median(()),
            SimpleDataType::FutureEntry(()),
            Option::Some(11111110)
        );
    assert(entry_2.price == (666666), 'wrong price-usdfhop');
    assert(entry_2.decimals == 6, 'wrong decimals-usdfhop');
}

#[test]
#[available_gas(2000000000)]
fn test_get_data_with_usd_hop_diff() {
    let (publisher_registry, oracle) = setup();
    let entry = oracle
        .get_data_with_USD_hop(
            'hop', 333, AggregationMode::Median(()), SimpleDataType::SpotEntry(()), Option::Some(0)
        );
    assert(entry.price == 400000, 'wrong price for hop');
    assert(entry.decimals == 6, 'wrong decimals for hop');
}

#[test]
#[should_panic]
#[available_gas(2000000000)]
fn test_get_data_with_USD_hop_should_fail_if_wrong_id() {
    let (publisher_registry, oracle) = setup();
    let entry: PragmaPricesResponse = oracle
        .get_data_with_USD_hop(
            444, 222, AggregationMode::Median(()), SimpleDataType::SpotEntry(()), Option::Some(0)
        );
}

#[test]
#[available_gas(2000000000)]
fn test_set_checkpoint() {
    let (publisher_registry, oracle) = setup();
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    let (idx, _) = oracle
        .get_latest_checkpoint_index(DataType::SpotEntry(2), AggregationMode::Median(()));
    let checkpoint: Checkpoint = oracle
        .get_checkpoint(DataType::SpotEntry(2), idx, AggregationMode::Median(()));
    assert(checkpoint.value == (2500000), 'wrong checkpoint');
    assert(checkpoint.num_sources_aggregated == 2, 'wrong num sources');
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    let (idx, _) = oracle
        .get_latest_checkpoint_index(
            DataType::FutureEntry((2, 11111110)), AggregationMode::Median(())
        );
    let checkpoint: Checkpoint = oracle
        .get_checkpoint(DataType::FutureEntry((2, 11111110)), idx, AggregationMode::Median(()));
    assert(checkpoint.value == (2000000), 'wrong checkpoint');
    assert(checkpoint.num_sources_aggregated == 2, 'wrong num sources');
}

#[test]
#[should_panic]
#[available_gas(2000000000)]
fn test_set_checkpoint_should_fail_if_wrong_data_type() {
    let (publisher_registry, oracle) = setup();
    oracle.set_checkpoint(DataType::SpotEntry(8), AggregationMode::Median(()));
}
#[test]
#[available_gas(2000000000)]
fn test_get_last_checkpoint_before() {
    let (publisher_registry, oracle) = setup();
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));

    let (checkpoint, idx) = oracle
        .get_last_checkpoint_before(DataType::SpotEntry(2), 111111111, AggregationMode::Median(()));
    assert(checkpoint.value == (2500000), 'wrong checkpoint');
    assert(idx == 0, 'wrong idx');
    assert(checkpoint.timestamp <= 111111111, 'wrong timestamp');
    let (checkpoint_2, idx_2) = oracle
        .get_last_checkpoint_before(
            DataType::FutureEntry((2, 11111110)), 1111111111, AggregationMode::Median(()),
        );

    assert(checkpoint_2.value == (2000000), 'wrong checkpoint');
    assert(idx_2 == 0, 'wrong idx');
    assert(checkpoint_2.timestamp <= 111111111, 'wrong timestamp');
}

#[test]
#[should_panic]
#[available_gas(2000000000)]
fn test_get_last_checkpoint_before_should_fail_if_wrong_data_type() {
    let (publisher_registry, oracle) = setup();
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));

    let (checkpoint, idx) = oracle
        .get_last_checkpoint_before(DataType::SpotEntry(6), 111111111, AggregationMode::Median(()));
}

#[test]
#[should_panic]
#[available_gas(2000000000)]
fn test_get_last_checkpoint_before_should_fail_if_timestamp_too_old() {
    //if timestamp is before the first checkpoint
    let (publisher_registry, oracle) = setup();
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));

    let (checkpoint, idx) = oracle
        .get_last_checkpoint_before(DataType::SpotEntry(6), 111, AggregationMode::Median(()));
}

#[test]
#[should_panic(expected: ('Currency id cannot be 0', 'ENTRYPOINT_FAILED'))]
#[available_gas(2000000000)]
fn test_add_currency_should_fail_if_currency_id_null() {
    let (publisher_registry, oracle) = setup();
    oracle
        .add_currency(
            Currency {
                id: 0,
                decimals: 18_u32,
                is_abstract_currency: false,
                starknet_address: 0.try_into().unwrap(),
                ethereum_address: 0.try_into().unwrap(),
            }
        );
}

#[test]
#[should_panic(expected: ('No base currency registered', 'ENTRYPOINT_FAILED'))]
#[available_gas(2000000000)]
fn test_add_pair_should_panic_if_base_currency_do_not_corresponds() {
    let (publisher_registry, oracle) = setup();
    oracle
        .add_pair(
            Pair {
                id: 10,
                quote_currency_id: 111,
                base_currency_id: 1931029312, //wrong base currency id 
            }
        )
}

#[test]
#[should_panic(expected: ('No quote currency registered', 'ENTRYPOINT_FAILED'))]
#[available_gas(2000000000)]
fn test_add_pair_should_panic_if_quote_currency_do_not_corresponds() {
    let (publisher_registry, oracle) = setup();
    oracle
        .add_pair(Pair { id: 10, quote_currency_id: 123123132, base_currency_id: USD_CURRENCY_ID, })
}

#[test]
#[available_gas(2000000000)]
fn test_multiple_publishers_price() {
    let admin = contract_address_const::<0x123456789>();
    let test_address = contract_address_const::<0x1234567>();
    set_contract_address(admin);
    let (publisher_registry, oracle) = setup();
    publisher_registry.add_publisher(2, test_address);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(2, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(2, 2);
    let now = 100000;
    set_contract_address(test_address);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 2,
                    price: 4 * 1000000,
                    volume: 100
                }
            )
        );

    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 2 },
                    pair_id: 2,
                    price: 5 * 1000000,
                    volume: 50
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 3,
                    price: 8 * 1000000,
                    volume: 100
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 4,
                    price: 8 * 1000000,
                    volume: 20
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 2 },
                    pair_id: 4,
                    price: 3 * 1000000,
                    volume: 10
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 5,
                    price: 5 * 1000000,
                    volume: 20
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 2,
                    price: 2 * 1000000,
                    volume: 40,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 2 },
                    pair_id: 2,
                    price: 2 * 1000000,
                    volume: 30,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 3,
                    price: 3 * 1000000,
                    volume: 1000,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 4,
                    price: 4 * 1000000,
                    volume: 2321,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 5,
                    price: 5 * 1000000,
                    volume: 231,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 2 },
                    pair_id: 5,
                    price: 5 * 1000000,
                    volume: 232,
                    expiration_timestamp: 11111110
                }
            )
        );
    let entry = oracle.get_data(DataType::SpotEntry(2), AggregationMode::Median(()));
    assert(entry.price == (3500000), 'wrong price');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data(DataType::SpotEntry(3), AggregationMode::Median(()));
    assert(entry.price == (8000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data(DataType::SpotEntry(4), AggregationMode::Median(()));
    assert(entry.price == (5500000), 'wrong price');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data(DataType::SpotEntry(5), AggregationMode::Median(()));
    assert(entry.price == (5000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (2 * 1000000), 'wrong price');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (2 * 1000000), 'wrong price');
    assert(entry.num_sources_aggregated == 2, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((3, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (3 * 1000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((4, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (4 * 1000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let entry = oracle.get_data(DataType::FutureEntry((5, 11111110)), AggregationMode::Median(()));
    assert(entry.price == (5 * 1000000), 'wrong price');
}
#[test]
#[available_gas(2000000000)]
fn test_get_data_entry_for_publishers() {
    let admin = contract_address_const::<0x123456789>();
    let (publisher_registry, oracle) = setup();
    let test_address = contract_address_const::<0x1234567>();
    set_contract_address(admin);
    publisher_registry.add_publisher(2, test_address);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(2, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(2, 2);
    let now = 100000;
    set_contract_address(test_address);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 2,
                    price: 4 * 1000000,
                    volume: 120
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 2,
                    price: 4 * 1000000,
                    volume: 120,
                    expiration_timestamp: 11111110
                }
            )
        );

    let entry = oracle.get_data_entry_for_publishers(DataType::SpotEntry(2), 1);
    match entry {
        PossibleEntries::Spot(entry) => {
            assert(entry.price == (3000000), 'wrong price');
            assert(entry.volume == 110, 'wrong volume');
        },
        PossibleEntries::Future(entry) => {
            assert(false, 'wrong entry type');
        },
        PossibleEntries::Generic(entry) => {
            assert(false, 'wrong entry type');
        }
    }
    let entry = oracle.get_data_entry_for_publishers(DataType::FutureEntry((2, 11111110)), 1);
    match entry {
        PossibleEntries::Spot(entry) => {
            assert(false, 'wrong entry type');
        },
        PossibleEntries::Future(entry) => {
            assert(entry.price == (3000000), 'wrong price');
            assert(entry.volume == 80, 'wrong volume');
        },
        PossibleEntries::Generic(entry) => {
            assert(false, 'wrong entry type');
        }
    }
    let test_address_2 = contract_address_const::<0x1234567314>();
    set_contract_address(admin);
    publisher_registry.add_publisher(3, test_address_2);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(3, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(3, 2);
    set_contract_address(test_address_2);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 3 },
                    pair_id: 2,
                    price: 7 * 1000000,
                    volume: 150
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 3 },
                    pair_id: 2,
                    price: 7 * 1000000,
                    volume: 150,
                    expiration_timestamp: 11111110
                }
            )
        );
    let entry = oracle.get_data_entry_for_publishers(DataType::SpotEntry(2), 1);

    match entry {
        PossibleEntries::Spot(entry) => {
            assert(entry.price == (4000000), 'wrong price');
            assert(entry.volume == 120, 'wrong volume');
        },
        PossibleEntries::Future(entry) => {
            assert(false, 'wrong entry type');
        },
        PossibleEntries::Generic(entry) => {
            assert(false, 'wrong entry type');
        }
    }
    let entry = oracle.get_data_entry_for_publishers(DataType::FutureEntry((2, 11111110)), 1);
    match entry {
        PossibleEntries::Spot(entry) => {
            assert(false, 'wrong entry type');
        },
        PossibleEntries::Future(entry) => {
            assert(entry.price == (4000000), 'wrong price');
            assert(entry.volume == 120, 'wrong volume');
        },
        PossibleEntries::Generic(entry) => {
            assert(false, 'wrong entry type');
        }
    }
}

#[test]
#[available_gas(20000000000000)]
fn test_transfer_ownership() {
    let (publisher_registry, oracle) = setup();
    let admin = contract_address_const::<0x123456789>();
    let test_address = contract_address_const::<0x1234567>();
    set_contract_address(admin);
    let admin_address = oracle.get_admin_address();
    assert(admin_address == admin, 'wrong admin address');
    oracle.set_admin_address(test_address);
    let admin_address = oracle.get_admin_address();
    assert(admin_address == test_address, 'wrong admin address');
}

#[test]
#[available_gas(2000000000)]
fn test_get_all_publishers() {
    let now = 100000;
    let (publisher_registry, oracle) = setup();
    let publishers = oracle.get_all_publishers(DataType::SpotEntry(2));
    assert(publishers.len() == 1, 'wrong number of publishers(S)');
    assert(*publishers.at(0) == 1, 'wrong publisher(S)');
    let test_address = contract_address_const::<0x1234567>();

    publisher_registry.add_publisher(2, test_address);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(2, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(2, 2);
    set_contract_address(test_address);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 2 },
                    pair_id: 2,
                    price: 4 * 1000000,
                    volume: 120
                }
            )
        );
    let publishers = oracle.get_all_publishers(DataType::SpotEntry(2));
    assert(publishers.len() == 2, 'wrong number of publishers(S)');
    assert(*publishers.at(0) == 1, 'wrong publisher(S)');
    assert(*publishers.at(1) == 2, 'wrong publisher(S)');
    let future_publishers = oracle.get_all_publishers(DataType::FutureEntry((2, 11111110)));
    assert(future_publishers.len() == 1, 'wrong number of publishers(F)');
    assert(*future_publishers.at(0) == 1, 'wrong publisher(F)');
}

#[test]
#[available_gas(2000000000)]
fn test_get_all_sources() {
    let (publisher_registry, oracle) = setup();
    let sources = oracle.get_all_sources(DataType::SpotEntry(2));
    assert(sources.len() == 2, 'wrong number of sources(S)');
    assert(*sources.at(0) == 1, 'wrong source(S)');
    assert(*sources.at(1) == 2, 'wrong source(S)');
    let future_sources = oracle.get_all_sources(DataType::FutureEntry((2, 11111110)));
    assert(future_sources.len() == 2, 'wrong number of sources(F)');
    assert(*future_sources.at(0) == 1, 'wrong source(F)');
    assert(*future_sources.at(1) == 2, 'wrong source(F)');
}

#[test]
#[available_gas(2000000000)]
fn test_remove_source() {
    let (publisher_registry, oracle) = setup();
    let admin = contract_address_const::<0x123456789>();
    set_contract_address(admin);
    publisher_registry.add_source_for_publisher(1, 3);
    let now = 100000;
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 3, publisher: 1 },
                    pair_id: 2,
                    price: 7 * 1000000,
                    volume: 150
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now - 10000, source: 3, publisher: 1 },
                    pair_id: 2,
                    price: 7 * 1000000,
                    volume: 150,
                    expiration_timestamp: 11111110
                }
            )
        );
    let sources = array![3];
    let entry = oracle
        .get_data_for_sources(DataType::SpotEntry(2), AggregationMode::Median(()), sources.span());
    assert(entry.price == (7000000), 'wrong price');
    assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
    let boolean: bool = oracle.remove_source(3, DataType::SpotEntry(2));
    assert(boolean == true, 'operation failed');
}

#[test]
#[available_gas(20000000000)]
fn test_publishing_data_for_less_sources_than_initially_planned() {
    let (publisher_registry, oracle) = setup();
    let now = 100000;
    let admin = contract_address_const::<0x123456789>();
    set_contract_address(admin);
    publisher_registry.add_source_for_publisher(1, 3);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now + 9000, source: 3, publisher: 1 },
                    pair_id: 2,
                    price: 7 * 1000000,
                    volume: 150,
                }
            )
        );
    let data_sources = oracle.get_all_sources(DataType::SpotEntry(2));
    assert(data_sources.len() == 3, 'wrong number of sources');
    set_block_timestamp(now + 10000);
    let entries = oracle.get_data_entries(DataType::SpotEntry(2));
    assert(entries.len() == 1, 'wrong number of entries');
    let data = oracle.get_data(DataType::SpotEntry(2), AggregationMode::Median(()));
    assert(data.price == 7000000, 'wrong price');
}


#[test]
#[available_gas(2000000000)]
fn test_update_pair() {
    let (publisher_registry, oracle) = setup();
    let admin = contract_address_const::<0x123456789>();
    set_contract_address(admin);
    let pair = oracle.get_pair(1);
    assert(pair.id == 1, 'wrong pair fetched');
    assert(pair.quote_currency_id == 111, 'wrong recorded pair');
    assert(pair.base_currency_id == 222, 'wrong recorded pair');
    oracle
        .add_currency(
            Currency {
                id: 12345,
                decimals: 18_u32,
                is_abstract_currency: false,
                starknet_address: 0.try_into().unwrap(),
                ethereum_address: 0.try_into().unwrap(),
            }
        );
    oracle
        .update_pair(
            1,
            Pair {
                id: 1, quote_currency_id: 111, base_currency_id: 12345, //wrong base currency id 
            }
        );
    let pair = oracle.get_pair(1);
    assert(pair.id == 1, 'wrong pair fetched');
    assert(pair.quote_currency_id == 111, 'wrong recorded pair');
    assert(pair.base_currency_id == 12345, 'wrong recorded pair');
}
