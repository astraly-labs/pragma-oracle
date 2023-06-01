use array::ArrayTrait;
use result::ResultTrait;

const admin_address: felt252 = 123;
const publisher_address: felt252 = 456;
const publisher: felt252 = 'TEST_PUBLISHER';

fn deploy_publisher_registry() -> felt252 {
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(admin_address);
    let publisher_registry_address = deploy_contract('publisher_registry', @constructor_calldata).unwrap();
    publisher_registry_address
}

#[test]
fn test_register_non_admin_fail() {
    let publisher_registry_address = deploy_publisher_registry();

    start_prank(admin_address, publisher_registry_address).unwrap();

    let mut invoke_calldata = ArrayTrait::new();
    invoke_calldata.append(publisher);
    invoke_calldata.append(publisher_address);
    invoke(publisher_registry_address, 'add_publisher', @invoke_calldata).unwrap();
}
