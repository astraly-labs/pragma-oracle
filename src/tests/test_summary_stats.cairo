use array::ArrayTrait;
use option::OptionTrait;
use result::ResultTrait;
use starknet::ContractAddress;
use pragma::entry::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntries, FutureEntry, OptionEntry,
    AggregationMode, SimpleDataType
};
use cubit::f128::types::fixed::{FixedTrait, ONE_u128, Fixed};
use starknet::class_hash::class_hash_const;
use traits::Into;
use serde::Serde;
use alexandria_math::pow;
use traits::TryInto;
use pragma::oracle::oracle::Oracle;
use pragma::compute_engines::summary_stats::summary_stats::SummaryStats;
use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
use pragma::publisher_registry::publisher_registry::{
    IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
};
use pragma::compute_engines::summary_stats::summary_stats::{
    ISummaryStatsABIDispatcher, ISummaryStatsABIDispatcherTrait
};
use starknet::contract_address::contract_address_const;
use pragma::publisher_registry::publisher_registry::PublisherRegistry;
use starknet::ClassHash;
use starknet::SyscallResultTrait;
use starknet::testing::{
    set_caller_address, set_contract_address, set_block_timestamp, set_chain_id,
};
use starknet::syscalls::deploy_syscall;
use starknet::class_hash::{Felt252TryIntoClassHash};
use starknet::Felt252TryIntoContractAddress;
const ONE_ETH: felt252 = 1000000000000000000;
const CHAIN_ID: felt252 = 'SN_MAIN';
const BLOCK_TIMESTAMP: u64 = 103374042;
const NOW: u64 = 100000;

fn setup() -> (ISummaryStatsABIDispatcher, IOracleABIDispatcher) {
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
                id: 'BTC',
                decimals: 8_u32,
                is_abstract_currency: false,
                starknet_address: 0.try_into().unwrap(),
                ethereum_address: 0.try_into().unwrap()
            }
        );
    currencies
        .append(
            Currency {
                id: 'ETH',
                decimals: 8_u32,
                is_abstract_currency: false,
                starknet_address: 0.try_into().unwrap(),
                ethereum_address: 0.try_into().unwrap()
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
                id: 'BTC/ETH', // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 'BTC', // currency id - str_to_felt encode the ticker
                base_currency_id: 'ETH', // currency id - str_to_felt encode the ticker
            }
        );

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
    let mut summary_calldata = ArrayTrait::<felt252>::new();
    oracle_address.serialize(ref summary_calldata);
    let (summary_stats_address, _) = deploy_syscall(
        SummaryStats::TEST_CLASS_HASH.try_into().unwrap(), 0, summary_calldata.span(), true
    )
        .unwrap_syscall();
    let mut summary_stats = ISummaryStatsABIDispatcher { contract_address: summary_stats_address };
    set_contract_address(admin);
    publisher_registry.add_publisher(1, admin);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(1, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(1, 2);
    publisher_registry.add_source_for_publisher(1, 3);

    starknet::testing::set_block_timestamp(now);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 2,
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
                    pair_id: 2,
                    price: 3 * 1000000,
                    volume: 0
                }
            )
        );

    //checkpoint = 250000 (Median)
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Mean(()));

    starknet::testing::set_block_timestamp(now + 101);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now + 100, source: 2, publisher: 1 },
                    pair_id: 2,
                    price: 35 * 100000,
                    volume: 0
                }
            )
        );

    //checkpoint = 275000 (Median)
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Mean(()));

    starknet::testing::set_block_timestamp(now + 200);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now + 200, source: 2, publisher: 1 },
                    pair_id: 2,
                    price: 4 * 1000000,
                    volume: 0
                }
            )
        );

    //checkpoint = 300000 (Median)
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Mean(()));
    starknet::testing::set_block_timestamp(now + 300);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now + 300, source: 2, publisher: 1 },
                    pair_id: 2,
                    price: 4 * 1000000,
                    volume: 0
                }
            )
        );
    //checkpoint = 300000 (Median)
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Mean(()));
    starknet::testing::set_block_timestamp(now + 400);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now + 400, source: 2, publisher: 1 },
                    pair_id: 2,
                    price: 3 * 1000000,
                    volume: 0
                }
            )
        );
    //checkpoint = 250000 (Median)
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Mean(()));

    (summary_stats, oracle)
}


#[test]
#[available_gas(200000000000)]
fn test_summary_stats_mean_median() {
    let (summary_stats, oracle) = setup();
    starknet::testing::set_block_timestamp(NOW + 100);
    let (mean, _) = summary_stats
        .calculate_mean(
            DataType::SpotEntry(2), 100000, (100002 + 400), AggregationMode::Median(())
        );

    assert(mean == 2750000, 'wrong mean(1)');
    let (mean_1, _) = summary_stats
        .calculate_mean(DataType::SpotEntry(2), 100000, (100002), AggregationMode::Median(()));
    assert(mean_1 == 2500000, 'wrong mean(2)');
    let (mean_2, _) = summary_stats
        .calculate_mean(
            DataType::SpotEntry(2), 100000, (100002 + 100), AggregationMode::Median(())
        );

    assert(mean_2 == 2625000, 'wrong mean(3)');
    let (mean_3, _) = summary_stats
        .calculate_mean(
            DataType::SpotEntry(2), 100002, (100002 + 200), AggregationMode::Median(())
        );
    assert(mean_3 == 2750000, 'wrong mean(4)');
    let (mean_4, _) = summary_stats
        .calculate_mean(
            DataType::SpotEntry(2), 100002, (100002 + 300), AggregationMode::Median(())
        );
    assert(mean_4 == 2812500, 'wrong mean(5)');
    let (mean_5, _) = summary_stats
        .calculate_mean(
            DataType::SpotEntry(2), 100202, (100002 + 400), AggregationMode::Median(())
        );
    assert(mean_5 == 2833333, 'wrong mean(6)');
}


#[test]
#[available_gas(200000000000)]
fn test_summary_stats_mean_mean() {
    let (summary_stats, oracle) = setup();
    starknet::testing::set_block_timestamp(NOW + 100);
    let (mean, _) = summary_stats
        .calculate_mean(DataType::SpotEntry(2), 100000, (100002 + 400), AggregationMode::Mean(()));
    assert(mean == 2750000, 'wrong mean(1)');
    let (mean_1, _) = summary_stats
        .calculate_mean(DataType::SpotEntry(2), 100000, (100002), AggregationMode::Mean(()));
    assert(mean_1 == 2500000, 'wrong mean(2)');
    let (mean_2, _) = summary_stats
        .calculate_mean(DataType::SpotEntry(2), 100000, (100002 + 100), AggregationMode::Mean(()));
    assert(mean_2 == 2625000, 'wrong mean(3)');
    let (mean_3, _) = summary_stats
        .calculate_mean(DataType::SpotEntry(2), 100002, (100002 + 200), AggregationMode::Mean(()));
    assert(mean_3 == 2750000, 'wrong mean(4)');
    let (mean_4, _) = summary_stats
        .calculate_mean(DataType::SpotEntry(2), 100002, (100002 + 300), AggregationMode::Mean(()));
    assert(mean_4 == 2812500, 'wrong mean(5)');
    let (mean_5, _) = summary_stats
        .calculate_mean(DataType::SpotEntry(2), 100202, (100002 + 400), AggregationMode::Mean(()));
    assert(mean_5 == 2833333, 'wrong mean(6)');
}


fn setup_twap() -> (ISummaryStatsABIDispatcher, IOracleABIDispatcher) {
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
    pairs.append(Pair { id: 3, quote_currency_id: 222, base_currency_id: USD_CURRENCY_ID });
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
    let mut summary_calldata = ArrayTrait::<felt252>::new();
    oracle_address.serialize(ref summary_calldata);
    let (summary_stats_address, _) = deploy_syscall(
        SummaryStats::TEST_CLASS_HASH.try_into().unwrap(), 0, summary_calldata.span(), true
    )
        .unwrap_syscall();
    let mut summary_stats = ISummaryStatsABIDispatcher { contract_address: summary_stats_address };
    set_contract_address(admin);
    publisher_registry.add_publisher(1, admin);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(1, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(1, 2);
    //Add source 3 for publisher 1
    publisher_registry.add_source_for_publisher(1, 3);
    starknet::testing::set_block_timestamp(now);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 2,
                    price: 2 * 1000000,
                    volume: 0
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
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    starknet::testing::set_block_timestamp(now + 200);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 200, source: 1, publisher: 1 },
                    pair_id: 2,
                    price: 8 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );

    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));

    starknet::testing::set_block_timestamp(now + 400);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 400, source: 1, publisher: 1 },
                    pair_id: 2,
                    price: 3 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    starknet::testing::set_block_timestamp(now + 600);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 600, source: 1, publisher: 1 },
                    pair_id: 2,
                    price: 5 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    starknet::testing::set_block_timestamp(now);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 3,
                    price: 2 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 2, publisher: 1 },
                    pair_id: 3,
                    price: 4 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now, source: 3, publisher: 1 },
                    pair_id: 3,
                    price: 6 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .set_checkpoint(
            DataType::FutureEntry((3, 11111110)), AggregationMode::Median(())
        ); // 4 *10**6

    starknet::testing::set_block_timestamp(now + 200);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 200, source: 1, publisher: 1 },
                    pair_id: 3,
                    price: 8 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 200, source: 2, publisher: 1 },
                    pair_id: 3,
                    price: 8 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .set_checkpoint(
            DataType::FutureEntry((3, 11111110)), AggregationMode::Median(())
        ); // 8 *10**6
    starknet::testing::set_block_timestamp(now + 400);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 400, source: 1, publisher: 1 },
                    pair_id: 3,
                    price: 2 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 400, source: 2, publisher: 1 },
                    pair_id: 3,
                    price: 3 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 400, source: 3, publisher: 1 },
                    pair_id: 3,
                    price: 4 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .set_checkpoint(
            DataType::FutureEntry((3, 11111110)), AggregationMode::Median(())
        ); // 3 *10**6
    starknet::testing::set_block_timestamp(now + 600);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry { timestamp: now + 600, source: 1, publisher: 1 },
                    pair_id: 3,
                    price: 5 * 1000000,
                    volume: 100,
                    expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .set_checkpoint(
            DataType::FutureEntry((3, 11111110)), AggregationMode::Median(())
        ); // 5 *10**6
    //checkpoint = 250000 (Median)

    (summary_stats, oracle)
}


#[test]
#[available_gas(10000000000000)]
fn test_set_future_checkpoint() {
    let admin = contract_address_const::<0x123456789>();
    set_contract_address(admin);
    let (summary_stats, oracle) = setup_twap();

    let (twap_test, decimals) = summary_stats
        .calculate_twap(
            DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()), 10000, 100001
        );
    assert(twap_test == 4333333, 'wrong twap(1)');
    assert(decimals == 6, 'wrong decimals(1)');
    let (twap_test_2, decimals) = summary_stats
        .calculate_twap(
            DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()), 10000, 100201
        );

    assert(twap_test_2 == 5500000, 'wrong twap(2)');
    assert(decimals == 6, 'wrong decimals(2)');
    let (twap_test_3, decimals) = summary_stats
        .calculate_twap(
            DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()), 10000, 100401
        );
    assert(twap_test_3 == 3000000, 'wrong twap(3)');
    assert(decimals == 6, 'wrong decimals(3)');
    let (twap_test_4, decimals) = summary_stats
        .calculate_twap(
            DataType::FutureEntry((3, 11111110)), AggregationMode::Median(()), 10000, 100001
        );
    assert(twap_test_4 == 5000000, 'wrong twap(4)');
    assert(decimals == 6, 'wrong decimals(4)');
    let (twap_test_5, decimals) = summary_stats
        .calculate_twap(
            DataType::FutureEntry((3, 11111110)), AggregationMode::Median(()), 10000, 100201
        );
    assert(twap_test_5 == 5500000, 'wrong twap(5)');
    assert(decimals == 6, 'wrong decimals(5)');
    let (twap_test_6, decimals) = summary_stats
        .calculate_twap(
            DataType::FutureEntry((3, 11111110)), AggregationMode::Median(()), 10000, 100401
        );
    assert(twap_test_6 == 3000000, 'wrong twap(6)');
    return ();
}

#[derive(Drop, Copy, Serde)]
enum Config {
    EMA: (),
    MACD: (),
    ERROR_NOT_ENOUGH_DATA: ()
}

fn ema_macd_initial_configuration(
    config: Config
) -> (ISummaryStatsABIDispatcher, IOracleABIDispatcher, u64) {
    let admin = contract_address_const::<0x123456789>();
    set_contract_address(admin);
    let (summary_stats, oracle) = setup();
    let now = 1710701526;
    let max_iteration = match config {
        Config::EMA(()) => {
            10
        },
        Config::MACD(()) => {
            30
        },
        Config::ERROR_NOT_ENOUGH_DATA(()) => {
            3
        }
    };
    let initial_timestamp = now - max_iteration * 1000;
    set_block_timestamp(initial_timestamp);
    let mut cur_idx = 0;
    loop {
        if (cur_idx == max_iteration + 1) {
            break ();
        }
        oracle
            .publish_data(
                PossibleEntries::Spot(
                    SpotEntry {
                        base: BaseEntry {
                            timestamp: starknet::info::get_block_timestamp(),
                            source: 1,
                            publisher: 1
                        },
                        pair_id: 'BTC/ETH',
                        price: (4000 + cur_idx.into() * 100) * pow(10, 8),
                        volume: 100,
                    }
                )
            );
        set_block_timestamp(initial_timestamp + 1000 * cur_idx);
        oracle.set_checkpoint(DataType::SpotEntry('BTC/ETH'), AggregationMode::Median(()));
        cur_idx += 1;
    };

    return (summary_stats, oracle, now);
}
#[test]
#[available_gas(200000000000)]
fn test_compute_ema() {
    let (summary_stats, oracle, now) = ema_macd_initial_configuration(Config::EMA(()));
    // TEST 1: WITH NUMBER_OF_PERIOD = 4
    // Exponential Moving Average (EMA): [400000000000, 428000000000.0, 448800000000.0, 465280000000.0, 479168000000.0]
    let (result, _) = summary_stats
        .calculate_ema(
            DataType::SpotEntry('BTC/ETH'),
            AggregationMode::Median(()),
            1000,
            4,
            now + 10,
            Option::None
        );
    assert(*result.at(0) == (4000 * pow(10, 8)).into(), 'EMA: wrong initial value');
    assert(*result.at(1) == (4280 * pow(10, 8)).into(), 'EMA: wrong first value');
    assert(*result.at(2) == (4488 * pow(10, 8)).into(), 'EMA: wrong second value');
    assert(*result.at(3) == (46528 * pow(10, 7)).into(), 'EMA: wrong third value');
    assert(*result.at(4) == (479168 * pow(10, 6)).into(), 'EMA: wrong fourth value');

    // TEST 2: WITH NUMBER_OF_PERIOD = 10
    // Notice: incertitude propagation due to the nature of the data on the last 3 decimals 

    // Result array from the python script src/tests/computational_feeds.py: 
    // Exponential Moving Average (EMA): [400000000000, 401818181818.18176, 405123966942.1487, 409646882043.5762, 415165630762.92596, 421499152442.3939, 428499306543.77686, 436044887172.181, 444036725868.14813, 452393684801.21204, 461049378473.7189]    
    let (result, _) = summary_stats
        .calculate_ema(
            DataType::SpotEntry('BTC/ETH'),
            AggregationMode::Median(()),
            1000,
            10,
            now + 10,
            Option::None
        );
    assert(*result.at(0) == (4000 * pow(10, 8)), 'EMA: wrong initial value');
    assert(*result.at(1) == 401818181800, 'EMA: wrong first value');
    assert(*result.at(2) == 405123966894, 'EMA: wrong second value');
    assert(*result.at(3) == 409646881958, 'EMA: wrong third value');
    assert(*result.at(4) == 415165630637, 'EMA: wrong fourth value');
    assert(*result.at(5) == 421499152276, 'EMA: wrong fifth value');
    assert(*result.at(6) == 428499306337, 'EMA: wrong sixth value');
    assert(*result.at(7) == 436044886927, 'EMA: wrong seventh value');
    assert(*result.at(8) == 444036725587, 'EMA: wrong eight value');
    assert(*result.at(9) == 452393684487, 'EMA: wrong ninth value');
    assert(*result.at(10) == 461049378130, 'EMA: wrong tenth value');

    // TEST 3: WITH A DIFFERENT PERIOD
    let (result, _) = summary_stats
        .calculate_ema(
            DataType::SpotEntry('BTC/ETH'),
            AggregationMode::Median(()),
            2000,
            4,
            now + 10,
            Option::None
        );
    assert(*result.at(0) == (4000 * pow(10, 8)).into(), 'EMA: wrong initial value');
    assert(*result.at(1) == (4160 * pow(10, 8)).into(), 'EMA: wrong first value');
    assert(*result.at(2) == (4336 * pow(10, 8)).into(), 'EMA: wrong second value');
    assert(*result.at(3) == (45216 * pow(10, 7)).into(), 'EMA: wrong third value');
    assert(*result.at(4) == (471296 * pow(10, 6)).into(), 'EMA: wrong third value');
}


#[test]
#[available_gas(200000000000)]
fn test_compute_macd() {
    let (summary_stats, oracle, now) = ema_macd_initial_configuration(Config::MACD(()));
    // Result
    // MACD: [-83939188515.86871, -62564775691.33148, -44307731162.8042, -28701126689.880432, -15348930858.502808, -3915171379.691345, 5885240421.425293, 14294278266.50055, 21517378820.146362, 27729011689.01245, 33077396282.1239, 37688496504.28113]
    let (result, _) = summary_stats
        .calculate_macd(
            DataType::SpotEntry('BTC/ETH'), AggregationMode::Median(()), 1000, Option::None
        );
    assert(*result.at(0) == FixedTrait::new(83939185397, true), 'MACD: failed(0)');
    assert(*result.at(1) == FixedTrait::new(62564773102, true), 'MACD: failed(1)');
    assert(*result.at(2) == FixedTrait::new(44307728923, true), 'MACD: failed(2)');
    assert(*result.at(3) == FixedTrait::new(28701124659, true), 'MACD: failed(3)');
    assert(*result.at(4) == FixedTrait::new(15348928930, true), 'MACD: failed(4)');
    assert(*result.at(5) == FixedTrait::new(3915169471, true), 'MACD: failed(5)');
    assert(*result.at(6) == FixedTrait::new(5885242372, false), 'MACD: failed(6)');
    assert(*result.at(7) == FixedTrait::new(14294280304, false), 'MACD: failed(7))');
    assert(*result.at(8) == FixedTrait::new(21517380977, false), 'MACD: failed(8)');
    assert(*result.at(9) == FixedTrait::new(27729013987, false), 'MACD: failed(9)');
    assert(*result.at(10) == FixedTrait::new(33077398736, false), 'MACD: failed(10)');
    assert(*result.at(11) == FixedTrait::new(37688499122, false), 'MACD: failed(11)');
}


#[test]
#[available_gas(20000000000000)]
fn test_comppute_signal_line() {
    let (summary_stats, oracle, now) = ema_macd_initial_configuration(Config::MACD(()));
    // Signal line [-83939188515.86871, -79664305950.96127, -72592990993.32986, -63814618132.639984, -54121480677.81255, -44080218818.18832, -34087126970.265594, -24410845922.91237, -15225200974.300621, -6634358441.638008]    let (summary_stats, oracle, now) = ema_macd_initial_configuration(Config::MACD(()));
    let (result, _) = summary_stats
        .calculate_signal_line(
            DataType::SpotEntry('BTC/ETH'), AggregationMode::Median(()), 1000, Option::None
        );
    let mut cur_idx = 0;
    assert(*result.at(0) == FixedTrait::new(83939185397, true), 'Signal_line: failed(0)');
    assert(*result.at(1) == FixedTrait::new(79664302938, true), 'Signal_line: failed(1)');
    assert(*result.at(2) == FixedTrait::new(72592988135, true), 'Signal_line: failed(2)');
    assert(*result.at(3) == FixedTrait::new(63814615440, true), 'Signal_line: failed(3)');
    assert(*result.at(4) == FixedTrait::new(54121478138, true), 'Signal_line: failed(4)');
    assert(*result.at(5) == FixedTrait::new(44080216405, true), 'Signal_line: failed(5)');
    assert(*result.at(6) == FixedTrait::new(34087124650, true), 'Signal_line: failed(6)');
    assert(*result.at(7) == FixedTrait::new(24410843660, true), 'Signal_line: failed(7)');
    assert(*result.at(8) == FixedTrait::new(15225198733, true), 'Signal_line: failed(8)');
}

#[test]
#[should_panic(expected: ('EMA: not enough data', 'ENTRYPOINT_FAILED'))]
#[available_gas(20000000000000)]
fn compute_ema_should_fail_if_not_enough_data() {
    let (summary_stats, oracle, now) = ema_macd_initial_configuration(
        Config::ERROR_NOT_ENOUGH_DATA(())
    );
    let (result, _) = summary_stats
        .calculate_ema(
            DataType::SpotEntry('BTC/ETH'),
            AggregationMode::Median(()),
            1000,
            4,
            now + 10,
            Option::None
        );
    assert(*result.at(0) == (4000 * pow(10, 8)).into(), 'EMA: wrong initial value');
}


#[test]
#[should_panic(expected: ('EMA: not enough data', 'ENTRYPOINT_FAILED'))]
#[available_gas(20000000000000)]
fn compute_macd_should_fail_if_not_enough_data() {
    let (summary_stats, oracle, now) = ema_macd_initial_configuration(
        Config::ERROR_NOT_ENOUGH_DATA(())
    );
    let (result, _) = summary_stats
        .calculate_ema(
            DataType::SpotEntry('BTC/ETH'),
            AggregationMode::Median(()),
            1000,
            4,
            now + 10,
            Option::None
        );
    assert(*result.at(0) == (4000 * pow(10, 8)).into(), 'EMA: wrong initial value');
}


#[test]
#[should_panic(expected: ('EMA:No cp avlble for gvn period', 'ENTRYPOINT_FAILED'))]
#[available_gas(20000000000000)]
fn compute_ema_should_fail_if_no_checkpoint_available() {
    let (summary_stats, oracle, now) = ema_macd_initial_configuration(
        Config::ERROR_NOT_ENOUGH_DATA(())
    );
    let (result, _) = summary_stats
        .calculate_ema(
            DataType::SpotEntry('BTC/ETH'),
            AggregationMode::Median(()),
            20,
            4,
            now + 10,
            Option::None
        );
}


#[test]
#[should_panic(expected: ('EMA:No cp avlble for gvn period', 'ENTRYPOINT_FAILED'))]
#[available_gas(20000000000000)]
fn compute_macd_should_fail_if_no_checkpoint_available() {
    let (summary_stats, oracle, now) = ema_macd_initial_configuration(
        Config::ERROR_NOT_ENOUGH_DATA(())
    );
    let (result, _) = summary_stats
        .calculate_macd(
            DataType::SpotEntry('BTC/ETH'), AggregationMode::Median(()), 20, Option::None
        );
}


#[test]
#[should_panic(expected: ('EMA:No cp avlble for gvn period', 'ENTRYPOINT_FAILED'))]
#[available_gas(200000000000)]
fn compute_signal_should_fail_if_no_checkpoint_available() {
    let (summary_stats, oracle, now) = ema_macd_initial_configuration(
        Config::ERROR_NOT_ENOUGH_DATA(())
    );
    let (result, _) = summary_stats
        .calculate_signal_line(
            DataType::SpotEntry('BTC/ETH'), AggregationMode::Median(()), 20, Option::None
        );
}
