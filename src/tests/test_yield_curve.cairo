use array::{ArrayTrait, SpanTrait};
use starknet::ContractAddress;
use starknet::syscalls::deploy_syscall;
use pragma::entry::structs::{
    Currency, Pair, PossibleEntries, SpotEntry, FutureEntry, BaseEntry, GenericEntry, DataType,
    AggregationMode
};
use starknet::testing::{set_contract_address, set_block_timestamp, set_chain_id, };
use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
use pragma::publisher_registry::publisher_registry::{
    IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
};
use pragma::compute_engines::yield_curve::yield_curve::{
    IYieldCurveABIDispatcher, IYieldCurveABIDispatcherTrait
};
use serde::Serde;
use starknet::SyscallResultTrait;
use starknet::contract_address::contract_address_const;
use debug::PrintTrait;
use pragma::oracle::oracle::Oracle;
use pragma::publisher_registry::publisher_registry::PublisherRegistry;
use pragma::compute_engines::yield_curve::yield_curve::YieldCurve;
use traits::{TryInto, Into};
use option::OptionTrait;
use result::ResultTrait;

const AAVE_ON_BORROW: felt252 = 'AAVE-ON-BORROW';
const ON_KEY: felt252 = 'AAVE-ON-BORROW';
const BTC: felt252 = 'BTC';
const USD: felt252 = 'USD';
const BTC_USD: felt252 = 'BTC/USD';
const CHAIN_ID: felt252 = 'SN_MAIN';
const STARKNET_STARTING_TIMESTAMP: u64 = 1650590820;
const BLOCK_TIMESTAMP: u64 = 103374042;
fn setup() -> (IOracleABIDispatcher, IYieldCurveABIDispatcher) {
    let mut currencies = ArrayTrait::<Currency>::new();
    currencies
        .append(
            Currency {
                id: BTC,
                decimals: 8,
                is_abstract_currency: false,
                starknet_address: 0.try_into().unwrap(),
                ethereum_address: 0.try_into().unwrap()
            }
        );
    currencies
        .append(
            Currency {
                id: USD,
                decimals: 8,
                is_abstract_currency: false,
                starknet_address: 0.try_into().unwrap(),
                ethereum_address: 0.try_into().unwrap()
            }
        );
    currencies
        .append(
            Currency {
                id: AAVE_ON_BORROW,
                decimals: 8,
                is_abstract_currency: true,
                starknet_address: 0.try_into().unwrap(),
                ethereum_address: 0.try_into().unwrap()
            }
        );

    let mut pairs = ArrayTrait::<Pair>::new();
    pairs.append(Pair { id: BTC_USD, quote_currency_id: USD, base_currency_id: BTC });
    pairs.append(Pair { id: ON_KEY, quote_currency_id: USD, base_currency_id: AAVE_ON_BORROW });
    let admin = contract_address_const::<0x123456789>();
    set_contract_address(admin);
    set_block_timestamp(BLOCK_TIMESTAMP);
    set_chain_id(CHAIN_ID);
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(admin.into());
    let (publisher_registry_address, _) = deploy_syscall(
        PublisherRegistry::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), true
    )
        .unwrap_syscall();
    let mut publisher_registry = IPublisherRegistryABIDispatcher {
        contract_address: publisher_registry_address
    };
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
    let mut yield_curve_calldata = ArrayTrait::<felt252>::new();
    admin.serialize(ref yield_curve_calldata);
    oracle_address.serialize(ref yield_curve_calldata);
    let (yield_curve_address, _) = deploy_syscall(
        YieldCurve::TEST_CLASS_HASH.try_into().unwrap(), 0, yield_curve_calldata.span(), true
    )
        .unwrap_syscall();
    let mut yield_curve = IYieldCurveABIDispatcher { contract_address: yield_curve_address };
    publisher_registry.add_publisher(1, admin);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(1, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(1, 2);
    yield_curve.add_on_key(ON_KEY, true);
    yield_curve.set_future_spot_pragma_source_key(1);
    yield_curve.add_pair_id(BTC_USD, true);
    yield_curve.add_future_expiry_timestamp(BTC_USD, 20220624, true, 1656039600);
    yield_curve.add_future_expiry_timestamp(BTC_USD, 20220930, true, 1664506800);
    yield_curve.add_future_expiry_timestamp(BTC_USD, 20221230, true, 1672369200);
    yield_curve.add_future_expiry_timestamp(BTC_USD, 20230330, true, 1680145200);

    (oracle, yield_curve)
}

#[test]
#[available_gas(10000000000)]
fn test_yield_curve_deploy() {
    let (oracle, yield_curve) = setup();
    let on_keys = yield_curve.get_on_keys();
    assert(*on_keys.at(0) == ON_KEY, 'wrong on key');
    let on_key_is_active = yield_curve.get_on_key_is_active(ON_KEY);
    assert(on_key_is_active, 'wrong active key');
    let pair_ids = yield_curve.get_pair_ids();
    assert(*pair_ids.at(0) == BTC_USD, 'wrong pair id');
    let pair_id_is_active = yield_curve.get_pair_id_is_active(BTC_USD);
    assert(pair_id_is_active, 'wrong active pair id');
    let future_expiry_timestamps = yield_curve.get_future_expiry_timestamps(BTC_USD);
    let expiries = array![20220624, 20220930, 20221230, 20230330];
    let mut cur_idx = 0;
    loop {
        if cur_idx == future_expiry_timestamps.len() {
            break;
        }
        assert(*future_expiry_timestamps.at(cur_idx) == *expiries.at(cur_idx), 'wrong expiry');
        cur_idx += 1;
    };
}

#[test]
#[should_panic]
#[available_gas(10000000000)]
fn test_yield_curve_empty() {
    let (oracle, yield_curve) = setup();
    let result = yield_curve.get_yield_points(10);
    assert(result.len() == 0, 'wrong result');
}

#[test]
#[available_gas(10000000000)]
fn test_yield_curve_computation() {
    let (oracle, yield_curve) = setup();
    let output_decimals = 8;
    set_block_timestamp(STARKNET_STARTING_TIMESTAMP);

    oracle
        .publish_data(
            PossibleEntries::Generic(
                GenericEntry {
                    base: BaseEntry {
                        timestamp: STARKNET_STARTING_TIMESTAMP, source: 1, publisher: 1
                    }, key: ON_KEY, value: 10000000,
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry {
                        timestamp: STARKNET_STARTING_TIMESTAMP, source: 1, publisher: 1
                    }, pair_id: BTC_USD, price: 100, volume: 10
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: STARKNET_STARTING_TIMESTAMP, source: 1, publisher: 1
                    }, pair_id: BTC_USD, expiration_timestamp: 20220624, price: 90, volume: 10
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: STARKNET_STARTING_TIMESTAMP, source: 1, publisher: 1
                    }, pair_id: BTC_USD, expiration_timestamp: 20220930, price: 110, volume: 10
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: STARKNET_STARTING_TIMESTAMP - 20, source: 1, publisher: 1
                    }, pair_id: BTC_USD, expiration_timestamp: 20221230, price: 110, volume: 10
                }
            )
        );
    oracle
        .publish_data(
            PossibleEntries::Future(
                FutureEntry {
                    base: BaseEntry {
                        timestamp: STARKNET_STARTING_TIMESTAMP + 20, source: 1, publisher: 1
                    }, pair_id: BTC_USD, expiration_timestamp: 20230330, price: 110, volume: 10
                }
            )
        );

    let result = yield_curve.get_yield_points(output_decimals);
    let test = *result.at(0);
    assert(test.rate == 10000000, 'yield computation failed');
    assert(test.expiry_timestamp == STARKNET_STARTING_TIMESTAMP, 'wrong on timestamp');
    let test_1 = *result.at(1);
    assert(test_1.rate == 0, 'yield computation failed');
    assert(test_1.expiry_timestamp == 1656039600, 'wrong expiry for 1st');
    let test_2 = *result.at(2);
    assert(test_2.rate == 22661716, 'yield computation failed');
    assert(test_2.expiry_timestamp == 1664506800, 'wrong expiry for 2nd');
    return ();
}
