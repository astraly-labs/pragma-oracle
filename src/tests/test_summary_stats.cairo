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
use debug::PrintTrait;
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
    starknet::testing::set_block_timestamp(now);
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

    //checkpoint = 250000 (Median)
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Mean(()));

    starknet::testing::set_block_timestamp(now + 101);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: now + 100, source: 2, publisher: 1
                    }, pair_id: 2, price: 35 * 100000, volume: 0
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
                    base: BaseEntry {
                        timestamp: now + 200, source: 2, publisher: 1
                    }, pair_id: 2, price: 4 * 1000000, volume: 0
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
                    base: BaseEntry {
                        timestamp: now + 300, source: 2, publisher: 1
                    }, pair_id: 2, price: 4 * 1000000, volume: 0
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
                    base: BaseEntry {
                        timestamp: now + 400, source: 2, publisher: 1
                    }, pair_id: 2, price: 3 * 1000000, volume: 0
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
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 2, price: 2 * 1000000, volume: 0
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 2, price: 2 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    starknet::testing::set_block_timestamp(now + 200);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now + 200, source: 1, publisher: 1
                    }, pair_id: 2, price: 8 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );

    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));

    starknet::testing::set_block_timestamp(now + 400);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now + 400, source: 1, publisher: 1
                    }, pair_id: 2, price: 3 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    starknet::testing::set_block_timestamp(now + 600);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now + 600, source: 1, publisher: 1
                    }, pair_id: 2, price: 5 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );
    oracle.set_checkpoint(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
    starknet::testing::set_block_timestamp(now);
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 1, publisher: 1
                    }, pair_id: 3, price: 2 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 2, publisher: 1
                    }, pair_id: 3, price: 4 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now, source: 3, publisher: 1
                    }, pair_id: 3, price: 6 * 1000000, volume: 100, expiration_timestamp: 11111110
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
                    base: BaseEntry {
                        timestamp: now + 200, source: 1, publisher: 1
                    }, pair_id: 3, price: 8 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now + 200, source: 2, publisher: 1
                    }, pair_id: 3, price: 8 * 1000000, volume: 100, expiration_timestamp: 11111110
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
                    base: BaseEntry {
                        timestamp: now + 400, source: 1, publisher: 1
                    }, pair_id: 3, price: 2 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now + 400, source: 2, publisher: 1
                    }, pair_id: 3, price: 3 * 1000000, volume: 100, expiration_timestamp: 11111110
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: now + 400, source: 3, publisher: 1
                    }, pair_id: 3, price: 4 * 1000000, volume: 100, expiration_timestamp: 11111110
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
                    base: BaseEntry {
                        timestamp: now + 600, source: 1, publisher: 1
                    }, pair_id: 3, price: 5 * 1000000, volume: 100, expiration_timestamp: 11111110
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
