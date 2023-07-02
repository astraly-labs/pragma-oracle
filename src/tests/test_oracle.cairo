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
use starknet::testing;
use starknet::syscalls::deploy_syscall;
use starknet::class_hash::{Felt252TryIntoClassHash};
use starknet::Felt252TryIntoContractAddress;
// use starknet::class_hash::class_hash_try_from_felt252;
use starknet::contract_address::contract_address_const;
const ONE_ETH: felt252 = 1000000000000000000;
const CHAIN_ID : felt252 =  'SN_MAIN';
const BLOCK_TIMESTAMP: u64 = '103374042_u64';

fn setup() -> (IPublisherRegistryABIDispatcher, IOracleABIDispatcher) {
    let admin = contract_address_const::<0x123456789>();
    testing::set_block_timestamp(BLOCK_TIMESTAMP);

    // setup chain id to compute vouchers hashes
    testing::set_chain_id(CHAIN_ID);
    let now = 100000;
    let (oracle_address, _) =deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, ArrayTrait::new().span(), false
    ).unwrap_syscall();

    let mut oracle = IOracleABIDispatcher { contract_address: oracle_address };

    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(admin.into());
    let (publisher_registry_address, _) = deploy_syscall(
        PublisherRegistry::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        constructor_calldata.span(),
        false
    ).unwrap_syscall();
    let mut publisher_registry = IPublisherRegistryABIDispatcher {
        contract_address: publisher_registry_address
    };

    publisher_registry.add_publisher(1, admin);

    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(1, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(1, 2);

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
                base_currency_id: 222, // currency id - str_to_felt encode the ticker
            }
        );
oracle
    .initializer(
        publisher_registry_address.into(), currencies.span(), pairs.span()
    );
    let decimals_1 = oracle.get_decimals(DataType::SpotEntry(1));
publisher_registry.get_publisher_address(1).print();

(publisher_registry, oracle)
}

#[test]
#[available_gasx(2000000000)]
fn test_get_decimals() {
     let (publisher_registry, oracle) = setup();
    assert(1 == 1, 'no');
let decimals_1 = oracle.get_decimals(DataType::SpotEntry(1));
decimals_1.print();
assert(decimals_1 == 18_u32, 'wrong decimals value');
let decimals_2 = oracle.get_decimals(DataType::SpotEntry(2));
assert(decimals_2 == 6_u32, 'wrong decimals value');
let decimals_3 = oracle.get_decimals(DataType::SpotEntry(10));
assert(decimals_3 == 0, 'wrong decimals value');
}
// #[test]
// #[available_gas(2000000000)]
// fn test_get_spot_entry() {
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data(DataType::SpotEntry(1), AggregationMode::Median(()));
//     assert(entry.price == (1000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
// }
// #[test]
// #[available_gas(2000000000)]
// fn test_get_future_entry() {
//     let (publisher_registry, oracle) = setup();
//     let entry = oracle.get_data(DataType::FutureEntry((2, 11111110)), AggregationMode::Median(()));
//     assert(entry.price == (2 * 1000000).into(), 'wrong price');
//     assert(entry.num_sources_aggregated == 1, 'wrong number of sources');
// }


