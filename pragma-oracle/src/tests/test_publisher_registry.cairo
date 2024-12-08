use array::ArrayTrait;
use result::ResultTrait;
use starknet::ClassHash;
use traits::TryInto;
use traits::Into;
use option::OptionTrait;
use starknet::{get_caller_address, ContractAddress};
use starknet::SyscallResultTrait;
use starknet::contract_address::contract_address_const;
use pragma::publisher_registry::publisher_registry::{
    IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
};
use pragma::publisher_registry::publisher_registry::PublisherRegistry;
use snforge_std::{BlockId, declare, ContractClassTrait, ContractClass, start_prank, stop_prank};


fn admin() -> ContractAddress {
    contract_address_const::<0x12345>()
}

fn deploy_publisher_registry() -> IPublisherRegistryABIDispatcher {
    let mut constructor_calldata: Array<felt252> = ArrayTrait::new();

    constructor_calldata.append(admin().into());
    let publisher_registry_class = declare('PublisherRegistry');
    let publisher_registry_address = publisher_registry_class
        .deploy(@constructor_calldata)
        .unwrap();
    let mut publisher_registry = IPublisherRegistryABIDispatcher {
        contract_address: publisher_registry_address
    };

    start_prank(publisher_registry_address, admin());

    // Add publisher
    let publisher_address = contract_address_const::<0x54321>();
    publisher_registry.add_publisher(1, publisher_address);

    publisher_registry.add_source_for_publisher(1, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(1, 2);

    stop_prank(publisher_registry_address);
    publisher_registry
}
#[test]
#[should_panic]
fn test_register_non_admin_fail() {
    let publisher_registry = deploy_publisher_registry();

    let joe = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, joe);

    let test_add = contract_address_const::<0x1111111>();
    publisher_registry.add_publisher(1, test_add);
}

#[test]
fn test_add_publisher() {
    let publisher_registry = deploy_publisher_registry();
    let test_add = contract_address_const::<0x111222>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.add_publisher(2, test_add);
    assert(publisher_registry.get_publisher_address(2) == test_add, 'wrong publisher address');
}

#[test]
fn test_update_publisher_address() {
    let publisher_registry = deploy_publisher_registry();
    let test_add = contract_address_const::<0x101202>();

    let publisher_address = contract_address_const::<0x54321>();
    start_prank(publisher_registry.contract_address, publisher_address);

    publisher_registry.update_publisher_address(1, test_add);

    assert(publisher_registry.get_publisher_address(1) == test_add, 'wrong publisher address');
}

#[test]
#[should_panic]
fn test_update_publisher_should_fail_if_not_publisher() {
    let publisher_registry = deploy_publisher_registry();
    let test_add = contract_address_const::<0x101202>();

    let joe = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, joe);

    publisher_registry.update_publisher_address(1, test_add);
}

#[test]
#[should_panic]
fn test_add_source_should_fail_if_source_already_exists() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.add_source_for_publisher(1, 1);
}


#[test]
#[should_panic]
fn test_add_source_should_fail_if_not_admin() {
    let publisher_registry = deploy_publisher_registry();
    let joe = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, joe);
    publisher_registry.add_source_for_publisher(1, 3);
}

#[test]
fn test_add_source() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.add_source_for_publisher(1, 3);
    assert(publisher_registry.can_publish_source(1, 3), 'should publish source');
}

#[test]
#[should_panic]
fn test_remove_source_should_fail_if_not_admin() {
    let publisher_registry = deploy_publisher_registry();
    let joe = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, joe);
    publisher_registry.remove_source_for_publisher(1, 1);
}

#[test]
#[should_panic]
fn test_remove_source_should_fail_if_source_does_not_exist() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.remove_source_for_publisher(1, 3);
}


#[test]
fn test_remove_source() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.remove_source_for_publisher(1, 2);
    assert(!publisher_registry.can_publish_source(1, 2), 'should not publish source');
}

#[test]
#[should_panic]
fn test_remove_publisher_should_fail_if_not_admin() {
    let publisher_registry = deploy_publisher_registry();
    let joe = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, joe);
    publisher_registry.remove_publisher(1);
}

#[test]
fn test_remove_publisher() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.remove_publisher(1);
    assert(
        publisher_registry.get_publisher_address(1) == 0.try_into().unwrap(),
        'should not be publisher'
    );
}

#[test]
#[should_panic]
fn test_remove_publisher_should_fail_if_publisher_does_not_exist() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.remove_publisher(2);
}


#[test]
#[should_panic]
fn test_add_publisher_should_fail_if_not_admin() {
    let publisher_registry = deploy_publisher_registry();
    let joe = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, joe);
    publisher_registry.add_publisher(2, contract_address_const::<0x12345>());
}

#[test]
#[should_panic(expected: ('Cannot set address to zero',))]
#[available_gas(2000000000)]
fn test_add_publisher_should_fail_if_null_address() {
    let publisher_registry = deploy_publisher_registry();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.add_publisher(2, 0.try_into().unwrap());
}

#[test]
#[should_panic]
fn test_add_publisher_should_fail_if_publisher_already_exists() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.add_publisher(1, admin_address);
}

#[test]
fn test_change_admin() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    let admin_2_address = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.set_admin_address(admin_2_address);
    let new_address = publisher_registry.get_admin_address();
    assert(new_address == admin_2_address, 'should change admin address');
}

#[test]
#[should_panic]
fn test_change_admin_should_fail_if_not_admin() {
    let publisher_registry = deploy_publisher_registry();
    let joe = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, joe);
    publisher_registry.set_admin_address(joe);
}

#[test]
#[should_panic]
fn test_change_admin_should_fail_if_admin_is_zero() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.set_admin_address(0.try_into().unwrap());
}

#[test]
#[should_panic]
fn test_change_admin_should_fail_if_admin_is_same_as_current_admin() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.set_admin_address(admin_address);
}

#[test]
#[should_panic]
fn test_change_admin_should_fail_if_admin_is_same_as_current_admin_2() {
    let publisher_registry = deploy_publisher_registry();
    let admin_address = contract_address_const::<0x12345>();
    let admin_2_address = contract_address_const::<0x98765>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.set_admin_address(admin_2_address);
    publisher_registry.set_admin_address(admin_2_address);
}


#[test]
#[available_gas(20000000000000)]
fn test_transfer_ownership() {
    let publisher_registry = deploy_publisher_registry();
    let test_address = contract_address_const::<0x1234567>();
    start_prank(publisher_registry.contract_address, admin());
    let admin_address = publisher_registry.get_admin_address();
    assert(admin_address == admin(), 'wrong admin address');
    publisher_registry.set_admin_address(test_address);
    let admin_address = publisher_registry.get_admin_address();
    assert(admin_address == test_address, 'wrong admin address');
}

#[test]
#[available_gas(2000000000)]
fn test_remove_source_for_all_publishers() {
    let publisher_registry = deploy_publisher_registry();
    let publisher_address = contract_address_const::<0x543021>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.add_publisher(2, publisher_address);

    publisher_registry.add_source_for_publisher(2, 1);
    // Add source 2 for publisher 1
    publisher_registry.add_source_for_publisher(2, 2);
    //Add a new source to both publishers
    publisher_registry.add_source_for_publisher(2, 3);
    publisher_registry.add_source_for_publisher(1, 3);
    let sources_1 = publisher_registry.get_publisher_sources(1);
    let sources_2 = publisher_registry.get_publisher_sources(2);
    assert(sources_1.len() == 3, 'Source not added');
    assert(sources_2.len() == 3, 'Source not added');
    publisher_registry.remove_source_for_all_publishers(3);
    let sources_1 = publisher_registry.get_publisher_sources(1);
    let sources_2 = publisher_registry.get_publisher_sources(2);
    assert(sources_1.len() == 2, 'Source not deleted');
    assert(sources_2.len() == 2, 'Source not deleted');
}

#[test]
#[should_panic(expected: ('Address already registered',))]
#[available_gas(20000000000)]
fn test_add_pubisher_should_fail_if_already_registered() {
    let publisher_registry = deploy_publisher_registry();
    let publisher_address = contract_address_const::<0x54321>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.add_publisher(1, publisher_address);
    publisher_registry.add_publisher(2, publisher_address);
}


#[test]
#[should_panic(expected: ('Address already registered',))]
#[available_gas(20000000000)]
fn test_update_pubisher_should_fail_if_already_registered() {
    let publisher_registry = deploy_publisher_registry();
    let publisher_address = contract_address_const::<0x54321>();
    start_prank(publisher_registry.contract_address, admin());
    publisher_registry.add_publisher(1, publisher_address);
    let new_publisher_address = contract_address_const::<0x54322>();
    publisher_registry.add_publisher(2, new_publisher_address);
    publisher_registry.update_publisher_address(2, publisher_address);
}
