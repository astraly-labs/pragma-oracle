use array::ArrayTrait;
use result::ResultTrait;
use cheatcodes::RevertedTransactionTrait;
use protostar_print::PrintTrait;

const admin_address: felt252 = 123;
const admin_2_address: felt252 = 124;
const publisher_address: felt252 = 456;
const publisher: felt252 = 'TEST_PUBLISHER';

fn deploy_publisher_registry() -> felt252 {
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(admin_address);
    let publisher_registry_address = deploy_contract('publisher_registry', @constructor_calldata).unwrap();

    start_prank(admin_address, publisher_registry_address).unwrap();

    // Add publisher
    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(publisher);
    invoke_calldata.append(publisher_address);
    invoke(publisher_registry_address, 'add_publisher', @invoke_calldata).unwrap();

    publisher_registry_address
}

#[test]
fn test_register_non_admin_fail() {
    let publisher_registry_address = deploy_publisher_registry();

    start_prank(111, publisher_registry_address).unwrap();

    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append('NEW_PUBLISHER');
    invoke_calldata.append(222);
    
    match invoke(publisher_registry_address, 'add_publisher', @invoke_calldata) {
        Result::Ok(x) => assert(false, 'Shouldnt have succeeded'),
        Result::Err(x) => {
            assert(x.first() == 'Admin: unauthorized', 'first datum doesnt match');
        }
    }
}

#[test]
fn test_add_publisher() {
    let publisher_registry_address = deploy_publisher_registry();

    let mut calldata = ArrayTrait::new();
    calldata.append(publisher);
    let return_data2 = call(publisher_registry_address, 'get_publisher_address', @calldata).unwrap();
    assert(*return_data2.at(0_u32) == publisher_address, 'wrong publisher address');
}

#[test]
fn test_update_publisher_address() {
    let publisher_registry_address = deploy_publisher_registry();

    let mut calldata = ArrayTrait::new();
    calldata.append(publisher);
    let return_data2 = call(publisher_registry_address, 'get_publisher_address', @calldata).unwrap();
    assert(*return_data2.at(0_u32) == publisher_address, 'wrong publisher address');

    let new_publisher_address = 789;
    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(publisher);
    invoke_calldata.append(new_publisher_address);

    start_prank(publisher_address, publisher_registry_address).unwrap();

    invoke(publisher_registry_address, 'update_publisher_address', @invoke_calldata).unwrap();

    let return_data3 = call(publisher_registry_address, 'get_publisher_address', @calldata).unwrap();
    assert(*return_data3.at(0_u32) == new_publisher_address, 'wrong publisher address');
}

#[test]
fn test_rotate_fails_for_unregistered_publisher() {
    let publisher_registry_address = deploy_publisher_registry();

    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append('NEW_PUBLISHER');
    invoke_calldata.append(222);
    
    match invoke(publisher_registry_address, 'update_publisher_address', @invoke_calldata) {
        Result::Ok(x) => assert(false, 'Shouldnt have succeeded'),
        Result::Err(x) => {
            assert(x.first() == 'Name not registered', 'first datum doesnt match');
        }
    }
}

#[test]
fn test_register_second_publisher() {
    let publisher_registry_address = deploy_publisher_registry();

    start_prank(admin_address, publisher_registry_address).unwrap();

    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append('NEW_PUBLISHER');
    invoke_calldata.append(222);
    invoke(publisher_registry_address, 'add_publisher', @invoke_calldata).unwrap();

    let mut calldata = ArrayTrait::new();
    calldata.append(publisher);
    let return_data1 = call(publisher_registry_address, 'get_publisher_address', @calldata).unwrap();
    assert(*return_data1.at(0_u32) == publisher_address, 'wrong publisher address');

    let mut calldata = ArrayTrait::new();
    calldata.append('NEW_PUBLISHER');
    let return_data2 = call(publisher_registry_address, 'get_publisher_address', @calldata).unwrap();
    assert(*return_data2.at(0_u32) == 222, 'wrong publisher address');

    let return_data3 = call(publisher_registry_address, 'get_all_publishers', @ArrayTrait::new()).unwrap();
    assert(return_data3.len() == 3, 'wrong number of publishers');
    assert(*return_data3.at(1_u32) == publisher, 'wrong publisher address');
    assert(*return_data3.at(2_u32) == 'NEW_PUBLISHER', 'wrong publisher address');
}

#[test]
fn test_re_register_fail() {
    let publisher_registry_address = deploy_publisher_registry();

    start_prank(admin_address, publisher_registry_address).unwrap();

    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(publisher);
    invoke_calldata.append(222);

    match invoke(publisher_registry_address, 'add_publisher', @invoke_calldata) {
        Result::Ok(x) => assert(false, 'Shouldnt have succeeded'),
        Result::Err(x) => {
            assert(x.first() == 'Name already registered', 'first datum doesnt match');
        }
    }

    let mut calldata = ArrayTrait::new();
    calldata.append(publisher);
    let return_data1 = call(publisher_registry_address, 'get_publisher_address', @calldata).unwrap();
    assert(*return_data1.at(0_u32) == publisher_address, 'wrong publisher address');
}

#[test]
fn test_rotate_admin_address() {
    let publisher_registry_address = deploy_publisher_registry();

    start_prank(admin_address, publisher_registry_address).unwrap();

    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(admin_2_address);
    invoke(publisher_registry_address, 'set_admin_address', @invoke_calldata).unwrap();

    stop_prank(publisher_registry_address);
    start_prank(admin_2_address, publisher_registry_address).unwrap();

    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append('NEW_PUBLISHER');
    invoke_calldata.append(222);
    invoke(publisher_registry_address, 'add_publisher', @invoke_calldata).unwrap();

    let mut calldata = ArrayTrait::new();
    calldata.append('NEW_PUBLISHER');
    let return_data2 = call(publisher_registry_address, 'get_publisher_address', @calldata).unwrap();
    assert(*return_data2.at(0_u32) == 222, 'wrong publisher address');
}
