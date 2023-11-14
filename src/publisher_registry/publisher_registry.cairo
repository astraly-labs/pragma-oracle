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
    fn remove_source_for_all_publishers(ref self: TContractState, source: felt252);

    fn can_publish_source(self: @TContractState, publisher: felt252, source: felt252) -> bool;
    fn get_publisher_address(self: @TContractState, publisher: felt252) -> ContractAddress;
    fn set_admin_address(ref self: TContractState, new_admin_address: ContractAddress);
    fn get_admin_address(self: @TContractState) -> ContractAddress;
    fn get_all_publishers(self: @TContractState) -> Array<felt252>;
    fn get_publisher_sources(self: @TContractState, publisher: felt252) -> Array<felt252>;
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
    use pragma::admin::admin::Ownable;
    use super::IPublisherRegistryABI;

    #[storage]
    struct Storage {
        // publisher address storage : legacyMap between a publisher and its address( ContractAddress)
        publisher_address_storage: LegacyMap::<felt252, ContractAddress>,
        // len of the publishers storage list
        publishers_storage_len: usize,
        // publisher list : legacyMap between an index and the publisher (felt252)
        publishers_storage: LegacyMap::<usize, felt252>,
        // list of sources associated to a publisher, legacyMap between a publisher, its index and the source
        publishers_sources: LegacyMap::<(felt252, usize), felt252>,
        // len of the publishers sources list
        publishers_sources_idx: LegacyMap::<felt252, usize>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref state, admin_address);
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
    struct RemovedPublisher {
        publisher: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferOwnership {
        old_address: ContractAddress,
        new_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct DeletedSource {
        source: felt252,
    }

    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        RegisteredPublisher: RegisteredPublisher,
        UpdatedPublisherAddress: UpdatedPublisherAddress,
        RemovedPublisher: RemovedPublisher,
        TransferOwnership: TransferOwnership,
        DeletedSource: DeletedSource
    }


    #[external(v0)]
    impl PublisherRegistryImpl of IPublisherRegistryABI<ContractState> {
        // @notice add a publisher to the registry 
        // @dev can be called only by admin
        // @param publisher: the publisher that needs to be added 
        // @param publisher_address: the address associated with the given publisher 
        fn add_publisher(
            ref self: ContractState, publisher: felt252, publisher_address: ContractAddress
        ) {
            assert_only_admin();
            let existing_publisher_address = PublisherRegistryImpl::get_publisher_address(
                @self, publisher
            );
            assert(!is_address_registered(@self, publisher_address), 'Address already registered');
            assert(existing_publisher_address.is_zero(), 'Name already registered');
            assert(!publisher_address.is_zero(), 'Cannot set address to zero');
            let publishers_len = self.publishers_storage_len.read();

            self.publishers_storage_len.write(publishers_len + 1);
            self.publishers_storage.write(publishers_len, publisher);
            self.publisher_address_storage.write(publisher, publisher_address);

            self
                .emit(
                    Event::RegisteredPublisher(RegisteredPublisher { publisher, publisher_address })
                );
        }


        // @notice update the publisher address
        // @param publisher: the publisher whose address needs to be updated
        // @param  new_publisher_address the new publisher address
        fn update_publisher_address(
            ref self: ContractState, publisher: felt252, new_publisher_address: ContractAddress
        ) {
            let existing_publisher_address = PublisherRegistryImpl::get_publisher_address(
                @self, publisher
            );
            let caller = get_caller_address();
            assert(
                !is_address_registered(@self, new_publisher_address), 'Address already registered'
            );
            assert(!existing_publisher_address.is_zero(), 'Name not registered');

            assert(caller == existing_publisher_address, 'Caller is not the publisher');
            assert(!new_publisher_address.is_zero(), 'Publishr address cannot be zero');
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

        // @notice remove a given publisher
        // @param publisher : the publisher that needs to be removed
        fn remove_publisher(ref self: ContractState, publisher: felt252) {
            assert_only_admin();
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
            self.emit(Event::RemovedPublisher(RemovedPublisher { publisher, }));
        }

        // @notice add source for publisher
        // @param: the publisher for which we need to add a source
        // @param: the source that needs to be added for the given publisher
        fn add_source_for_publisher(ref self: ContractState, publisher: felt252, source: felt252) {
            assert_only_admin();
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
                self.publishers_sources.write((publisher, cur_idx), source);
                self.publishers_sources_idx.write(publisher, cur_idx + 1);
                return ();
            }
        }

        // @notice add multiple sources for a publisher 
        // @param the publisher for which sources needs to be added 
        // @param a span of sources that needs to be added for the given publisher
        fn add_sources_for_publisher(
            ref self: ContractState, publisher: felt252, sources: Span<felt252>
        ) {
            assert_only_admin();
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

        // @notice remove a source for a given publisher
        // @dev can be called only by the admin
        // @param  the publisher for which a source needs to be removed 
        // @param source : the source that needs to be removed for the publisher
        fn remove_source_for_publisher(
            ref self: ContractState, publisher: felt252, source: felt252
        ) {
            assert_only_admin();
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
            self.emit(Event::DeletedSource(DeletedSource { source, }));
        }

        // @notice remove a given source for all the publishers
        // @dev can be called only by admin
        // @param source the source to consider
        fn remove_source_for_all_publishers(ref self: ContractState, source: felt252) {
            let mut publishers = IPublisherRegistryABI::get_all_publishers(@self);
            assert_only_admin();
            loop {
                match publishers.pop_front() {
                    Option::Some(publisher) => {
                        IPublisherRegistryABI::remove_source_for_publisher(
                            ref self, publisher, source
                        );
                    },
                    Option::None(_) => {
                        break ();
                    }
                };
            };
            self.emit(Event::DeletedSource(DeletedSource { source, }));
        }

        // @notice checks whether a publisher can publish for a certain source or not 
        // @param the publisher to be checked
        // @param the source to be checked 
        // @returns a boolean on whether the publisher can publish for the source or not
        fn can_publish_source(self: @ContractState, publisher: felt252, source: felt252) -> bool {
            let cur_idx = self.publishers_sources_idx.read(publisher);
            if (cur_idx == 0) {
                return false;
            }

            let mut sources_arr = ArrayTrait::new();

            _iter_publisher_sources(self, 0_usize, cur_idx, publisher, ref sources_arr);

            let (_, found) = _find_source_idx(0_usize, source, @sources_arr);
            found
        }

        // @notice  get the publisher address
        // @param the publisher from which we want to retrieve the address
        // @returns the address associated to the given publisher 
        fn get_publisher_address(self: @ContractState, publisher: felt252) -> ContractAddress {
            self.publisher_address_storage.read(publisher)
        }

        // @notice set an admin address
        // @param new_admin_address: the new admin address
        fn set_admin_address(ref self: ContractState, new_admin_address: ContractAddress) {
            let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::assert_only_owner(@state);
            let old_admin = Ownable::OwnableImpl::owner(@state);
            assert(new_admin_address != old_admin, 'Same admin address');
            assert(!new_admin_address.is_zero(), 'Admin address cannot be zero');
            Ownable::OwnableImpl::transfer_ownership(ref state, new_admin_address);
            self
                .emit(
                    Event::TransferOwnership(
                        TransferOwnership { old_address: old_admin, new_address: new_admin_address }
                    )
                );
        }

        // @notice get the current admin address
        // @returns the admin address
        fn get_admin_address(self: @ContractState) -> ContractAddress {
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            let res = Ownable::OwnableImpl::owner(@state);
            res
        }

        // @notice retrieve all the publishers
        // @returns an array of publishers
        fn get_all_publishers(self: @ContractState) -> Array<felt252> {
            let publishers_len = self.publishers_storage_len.read();
            let mut publishers = ArrayTrait::new();

            _build_array(self, 0_usize, publishers_len, ref publishers);

            publishers
        }


        // @notice retrieve all the allowed sources for a given publisher
        // @param publisher : the publisher
        // @returns an array of sources
        fn get_publisher_sources(self: @ContractState, publisher: felt252) -> Array<felt252> {
            let cur_idx = self.publishers_sources_idx.read(publisher);
            if (cur_idx == 0) {
                return array![];
            }

            let mut sources = ArrayTrait::new();
            _iter_publisher_sources(self, 0_usize, cur_idx, publisher, ref sources);

            sources
        }
    }

    //
    // Internals
    //

    // @notice Check if the caller is the admin, use the contract Admin
    // @dev internal function, fails if not called by the admin
    fn assert_only_admin() {
        let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        let admin = Ownable::OwnableImpl::owner(@state);
        let caller = get_caller_address();
        assert(caller == admin, 'Admin: unauthorized');
    }


    // @notice retrieve all the publishers 
    // @dev recursive function 
    // @param index : current input index, should be set to 0 
    // @param len : the total number of publishers
    // @param publishers : a reference to an array of publishers, to be filled
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


    // @notice find a publisher index, by looking at each publisher in the storage
    // @dev recursive function 
    // @param  cur_idx : the current index, should be set to 0
    // @param max_idx : the total number of publishers
    // @param publisher : the publisher whose index needs to be found  
    // @returns the index of the publisher 
    // @returns whether the publisher is found or not (in order to avoid conflicts, case 0)
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


    // @notice find a source index
    // @dev recursive function 
    // @param  cur_idx : the current index, should be set to 0
    // @param source: the source whose index needs to be found
    // @param an array of sources to work with 
    // @returns the index of the source  
    // @returns whether the source is found or not (in order to avoid conflicts, case 0)
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

    // @notice generate an array of sources from the storage for a given publisher
    // @dev recursive function
    // @param cur_idx : should be set to 0 
    // @param max_idx : the total number of sources for a publisher
    // @param publisher: the publisher to work with 
    // @param sources_arr : an reference to an array of sources, to be filled
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

    // @notice check if a given contract address is already associated to a publisher 
    // @param address: address to check
    // @returns a boolean 
    fn is_address_registered(self: @ContractState, address: ContractAddress) -> bool {
        let mut cur_idx = 0;
        let arr_len = self.publishers_storage_len.read();
        let mut boolean = false;
        loop {
            if (cur_idx == arr_len) {
                break ();
            }
            let publisher = self.publishers_storage.read(cur_idx);
            let publisher_address = self.publisher_address_storage.read(publisher);
            if (publisher_address == address) {
                boolean = true;
                break ();
            }
            cur_idx += 1;
        };
        boolean
    }
}

