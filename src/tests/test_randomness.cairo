use array::{ArrayTrait, SpanTrait};
use starknet::{ContractAddress};
use starknet::testing;
use pragma::entry::structs::{Currency, Pair, PossibleEntries, SpotEntry, BaseEntry};
use pragma::randomness::example_randomness::{
    ExampleRandomness, IExampleRandomnessDispatcher, IExampleRandomnessDispatcherTrait
};
use pragma::randomness::randomness::{
    Randomness, IRandomnessDispatcher, IRandomnessDispatcherTrait, RequestStatus
};
use openzeppelin::token::erc20::{ERC20, interface::{IERC20Dispatcher, IERC20DispatcherTrait}};
use pragma::publisher_registry::publisher_registry::{
    IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait, PublisherRegistry
};
use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait, Oracle};
use starknet::contract_address::contract_address_const;
use starknet::syscalls::deploy_syscall;
use option::OptionTrait;
use starknet::SyscallResultTrait;
use serde::Serde;
use result::ResultTrait;
use traits::{Into, TryInto};
use starknet::info;
use debug::PrintTrait;
const INITIAL_SUPPLY: u128 = 100000000000000000000000000;
const CHAIN_ID: felt252 = 'SN_MAIN';
const BLOCK_TIMESTAMP: u64 = 103374042;
const MAX_PREMIUM_FEE: u128 = 100000000; // 1$ with 8 decimals
const ETH_USD_PRICE: u128 = 2000000;

fn pop_log<T, impl TDrop: Drop<T>, impl TEvent: starknet::Event<T>>(
    address: ContractAddress
) -> Option<T> {
    let (mut keys, mut data) = testing::pop_log_raw(address)?;
    let ret = starknet::Event::deserialize(ref keys, ref data);
    assert(data.is_empty(), 'Event has extra data');
    ret
}


fn setup() -> (
    IRandomnessDispatcher,
    IExampleRandomnessDispatcher,
    ContractAddress,
    ContractAddress,
    IERC20Dispatcher
) {
    let admin_address = contract_address_const::<0x1234>();
    starknet::testing::set_contract_address(admin_address);
    starknet::testing::set_chain_id(CHAIN_ID);
    starknet::testing::set_block_timestamp(BLOCK_TIMESTAMP);
    // TOKEN 1 deployment
    let mut token_1_calldata = ArrayTrait::new();
    let token_1: felt252 = 'Pragma1';
    let symbol_1: felt252 = 'PRA1';
    let initial_supply: u256 = u256 { high: 0, low: INITIAL_SUPPLY };
    token_1.serialize(ref token_1_calldata);
    symbol_1.serialize(ref token_1_calldata);
    initial_supply.serialize(ref token_1_calldata);
    admin_address.serialize(ref token_1_calldata);
    let (token_1_address, _) = deploy_syscall(
        ERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, token_1_calldata.span(), true
    )
        .unwrap_syscall();
    let mut token_1 = IERC20Dispatcher { contract_address: token_1_address };
    // PUBLISHER REGISTRY deployment
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(admin_address.into());
    let (publisher_registry_address, _) = deploy_syscall(
        PublisherRegistry::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), true
    )
        .unwrap_syscall();
    let mut publisher_registry = IPublisherRegistryABIDispatcher {
        contract_address: publisher_registry_address
    };

    // ORACLE deployment
    let mut currencies = ArrayTrait::<Currency>::new();
    currencies
        .append(
            Currency {
                id: 'ETH',
                decimals: 8_u32,
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
                decimals: 8_u32,
                is_abstract_currency: false, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
                starknet_address: 0
                    .try_into()
                    .unwrap(), // optional, e.g. can have synthetics for non-bridged assets
                ethereum_address: 0.try_into().unwrap(), // optional
            }
        );
    let mut pairs = array![
        Pair { id: 'ETH/USD', base_currency_id: 'ETH', quote_currency_id: 'USD', }
    ];

    let mut oracle_calldata = ArrayTrait::new();
    admin_address.serialize(ref oracle_calldata);
    publisher_registry_address.serialize(ref oracle_calldata);
    currencies.serialize(ref oracle_calldata);
    pairs.serialize(ref oracle_calldata);
    let (oracle_address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, oracle_calldata.span(), true
    )
        .unwrap_syscall();

    let mut oracle = IOracleABIDispatcher { contract_address: oracle_address };

    // Data publish
    let now = 100000;
    publisher_registry.add_publisher(1, admin_address);
    // Add source 1 for publisher 1
    publisher_registry.add_source_for_publisher(1, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(1, 2);
    oracle
        .publish_data(
            PossibleEntries::Spot(
                SpotEntry {
                    base: BaseEntry { timestamp: now, source: 1, publisher: 1 },
                    pair_id: 'ETH/USD',
                    price: ETH_USD_PRICE,
                    volume: 12131
                }
            )
        );
    // RANDOMNESS deployment
    let public_key = 12345678;
    let mut calldata = ArrayTrait::new();
    admin_address.serialize(ref calldata);
    public_key.serialize(ref calldata);
    token_1_address.serialize(ref calldata);
    oracle_address.serialize(ref calldata);
    let (randomness_contract, _) = deploy_syscall(
        Randomness::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), true
    )
        .unwrap_syscall();
    let randomness_dispatcher = IRandomnessDispatcher { contract_address: randomness_contract };
    let mut example_calldata = ArrayTrait::new();
    randomness_contract.serialize(ref example_calldata);
    let (example_randomness_contract, _) = deploy_syscall(
        ExampleRandomness::TEST_CLASS_HASH.try_into().unwrap(), 0, example_calldata.span(), true
    )
        .unwrap_syscall();
    let example_randomness_dispatcher = IExampleRandomnessDispatcher {
        contract_address: example_randomness_contract
    };
    token_1.transfer(example_randomness_contract, u256 { high: 0, low: INITIAL_SUPPLY / 20 });
    token_1.balance_of(example_randomness_contract);
    assert(
        token_1
            .balance_of(example_randomness_contract) == u256 { high: 0, low: INITIAL_SUPPLY / 20 },
        'wrong initial balance'
    );
    starknet::testing::set_contract_address(example_randomness_contract);
    token_1.approve(randomness_contract, u256 { high: 0, low: INITIAL_SUPPLY });

    return (
        randomness_dispatcher,
        example_randomness_dispatcher,
        randomness_contract,
        example_randomness_contract,
        token_1
    );
}

fn randomness_request_event_handler(
    randomness_address: ContractAddress,
    request_id: u64,
    caller_address: ContractAddress,
    seed: u64,
    minimum_block_number: u64,
    callback_address: ContractAddress,
    callback_fee_limit: u128,
    num_words: u64
) {
    let event = pop_log::<Randomness::RandomnessRequest>(randomness_address).unwrap();
    assert(event.request_id == request_id, 'wrong `request_id`');
    assert(event.caller_address == caller_address, 'wrong `requestor_address`');
    assert(event.seed == seed, 'wrong `seed`');
    assert(event.minimum_block_number == minimum_block_number, 'wrong `block_number`');
    assert(event.callback_address == callback_address, 'wrong `callback_address`');
    assert(event.callback_fee_limit == callback_fee_limit, 'wrong `callback_gas_limit`');
    assert(event.num_words == num_words, 'wrong `num_words`');
}

#[test]
#[available_gas(100000000000)]
fn test_randomness() {
    let admin = contract_address_const::<0x1234>();
    let (randomness, example_randomness, randomness_address, example_randomness_address, token_1) =
        setup();
    starknet::testing::set_contract_address(example_randomness_address);
    let initial_supply = u256 { high: 0, low: INITIAL_SUPPLY / 20 };
    let initial_user_balance = token_1.balance_of(example_randomness_address);
    assert(initial_user_balance == initial_supply, 'wrong initial user balance');
    let seed = 1;
    let callback_fee_limit = 900000000;
    let premium_fee = (MAX_PREMIUM_FEE * 1000000000000000000) / ETH_USD_PRICE;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_fee_limit, publish_delay, num_words);
    randomness_request_event_handler(
        randomness_address,
        0,
        example_randomness_address,
        seed,
        1,
        callback_address,
        callback_fee_limit,
        num_words
    );
    let request_user_balance = token_1.balance_of(example_randomness_address);
    assert(
        request_user_balance == initial_supply - callback_fee_limit.into() - premium_fee.into(),
        'wrong request user balance'
    );
    assert(
        randomness.get_total_fees(example_randomness_address, 0) == callback_fee_limit.into()
            + premium_fee.into(),
        'wrong total fees(1)'
    );
    let mut random_words = ArrayTrait::<felt252>::new();
    let res = example_randomness.get_last_random();
    assert(res == 0, 'wrong random');
    let random_words = array![10000];
    let block_hash = 123456789;
    let proof = array![100, 200, 300];
    let minimum_block_number = 2;
    let callback_fee = 1000000;
    testing::set_block_number(4);
    testing::set_contract_address(admin);
    randomness
        .submit_random(
            0,
            example_randomness_address,
            seed,
            1,
            callback_address,
            callback_fee_limit,
            callback_fee,
            random_words.span(),
            proof.span()
        );
    assert(
        randomness.get_total_fees(example_randomness_address, 0) == callback_fee_limit.into()
            + premium_fee.into(),
        'wrong total fees(2)'
    );
    let final_user_balance = token_1.balance_of(example_randomness_address);
    assert(
        final_user_balance == initial_supply - callback_fee.into() - premium_fee.into(),
        'wrong final user balance'
    );
    let res = example_randomness.get_last_random();
    assert(res == 10000, 'wrong random');
}


#[test]
#[available_gas(20000000000)]
fn test_randomness_cancellation() {
    let (randomness, example_randomness, randomness_address, example_randomness_address, token_1) =
        setup();
    testing::set_contract_address(example_randomness_address);
    let initial_supply = u256 { high: 0, low: INITIAL_SUPPLY / 20 };
    let initial_user_balance = token_1.balance_of(example_randomness_address);
    assert(initial_user_balance == initial_supply, 'wrong initial user balance');
    assert(
        randomness.get_total_fees(example_randomness_address, 0) == 0.into(), 'wrong total fees(1)'
    );
    let seed = 1;
    let premium_fee = (MAX_PREMIUM_FEE * 1000000000000000000) / ETH_USD_PRICE;
    let callback_fee_limit = 900000000;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_fee_limit, publish_delay, num_words);
    randomness_request_event_handler(
        randomness_address,
        0,
        example_randomness_address,
        seed,
        1,
        callback_address,
        callback_fee_limit,
        num_words
    );
    assert(
        randomness.get_total_fees(example_randomness_address, 0) == callback_fee_limit.into()
            + premium_fee.into(),
        'wrong total fees'
    );
    let request_user_balance = token_1.balance_of(example_randomness_address);
    assert(
        request_user_balance == initial_supply - callback_fee_limit.into() - premium_fee.into(),
        'wrong request user balance'
    );
    let mut random_words = ArrayTrait::<felt252>::new();
    let res = example_randomness.get_last_random();
    assert(res == 0, 'wrong random');
    testing::set_block_number(3);
    randomness
        .cancel_random_request(
            0, example_randomness_address, seed, 1, callback_address, callback_fee_limit, 1,
        );
    let cancel_user_balance = token_1.balance_of(example_randomness_address);
    assert(cancel_user_balance == initial_supply, 'wrong request user balance');
    assert(
        randomness.get_total_fees(example_randomness_address, 0) == 0.into(), 'wrong total fees(2)'
    );
    let request_status = randomness.get_request_status(example_randomness_address, 0);
    assert(request_status == RequestStatus::CANCELLED, 'wrong request status');
}

#[test]
#[should_panic(expected: ('request already fulfilled', 'ENTRYPOINT_FAILED'))]
#[available_gas(100000000000)]
fn test_cancel_random_request_should_fail_if_fulflled() {
    let admin_address = contract_address_const::<0x1234>();
    let (randomness, example_randomness, randomness_address, example_randomness_address, token_1) =
        setup();
    testing::set_contract_address(example_randomness_address);
    let seed = 1;
    let callback_fee_limit = 90000000000;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_fee_limit, publish_delay, num_words);
    let mut random_words = ArrayTrait::<felt252>::new();
    let res = example_randomness.get_last_random();
    assert(res == 0, 'wrong random');
    let random_words = array![10000];
    let block_hash = 123456789;
    let proof = array![100, 200, 300];
    let minimum_block_number = 2;
    let callback_fee = 1000000;
    testing::set_block_number(4);
    testing::set_contract_address(admin_address);
    randomness
        .submit_random(
            0,
            example_randomness_address,
            seed,
            1,
            callback_address,
            callback_fee_limit,
            callback_fee,
            random_words.span(),
            proof.span()
        );
    let res = example_randomness.get_last_random();
    assert(res == 10000, 'wrong random');
    testing::set_contract_address(example_randomness_address);
    randomness
        .cancel_random_request(
            0, example_randomness_address, seed, 1, callback_address, callback_fee_limit, 1,
        );
}

#[test]
#[should_panic(expected: ('request already cancelled', 'ENTRYPOINT_FAILED'))]
#[available_gas(100000000000)]
fn test_submit_random_should_fail_if_request_cancelled() {
    let (randomness, example_randomness, randomness_address, example_randomness_address, token_1) =
        setup();
    let admin_address = contract_address_const::<0x1234>();

    testing::set_contract_address(example_randomness_address);
    let seed = 1;
    let callback_fee_limit = 900000000;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_fee_limit, publish_delay, num_words);
    let mut random_words = ArrayTrait::<felt252>::new();
    let res = example_randomness.get_last_random();
    assert(res == 0, 'wrong random');
    let random_words = array![10000];
    let block_hash = 123456789;
    let proof = array![100, 200, 300];
    let minimum_block_number = 2;
    let callback_fee = 1000000;
    randomness
        .cancel_random_request(
            0, example_randomness_address, seed, 1, callback_address, callback_fee_limit, 1,
        );
    testing::set_block_number(4);
    testing::set_contract_address(admin_address);
    randomness
        .submit_random(
            0,
            example_randomness_address,
            seed,
            1,
            callback_address,
            callback_fee_limit,
            callback_fee,
            random_words.span(),
            proof.span()
        );
}

#[test]
#[available_gas(20000000000)]
fn test_randomness_id_incrementation() {
    let (randomness, example_randomness, randomness_address, example_randomness_address, token_1) =
        setup();
    testing::set_contract_address(example_randomness_address);
    let seed = 1;
    let callback_gas_limit = 0;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_gas_limit, publish_delay, num_words);
    randomness_request_event_handler(
        randomness_address,
        0,
        example_randomness_address,
        seed,
        1,
        callback_address,
        callback_gas_limit,
        num_words
    );
    let mut random_words = ArrayTrait::<felt252>::new();
    let res = example_randomness.get_last_random();
    assert(res == 0, 'wrong random');
    let random_words = array![10000];
    let block_hash = 123456789;
    let proof = array![100, 200, 300];
    let minimum_block_number = 2;
    testing::set_block_number(3);
    randomness
        .cancel_random_request(
            0, example_randomness_address, seed, 1, callback_address, callback_gas_limit, 1,
        );
    let request_status = randomness.get_request_status(example_randomness_address, 0);
    assert(request_status == RequestStatus::CANCELLED, 'wrong request status');
    let random_id = randomness
        .request_random(seed, callback_address, callback_gas_limit, publish_delay, num_words);
    assert(random_id == 1, 'wrong id ');
}

#[test]
#[available_gas(2000000000000)]
fn test_out_of_gas_refund_check() {
    let (randomness, example_randomness, randomness_address, example_randomness_address, token_1) =
        setup();
    let admin_address = contract_address_const::<0x1234>();
    let initial_supply = u256 { high: 0, low: INITIAL_SUPPLY / 20 };
    let initial_user_balance = token_1.balance_of(example_randomness_address);
    assert(initial_user_balance == initial_supply, 'wrong initial user balance');
    testing::set_contract_address(example_randomness_address);

    let seed = 1;
    let callback_fee_limit = 90000000000;
    let premium_fee = (MAX_PREMIUM_FEE * 1000000000000000000) / ETH_USD_PRICE;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_fee_limit, publish_delay, num_words);
    let request_user_balance = token_1.balance_of(example_randomness_address);
    assert(
        request_user_balance == initial_supply - callback_fee_limit.into() - premium_fee.into(),
        'wrong request user balance'
    );
    testing::set_contract_address(admin_address);
    randomness.update_status(example_randomness_address, request_id, RequestStatus::OUT_OF_GAS(()));
    assert(
        randomness
            .get_request_status(
                example_randomness_address, request_id
            ) == RequestStatus::OUT_OF_GAS(()),
        'wrong request status'
    );
    testing::set_contract_address(example_randomness_address);
    randomness.refund_operation(example_randomness_address, request_id);
    let refund_user_balance = token_1.balance_of(example_randomness_address);
    assert(refund_user_balance == initial_supply, 'wrong refund user balance');
}

//NOTICE: THE REFUND PROCESS CAN BE CHALLENGING IF THE USER IS SENDING LOTS OF REQUESTS AND CANNOT FIND THE REQUEST ID THAT FAILED
//TODO: add a function that loop on the number of requests to return the list of request ids that failed and the total debt

#[test]
#[should_panic(expected: ('no due amount', 'ENTRYPOINT_FAILED'))]
#[available_gas(2000000000000)]
fn test_refund_fails_if_id_not_valid_id() {
    let (randomness, example_randomness, randomness_address, example_randomness_address, token_1) =
        setup();
    testing::set_contract_address(example_randomness_address);
    randomness.refund_operation(example_randomness_address, 1);
}

#[test]
#[should_panic(expected: ('request not out of gas', 'ENTRYPOINT_FAILED'))]
#[available_gas(2000000000000)]
fn test_refund_fails_if_no_due_amount() {
    let (randomness, example_randomness, randomness_address, example_randomness_address, token_1) =
        setup();
    testing::set_contract_address(example_randomness_address);
    let seed = 1;
    let callback_fee_limit = 900000000;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_fee_limit, publish_delay, num_words);
    randomness.refund_operation(example_randomness_address, request_id);
}

