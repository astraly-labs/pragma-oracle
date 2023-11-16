use array::{ArrayTrait, SpanTrait};
use starknet::{ContractAddress};
use starknet::testing;
use pragma::randomness::example_randomness::{
    ExampleRandomness, IExampleRandomnessDispatcher, IExampleRandomnessDispatcherTrait
};
use pragma::randomness::randomness::{
    Randomness, IRandomnessDispatcher, IRandomnessDispatcherTrait, RequestStatus
};
use starknet::contract_address::contract_address_const;
use starknet::syscalls::deploy_syscall;
use option::OptionTrait;
use starknet::SyscallResultTrait;
use serde::Serde;
use result::ResultTrait;
use traits::{Into, TryInto};
use starknet::info;

fn pop_log<T, impl TDrop: Drop<T>, impl TEvent: starknet::Event<T>>(
    address: ContractAddress
) -> Option<T> {
    let (mut keys, mut data) = testing::pop_log_raw(address)?;
    let ret = starknet::Event::deserialize(ref keys, ref data);
    assert(data.is_empty(), 'Event has extra data');
    ret
}


fn setup() -> (
    IRandomnessDispatcher, IExampleRandomnessDispatcher, ContractAddress, ContractAddress
) {
    let mut constructor_calldata = ArrayTrait::new();
    let admin_address = contract_address_const::<0x1234>();
    let public_key = 12345678;
    admin_address.serialize(ref constructor_calldata);
    public_key.serialize(ref constructor_calldata);
    let (randomness_contract, _) = deploy_syscall(
        Randomness::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), true
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
    return (
        randomness_dispatcher,
        example_randomness_dispatcher,
        randomness_contract,
        example_randomness_contract
    );
}

fn randomness_request_event_handler(
    randomness_address: ContractAddress,
    request_id: u64,
    caller_address: ContractAddress,
    seed: u64,
    minimum_block_number: u64,
    callback_address: ContractAddress,
    callback_gas_limit: u64,
    num_words: u64
) {
    let event = pop_log::<Randomness::RandomnessRequest>(randomness_address).unwrap();
    assert(event.request_id == request_id, 'wrong `request_id`');
    assert(event.caller_address == caller_address, 'wrong `requestor_address`');
    assert(event.seed == seed, 'wrong `seed`');
    assert(event.minimum_block_number == minimum_block_number, 'wrong `block_number`');
    assert(event.callback_address == callback_address, 'wrong `callback_address`');
    assert(event.callback_gas_limit == callback_gas_limit, 'wrong `callback_gas_limit`');
    assert(event.num_words == num_words, 'wrong `num_words`');
}

#[test]
#[available_gas(100000000000)]
fn test_randomness() {
    let requestor_address = contract_address_const::<0x1234>();
    testing::set_contract_address(requestor_address);
    let (randomness, example_randomness, randomness_address, example_randomness_address) = setup();
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
        requestor_address,
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
    testing::set_block_number(4);
    randomness
        .submit_random(
            0,
            requestor_address,
            seed,
            1,
            callback_address,
            callback_gas_limit,
            random_words.span(),
            proof.span()
        );
    let res = example_randomness.get_last_random();
    assert(res == 10000, 'wrong random');
}


#[test]
#[available_gas(2000000)]
fn test_randomness_cancellation() {
    let requestor_address = contract_address_const::<0x1234>();
    testing::set_contract_address(requestor_address);
    let (randomness, example_randomness, randomness_address, example_randomness_address) = setup();
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
        requestor_address,
        seed,
        1,
        callback_address,
        callback_gas_limit,
        num_words
    );
    let mut random_words = ArrayTrait::<felt252>::new();
    let res = example_randomness.get_last_random();
    assert(res == 0, 'wrong random');
    testing::set_block_number(3);
    randomness
        .cancel_random_request(
            0, requestor_address, seed, 1, callback_address, callback_gas_limit, 1,
        );
    let request_status = randomness.get_request_status(requestor_address, 0);
    assert(request_status == RequestStatus::CANCELLED, 'wrong request status');
}


#[test]
#[should_panic(expected: ('request already fulfilled', 'ENTRYPOINT_FAILED'))]
#[available_gas(100000000000)]
fn test_cancel_random_request_should_fail_if_fulflled() {
    let requestor_address = contract_address_const::<0x1234>();
    testing::set_contract_address(requestor_address);
    let (randomness, example_randomness, randomness_address, example_randomness_address) = setup();
    let seed = 1;
    let callback_gas_limit = 0;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_gas_limit, publish_delay, num_words);
    let mut random_words = ArrayTrait::<felt252>::new();
    let res = example_randomness.get_last_random();
    assert(res == 0, 'wrong random');
    let random_words = array![10000];
    let block_hash = 123456789;
    let proof = array![100, 200, 300];
    let minimum_block_number = 2;
    testing::set_block_number(4);
    randomness
        .submit_random(
            0,
            requestor_address,
            seed,
            1,
            callback_address,
            callback_gas_limit,
            random_words.span(),
            block_hash,
            proof.span()
        );
    let res = example_randomness.get_last_random();
    assert(res == 10000, 'wrong random');
    randomness
        .cancel_random_request(
            0, requestor_address, seed, 1, callback_address, callback_gas_limit, 1,
        );
}

#[test]
#[should_panic(expected: ('request already cancelled', 'ENTRYPOINT_FAILED'))]
#[available_gas(100000000000)]
fn test_submit_random_should_fail_if_request_cancelled() {
    let requestor_address = contract_address_const::<0x1234>();
    testing::set_contract_address(requestor_address);
    let (randomness, example_randomness, randomness_address, example_randomness_address) = setup();
    let seed = 1;
    let callback_gas_limit = 0;
    let callback_address = example_randomness_address;
    let publish_delay = 1;
    let num_words = 1;
    let block_number = info::get_block_number();
    let request_id = randomness
        .request_random(seed, callback_address, callback_gas_limit, publish_delay, num_words);
    let mut random_words = ArrayTrait::<felt252>::new();
    let res = example_randomness.get_last_random();
    assert(res == 0, 'wrong random');
    let random_words = array![10000];
    let block_hash = 123456789;
    let proof = array![100, 200, 300];
    let minimum_block_number = 2;
    randomness
        .cancel_random_request(
            0, requestor_address, seed, 1, callback_address, callback_gas_limit, 1,
        );
    testing::set_block_number(4);
    randomness
        .submit_random(
            0,
            requestor_address,
            seed,
            1,
            callback_address,
            callback_gas_limit,
            random_words.span(),
            block_hash,
            proof.span()
        );
}

#[test]
#[available_gas(20000000000)]
fn test_randomness_id_incrementation() {
    let requestor_address = contract_address_const::<0x1234>();
    testing::set_contract_address(requestor_address);
    let (randomness, example_randomness, randomness_address, example_randomness_address) = setup();
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
        requestor_address,
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
            0, requestor_address, seed, 1, callback_address, callback_gas_limit, 1,
        );
    let request_status = randomness.get_request_status(requestor_address, 0);
    assert(request_status == RequestStatus::CANCELLED, 'wrong request status');
    let random_id = randomness
        .request_random(seed, callback_address, callback_gas_limit, publish_delay, num_words);
    assert(random_id == 1, 'wrong id ');
}

