#[contract]
mod PublisherRegistry {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use array::ArrayTrait;
    use array::ArrayTCloneImpl;
    use traits::Into;
    use traits::TryInto;
    use admin::contracts::Admin::Admin;
    
    use publisher_registry::business_logic::interface::IPublisherRegistry;

    struct Storage {
        publisher_address_storage: LegacyMap::<felt252, ContractAddress>,
        publishers_storage_len: usize,
        publishers_storage: LegacyMap::<usize, felt252>,
        publishers_sources: LegacyMap::<(felt252, usize), felt252>,
        publishers_sources_idx: LegacyMap::<felt252, usize>,
    }

    #[constructor]
    fn constructor(admin_address: ContractAddress) {
        Admin::initialize_admin_address(admin_address);
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

        fn update_publisher_address(publisher: felt252, new_publisher_address: ContractAddress) {
            let existing_publisher_address = get_publisher_address(publisher);
            let caller = get_caller_address();

            assert(!existing_publisher_address.is_zero(), 'Name not registered');

            assert(caller == existing_publisher_address, 'Caller is not the publisher');

            publisher_address_storage::write(publisher, new_publisher_address);

            UpdatedPublisherAddress(publisher, existing_publisher_address, new_publisher_address);
        }

        fn remove_publisher(publisher: felt252) {
            publisher_address_storage::write(publisher, Zeroable::zero());
            publishers_sources_idx::write(publisher, 0);
            publishers_sources::write((publisher, 0), 0);

            let publishers_len = publishers_storage_len::read();

            if (publishers_len == 1) {
                publishers_storage_len::write(0);
                publishers_storage::write(0, 0);
                return ();
            }

            let (publisher_idx, found) = _find_publisher_idx(0, publishers_len, publisher);

            assert(found, 'Publisher not found');

            if (publisher_idx == publishers_len - 1) {
                publishers_storage_len::write(publishers_len - 1);
                publishers_storage::write(publishers_len - 1, 0);
            } else {
                let last_publisher = publishers_storage::read(publishers_len - 1);
                publishers_storage::write(publisher_idx, last_publisher);
                publishers_storage::write(publishers_len - 1, 0);
                publishers_storage_len::write(publishers_len - 1);
            }
        }

        fn add_source_for_publisher(publisher: felt252, source: felt252) {
            let existing_publisher_address = get_publisher_address(publisher);
            
            assert(!existing_publisher_address.is_zero(), 'Publisher does not exist');

            let can_publish = can_publish_source(publisher, source);

            assert(can_publish, 'Already registered');

            let cur_idx = publishers_sources_idx::read(publisher);
            publishers_sources::write((publisher, cur_idx), source);
            publishers_sources_idx::write(publisher, cur_idx + 1);
        }

        fn add_sources_for_publisher(publisher: felt252, sources: @Array<felt252>) {
            let mut idx = 0;

            loop {
                if (idx == sources.len()) {
                    break();
                }

                PublisherRegistryImpl::add_source_for_publisher(publisher, *sources[idx]);
                idx += 1;
            }
        }

        fn remove_source_for_publisher(publisher: felt252, source: felt252) {
            let cur_idx = publishers_sources_idx::read(publisher);

            if (cur_idx == 0) {
                return ();
            }

            let mut sources_arr = ArrayTrait::new();
            _iter_publisher_sources(0_usize, cur_idx, publisher, ref sources_arr);

            let (source_idx, found) = _find_source_idx(0_usize, source, @sources_arr);
            assert(found, 'Source not found');

            if (source_idx == cur_idx - 1) {
                publishers_sources_idx::write(publisher, source_idx);
                publishers_sources::write((publisher, source_idx), 0);
            } else {
                let last_source = publishers_sources::read((publisher, cur_idx - 1));
                publishers_sources_idx::write(publisher, cur_idx - 1);
                publishers_sources::write((publisher, cur_idx - 1), 0);
                publishers_sources::write((publisher, source_idx), last_source);
            }
        }
    }

    //
    // View
    //

    #[view]
    fn get_admin_address() -> ContractAddress {
        return Admin::get_admin_address();
    }

    #[view]
    fn get_publisher_address(publisher: felt252) -> ContractAddress {
        publisher_address_storage::read(publisher)
    }

    #[view]
    fn get_all_publishers() -> Array<felt252> {
        let publishers_len = publishers_storage_len::read();
        let mut publishers = ArrayTrait::new();

        _build_array(0_usize, publishers_len, ref publishers);

        publishers
    }

    #[view]
    fn can_publish_source(publisher: felt252, source: felt252) -> bool {
        let cur_idx = publishers_sources_idx::read(publisher);

        if (cur_idx == 0) {
            return true;
        }

        let mut sources_arr = ArrayTrait::new();
        
        _iter_publisher_sources(0_usize, cur_idx, publisher, ref sources_arr);

        let (_, found) = _find_source_idx(0_usize, source, @sources_arr);

        found
    }


    //
    // Externals
    //

    #[external]
    fn add_publisher(publisher: felt252, publisher_address: ContractAddress) {
        Admin::assert_only_admin();
        PublisherRegistryImpl::add_publisher(publisher, publisher_address)
    }

    #[external]
    fn remove_publisher(publisher: felt252) {
        Admin::assert_only_admin();
        PublisherRegistryImpl::remove_publisher(publisher)
    }

    #[external]
    fn update_publisher_address(publisher: felt252, new_publisher_address: ContractAddress) {
        PublisherRegistryImpl::update_publisher_address(publisher, new_publisher_address)
    }

    #[external]
    fn add_source_for_publisher(publisher: felt252, source: felt252) {
        Admin::assert_only_admin();
        PublisherRegistryImpl::add_source_for_publisher(publisher, source)
    }

    #[external]
    fn add_sources_for_publisher(publisher: felt252, sources: Array<felt252>) {
        Admin::assert_only_admin();
        PublisherRegistryImpl::add_sources_for_publisher(publisher, @sources)
    }

    #[external]
    fn remove_source_for_publisher(publisher: felt252, source: felt252) {
        Admin::assert_only_admin();
        PublisherRegistryImpl::remove_source_for_publisher(publisher, source)
    }

    #[external]
    fn set_admin_address(new_admin_address: ContractAddress) {
        Admin::assert_only_admin();
        Admin::set_admin_address(new_admin_address);
    }

    //
    // Internals
    //

    fn _build_array(index: usize, len: usize, ref publishers: Array<felt252>) {
        if index >= len {
            return ();
        }

        let publisher = publishers_storage::read(index);
        publishers.append(publisher);

        gas::withdraw_gas_all(get_builtin_costs()).expect('Out of gas');
        _build_array(index + 1_usize, len, ref publishers);
    }

    fn _find_publisher_idx(cur_idx: usize, max_idx: usize, publisher: felt252) -> (usize, bool) {
        if cur_idx == max_idx {
            return (0, false);
        }

        let current_publisher = publishers_storage::read(cur_idx);

        if (current_publisher == publisher) {
            return (cur_idx, true);
        }

        gas::withdraw_gas_all(get_builtin_costs()).expect('Out of gas');
        _find_publisher_idx(cur_idx + 1_usize, max_idx, publisher)
    }   

    fn _find_source_idx(cur_idx: usize, source: felt252, sources_arr: @Array<felt252>) -> (usize, bool) {
        if cur_idx == sources_arr.len() {
            return (0, false);
        }

        if (*sources_arr[cur_idx] == source) {
            return (cur_idx, true);
        }

        gas::withdraw_gas_all(get_builtin_costs()).expect('Out of gas');
        _find_source_idx(cur_idx + 1_usize, source, sources_arr)
    }

    fn _iter_publisher_sources(cur_idx: usize, max_idx: usize, publisher: felt252, ref sources_arr: Array<felt252>) {
        if cur_idx == max_idx {
            return ();
        }

        let source = publishers_sources::read((publisher, cur_idx));

        sources_arr.append(source);

        gas::withdraw_gas_all(get_builtin_costs()).expect('Out of gas');
        _iter_publisher_sources(cur_idx + 1_usize, max_idx, publisher, ref sources_arr)
    }
}

