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
use pragma::summary_stats::summary_stats::SummaryStats;
use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
use pragma::publisher_registry::publisher_registry::{
    IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
};
use pragma::summary_stats::summary_stats::{
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
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    starknet::testing::set_block_timestamp(now + 100);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: now + 200, source: 2, publisher: 1
                    }, pair_id: 2, price: 35 * 100000, volume: 0
                }
            )
        );
    oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    // starknet::testing::set_block_timestamp(now + 200);
    // oracle
    //     .publish_data(
    //         PossibleEntries::Spot(
    //             SpotEntry {
    //                 base: BaseEntry {
    //                     timestamp: now + 200, source: 2, publisher: 1
    //                 }, pair_id: 2, price: 4 * 1000000, volume: 0
    //             }
    //         )
    //     );
    // oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    // starknet::testing::set_block_timestamp(now + 300);
    // oracle
    //     .publish_data(
    //         PossibleEntries::Spot(
    //             SpotEntry {
    //                 base: BaseEntry {
    //                     timestamp: now + 300, source: 2, publisher: 1
    //                 }, pair_id: 2, price: 4 * 1000000, volume: 0
    //             }
    //         )
    //     );
    // oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));
    // starknet::testing::set_block_timestamp(now + 400);
    // oracle
    //     .publish_data(
    //         PossibleEntries::Spot(
    //             SpotEntry {
    //                 base: BaseEntry {
    //                     timestamp: now + 400, source: 2, publisher: 1
    //                 }, pair_id: 2, price: 3 * 1000000, volume: 0
    //             }
    //         )
    //     );
    // oracle.set_checkpoint(DataType::SpotEntry(2), AggregationMode::Median(()));

    (summary_stats, oracle)
}


#[test]
#[available_gas(200000000000)]
fn test_summary_stats_mean() {
    let (summary_stats, oracle) = setup();
    // starknet::testing::set_block_timestamp(100001);

    starknet::testing::set_block_timestamp(100001 + 1100);
    let check = oracle.get_checkpoint(DataType::SpotEntry(2), 1, AggregationMode::Median(()));
    check.value.print();
// let mean = summary_stats
//     .calculate_mean(
//         DataType::SpotEntry(2), 100001, (100001 + 400), AggregationMode::Median(())
//     );
// mean.print();
}
