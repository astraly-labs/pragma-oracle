#[contract]
mod PublisherRegistry {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    
    use publisher_registry::business_logic::interface::IPublisherRegistry;

    struct Storage {
        publisher_address_storage: LegacyMap::<felt252, ContractAddress>,
        publishers_storage_len: usize,
        publishers_storage: LegacyMap::<usize, felt252>,
        publishers_sources: LegacyMap::<(felt252, usize), u256>,
        publishers_sources_idx: LegacyMap::<felt252, usize>,
    }

    #[event]
    fn RegisteredPublisher(publisher: felt252, publisher_address:ContractAddress) {}

    #[event]
    fn UpdatedPublisherAddress(publisher: felt252, old_publisher_address: ContractAddress, new_publisher_address: ContractAddress) {}

    impl PublisherRegistryImpl of IPublisherRegistry {
        fn add_publisher(publisher: felt252, publisher_address: ContractAddress) {
            let existing_publisher_address = get_publisher_address(publisher);

            assert(existing_publisher_address.is_zero(), 'Name already registered');

            let publishers_len = publishers_storage_len::read();

            publishers_storage_len::write(publishers_len + 1);
            publishers_storage::write(publishers_len, publisher);
            publisher_address_storage::write(publisher, publisher_address);

            RegisteredPublisher(publisher, publisher_address);
        }
    }

    //
    // View
    //

    #[view]
    fn get_publisher_address(publisher: felt252) -> ContractAddress {
        publisher_address_storage::read(publisher)
    }

    #[view]
    fn get_all_publishers() -> Array<ContractAddress> {
    }


    // //
    // // Externals
    // //
    // #[external]
    // fn add_publisher(publisher: felt252, publisher_address: ContractAddress) {

    // }

    
}

