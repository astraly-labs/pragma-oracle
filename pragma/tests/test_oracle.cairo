use array::ArrayTrait;
use result::ResultTrait;
use cheatcodes::RevertedTransactionTrait;
use protostar_print::PrintTrait;
use starknet::ContractAddress;
use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntries, FutureEntry, OptionEntry,
    simpleDataType, entryDataType
};
use traits::Into;

const admin_address: felt252 = 1234;

const ONE_ETH: felt252 = 10 * *18;
const USD_CURRENCY_ID: felt252 = 5591876; // str_to_felt("USD")

fn setup() -> (ContractAddress, ContractAddress) {
    let oracle_admin_address = admin_address;
    let now = 100000;

    let oracle_address = deploy_contract('Oracle', @ArrayTrait::new()).unwrap();

    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(oracle_admin_address);
    let publisher_registry_address = deploy_contract('publisher_registry', @constructor_calldata)
        .unwrap();

    start_prank(oracle_admin_address, publisher_registry_address).unwrap();

    // Add publisher 1
    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(1);
    invoke_calldata.append(oracle_admin_address);
    invoke(publisher_registry_address, 'add_publisher', @invoke_calldata).unwrap();

    // Add source 1 for publisher 1
    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(1);
    invoke_calldata.append(1);
    invoke(publisher_registry_address, 'add_source_for_publisher', @invoke_calldata).unwrap();
    // Add source 2 for publisher 1
    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(1);
    invoke_calldata.append(2);
    invoke(publisher_registry_address, 'add_source_for_publisher', @invoke_calldata).unwrap();

    stop_prank(publisher_registry_address);
    start_prank(oracle_admin_address, oracle_address).unwrap();

    let mut currencies = ArrayTrait::new();
    currencies
        .append(
            Currency {
                id: 111,
                decimals: 18_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .into(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.into(), // optional
            }
        )

    currencies
        .append(
            Currency {
                id: 222,
                decimals: 18_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .into(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.into(), // optional
            }
        )
    currencies
        .append(
            Currency {
                id: USD_CURRENCY_ID,
                decimals: 6_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .into(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.into(), // optional
            }
        )
    currencies
        .append(
            Currency {
                id: 333,
                decimals: 18_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .into(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.into(), // optional
            }
        )

    let mut pairs = ArrayTrait::new();
    pairs
        .append(
            Pair {
                id: 1, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 111, // currency id - str_to_felt encode the ticker
                base_currency_id: 222, // currency id - str_to_felt encode the ticker
            }
        )
    pairs
        .append(
            Pair {
                id: 2, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 111, // currency id - str_to_felt encode the ticker
                base_currency_id: USD_CURRENCY_ID, // currency id - str_to_felt encode the ticker
            }
        )
    pairs
        .append(
            Pair {
                id: 3, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 222, // currency id - str_to_felt encode the ticker
                base_currency_id: USD_CURRENCY_ID, // currency id - str_to_felt encode the ticker
            }
        )
    pairs
        .append(
            Pair {
                id: 4, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 111, // currency id - str_to_felt encode the ticker
                base_currency_id: 333, // currency id - str_to_felt encode the ticker
            }
        )
    pairs
        .append(
            Pair {
                id: 5, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
                quote_currency_id: 333, // currency id - str_to_felt encode the ticker
                base_currency_id: 222, // currency id - str_to_felt encode the ticker
            }
        )

    // Initialize oracle
    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(1234);
    invoke_calldata.append(publisher_registry_address);
    invoke_calldata.append(currencies);
    invoke_calldata.append(pairs);
    invoke(oracle_address, 'initializer', @invoke_calldata).unwrap();

    // Publish SPOT data

    // Publish FUTURE data

    // TODO: Publish OPTION data

    (oracle_address, publisher_registry_address)
}

#[test]
fn test_set_decimals() {
    let (oracle_address, publisher_registry_address) = setup();

    let mut calldata = ArrayTrait::new();
    calldata.append(DataType::SPOT(1));
    calldata.append(1);
    let decimals = invoke(oracle_address, 'get_decimals', @calldata).unwrap();
    
    assert(decimals == 18_u32, 'wrong decimals value');
}

#[test]
fn test_get_spot_entry() {
    let (oracle_address, publisher_registry_address) = setup();

    let mut calldata = ArrayTrait::new();
    calldata.append(DataType::SPOT(2));
    calldata.append(1);
    let entry = invoke(oracle_address, 'get_entry', @calldata).unwrap();

    assert(entry.price == (1 * 10 ** 6).into(), 'wrong price');
    assert(entry.base.source == 1, 'wrong source');
}

#[test]
fn test_get_future_entry() {
    let (oracle_address, publisher_registry_address) = setup();

    let mut calldata = ArrayTrait::new();
    calldata.append(DataType::FUTURE(2));
    calldata.append(11111110);
    calldata.append(1);
    let future_entry = invoke(oracle_address, 'get_entry', @calldata).unwrap();
    
    assert(future_entry.price == (2 * 10 ** 6).into(), 'wrong price');
    assert(future_entry.base.source == 1, 'wrong source');
}
