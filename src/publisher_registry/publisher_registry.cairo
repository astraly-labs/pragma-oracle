use starknet::ContractAddress;


#[starknet::interface]
trait IPublisherRegistryABI<TContractState> {
    fn add_publisher(
        ref self: TContractState, publisher: felt252, publisher_address: ContractAddress
    );
    fn update_publisher_address(
        ref self: TContractState, publisher: felt252, new_publisher_address: ContractAddress
    );
    fn remove_publisher(ref self: TContractState, publisher: felt252);
    fn add_source_for_publisher(ref self: TContractState, publisher: felt252, source: felt252);
    fn add_sources_for_publisher(
        ref self: TContractState, publisher: felt252, sources: Span<felt252>
    );
    fn remove_source_for_publisher(ref self: TContractState, publisher: felt252, source: felt252);
    fn can_publish_source(self: @TContractState, publisher: felt252, source: felt252) -> bool;
    fn get_publisher_address(self: @TContractState, publisher: felt252) -> ContractAddress;
    fn set_admin_address(ref self: TContractState, new_admin_address: ContractAddress);
    fn get_admin_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod PublisherRegistry {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use box::BoxTrait;
    use array::{ArrayTrait, SpanTrait};
    use serde::Serde;
    use traits::Into;
    use traits::TryInto;
    use pragma::admin::admin::Admin;
    use super::IPublisherRegistryABI;
    use debug::PrintTrait;

    #[storage]
    struct Storage {
        publisher_address_storage: LegacyMap::<felt252, ContractAddress>,
        publishers_storage_len: usize,
        publishers_storage: LegacyMap::<usize, felt252>,
        publishers_sources: LegacyMap::<(felt252, usize), felt252>,
        publishers_sources_idx: LegacyMap::<felt252, usize>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
        Admin::initialize_admin_address(ref state, admin_address);
    }


    #[derive(Drop, starknet::Event)]
    struct RegisteredPublisher {
        publisher: felt252,
        publisher_address: ContractAddress
    }


    #[derive(Drop, starknet::Event)]
    struct UpdatedPublisherAddress {
        publisher: felt252,
        old_publisher_address: ContractAddress,
        new_publisher_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        RegisteredPublisher: RegisteredPublisher,
        UpdatedPublisherAddress: UpdatedPublisherAddress,
    }

    #[external(v0)]
    impl PublisherRegistryImpl of IPublisherRegistryABI<ContractState> {
        fn add_publisher(
            ref self: ContractState, publisher: felt252, publisher_address: ContractAddress
        ) {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let existing_publisher_address = PublisherRegistryImpl::get_publisher_address(
                @self, publisher
            );

            assert(existing_publisher_address.is_zero(), 'Name already registered');

            let publishers_len = self.publishers_storage_len.read();

            self.publishers_storage_len.write(publishers_len + 1);
            self.publishers_storage.write(publishers_len, publisher);
            self.publisher_address_storage.write(publisher, publisher_address);

            self
                .emit(
                    Event::RegisteredPublisher(RegisteredPublisher { publisher, publisher_address })
                );
        }

        fn update_publisher_address(
            ref self: ContractState, publisher: felt252, new_publisher_address: ContractAddress
        ) {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let existing_publisher_address = PublisherRegistryImpl::get_publisher_address(
                @self, publisher
            );
            let caller = get_caller_address();

            assert(!existing_publisher_address.is_zero(), 'Name not registered');

            assert(caller == existing_publisher_address, 'Caller is not the publisher');

            self.publisher_address_storage.write(publisher, new_publisher_address);

            self
                .emit(
                    Event::UpdatedPublisherAddress(
                        UpdatedPublisherAddress {
                            publisher,
                            old_publisher_address: existing_publisher_address,
                            new_publisher_address
                        }
                    )
                );
        }

        fn remove_publisher(ref self: ContractState, publisher: felt252) {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let not_exists: bool = self.publisher_address_storage.read(publisher).is_zero();
            assert(!not_exists, 'Publisher not found');
            self.publisher_address_storage.write(publisher, Zeroable::zero());

            self.publishers_sources_idx.write(publisher, 0);
            self.publishers_sources.write((publisher, 0), 0);

            let publishers_len = self.publishers_storage_len.read();

            if (publishers_len == 1) {
                self.publishers_storage_len.write(0);
                self.publishers_storage.write(0, 0);
                return ();
            }

            let (publisher_idx, found) = _find_publisher_idx(@self, 0, publishers_len, publisher);

            assert(found, 'Publisher not found');

            if (publisher_idx == publishers_len - 1) {
                self.publishers_storage_len.write(publishers_len - 1);
                self.publishers_storage.write(publishers_len - 1, 0);
            } else {
                let last_publisher = self.publishers_storage.read(publishers_len - 1);
                self.publishers_storage.write(publisher_idx, last_publisher);
                self.publishers_storage.write(publishers_len - 1, 0);
                self.publishers_storage_len.write(publishers_len - 1);
            }
        }

        fn add_source_for_publisher(ref self: ContractState, publisher: felt252, source: felt252) {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let existing_publisher_address = PublisherRegistryImpl::get_publisher_address(
                @self, publisher
            );
            assert(!existing_publisher_address.is_zero(), 'Publisher does not exist');
            let cur_idx = self.publishers_sources_idx.read(publisher);
            if (cur_idx == 0) {
                self.publishers_sources.write((publisher, 0), source);
                self.publishers_sources_idx.write(publisher, 1);
                return ();
            } else {
                let can_publish = PublisherRegistryImpl::can_publish_source(
                    @self, publisher, source
                );
                assert(can_publish == false, 'Already registered');
                let cur_idx = self.publishers_sources_idx.read(publisher);
                self.publishers_sources.write((publisher, cur_idx), source);
                self.publishers_sources_idx.write(publisher, cur_idx + 1);
                return ();
            }
        }

        fn add_sources_for_publisher(
            ref self: ContractState, publisher: felt252, sources: Span<felt252>
        ) {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let mut idx: u32 = 0;

            loop {
                if (idx == sources.len()) {
                    break ();
                }
                let source: felt252 = *sources.get(idx).unwrap().unbox();
                PublisherRegistryImpl::add_source_for_publisher(ref self, publisher, source);
                idx += 1;
            }
        }

        fn remove_source_for_publisher(
            ref self: ContractState, publisher: felt252, source: felt252
        ) {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let cur_idx = self.publishers_sources_idx.read(publisher);

            if (cur_idx == 0) {
                return ();
            }

            let mut sources_arr = ArrayTrait::new();
            _iter_publisher_sources(@self, 0_usize, cur_idx, publisher, ref sources_arr);

            let (source_idx, found) = _find_source_idx(0_usize, source, @sources_arr);
            assert(found, 'Source not found');

            if (source_idx == cur_idx - 1) {
                self.publishers_sources_idx.write(publisher, source_idx);
                self.publishers_sources.write((publisher, source_idx), 0);
            } else {
                let last_source = self.publishers_sources.read((publisher, cur_idx - 1));
                self.publishers_sources_idx.write(publisher, cur_idx - 1);
                self.publishers_sources.write((publisher, cur_idx - 1), 0);
                self.publishers_sources.write((publisher, source_idx), last_source);
            }
        }
        fn can_publish_source(self: @ContractState, publisher: felt252, source: felt252) -> bool {
            let cur_idx = self.publishers_sources_idx.read(publisher);
            if (cur_idx == 0) {
                return true;
            }

            let mut sources_arr = ArrayTrait::new();

            _iter_publisher_sources(self, 0_usize, cur_idx, publisher, ref sources_arr);

            let (_, found) = _find_source_idx(0_usize, source, @sources_arr);
            found
        }
        fn get_publisher_address(self: @ContractState, publisher: felt252) -> ContractAddress {
            self.publisher_address_storage.read(publisher)
        }

        fn set_admin_address(ref self: ContractState, new_admin_address: ContractAddress) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let old_admin = Admin::get_admin_address(@state);
            assert(new_admin_address != old_admin, 'Same admin address');
            assert(!new_admin_address.is_zero(), 'Admin address cannot be zero');
            Admin::set_admin_address(ref state, new_admin_address);
        }
        fn get_admin_address(self: @ContractState) -> ContractAddress {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            let res = Admin::get_admin_address(@state);
            res
        }
    }


    fn get_all_publishers(self: @ContractState) -> Array<felt252> {
        let publishers_len = self.publishers_storage_len.read();
        let mut publishers = ArrayTrait::new();

        _build_array(self, 0_usize, publishers_len, ref publishers);

        publishers
    }


    //
    // Internals
    //

    fn _build_array(
        self: @ContractState, index: usize, len: usize, ref publishers: Array<felt252>
    ) {
        if index >= len {
            return ();
        }

        let publisher = self.publishers_storage.read(index);
        publishers.append(publisher);

        // gas::withdraw_gas_all(get_builtin_costs()).expect('Out of gas');
        _build_array(self, index + 1_usize, len, ref publishers);
    }

    fn _find_publisher_idx(
        self: @ContractState, cur_idx: usize, max_idx: usize, publisher: felt252
    ) -> (usize, bool) {
        if cur_idx == max_idx {
            return (0, false);
        }

        let current_publisher = self.publishers_storage.read(cur_idx);

        if (current_publisher == publisher) {
            return (cur_idx, true);
        }

        // gas::withdraw_gas_all(get_builtin_costs()).expect('Out of gas');
        _find_publisher_idx(self, cur_idx + 1_usize, max_idx, publisher)
    }

    fn _find_source_idx(
        cur_idx: usize, source: felt252, sources_arr: @Array<felt252>
    ) -> (usize, bool) {
        if cur_idx == sources_arr.len() {
            return (0, false);
        }

        if (*sources_arr[cur_idx] == source) {
            return (cur_idx, true);
        }

        // gas::withdraw_gas_all(get_builtin_costs()).expect('Out of gas');
        _find_source_idx(cur_idx + 1_usize, source, sources_arr)
    }

    fn _iter_publisher_sources(
        self: @ContractState,
        cur_idx: usize,
        max_idx: usize,
        publisher: felt252,
        ref sources_arr: Array<felt252>
    ) {
        if cur_idx == max_idx {
            return ();
        }

        let source = self.publishers_sources.read((publisher, cur_idx));
        sources_arr.append(source);

        // gas::withdraw_gas_all(get_builtin_costs()).expect('Out of gas');
        _iter_publisher_sources(self, cur_idx + 1_usize, max_idx, publisher, ref sources_arr)
    }
}

