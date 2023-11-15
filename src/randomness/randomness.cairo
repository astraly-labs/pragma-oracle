use starknet::ContractAddress;

#[derive(Serde, Drop, Copy, PartialEq, starknet::Store)]
enum RequestStatus {
    UNINITIALIZED: (),
    RECEIVED: (),
    FULFILLED: (),
    CANCELLED: (),
    EXCESSIVE_GAS_NEEDED: (),
    ERRORED: (),
}

#[starknet::interface]
trait IRandomness<TContractState> {
    fn update_status(
        ref self: TContractState,
        requestor_address: ContractAddress,
        request_id: u64,
        status: RequestStatus
    );
    fn request_random(
        ref self: TContractState,
        seed: u64,
        callback_address: ContractAddress,
        callback_gas_limit: u64,
        publish_delay: u64,
        num_words: u64
    ) -> u64;
    fn cancel_random_request(
        ref self: TContractState,
        request_id: u64,
        requestor_address: ContractAddress,
        seed: u64,
        minimum_block_number: u64,
        callback_address: ContractAddress,
        callback_gas_limit: u64,
        num_words: u64
    );
    fn submit_random(
        ref self: TContractState,
        request_id: u64,
        requestor_address: ContractAddress,
        seed: u64,
        minimum_block_number: u64,
        callback_address: ContractAddress,
        callback_gas_limit: u64,
        random_words: Span<felt252>,
        proof: Span<felt252>,
    );
    fn get_pending_requests(
        self: @TContractState, requestor_address: ContractAddress, offset: u64, max_len: u64
    ) -> Span<felt252>;

    fn get_request_status(
        self: @TContractState, requestor_address: ContractAddress, request_id: u64
    ) -> RequestStatus;
    fn requestor_current_index(self: @TContractState, requestor_address: ContractAddress) -> u64;
    fn get_public_key(self: @TContractState, requestor_address: ContractAddress) -> felt252;
}


#[starknet::contract]
mod Randomness {
    use super::{ContractAddress, IRandomness, RequestStatus};
    use starknet::{get_caller_address};
    use starknet::info::{get_block_number};
    use pragma::randomness::example_randomness::{
        IExampleRandomnessDispatcher, IExampleRandomnessDispatcherTrait
    };
    use pragma::admin::admin::Ownable;
    use poseidon::poseidon_hash_span;

    use array::{ArrayTrait, SpanTrait};
    use traits::{TryInto, Into};
    #[storage]
    struct Storage {
        public_key: felt252,
        request_id: LegacyMap::<ContractAddress, u64>,
        request_hash: LegacyMap::<(ContractAddress, u64), felt252>,
        request_status: LegacyMap::<(ContractAddress, u64), RequestStatus>,
    }

    #[derive(Drop, starknet::Event)]
    struct RandomnessRequest {
        request_id: u64,
        caller_address: ContractAddress,
        seed: u64,
        minimum_block_number: u64,
        callback_address: ContractAddress,
        callback_gas_limit: u64,
        num_words: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct RandomnessProof {
        request_id: u64,
        requestor_address: ContractAddress,
        seed: u64,
        minimum_block_number: u64,
        random_words: Span<felt252>,
        proof: Span<felt252>
    }

    #[derive(Drop, starknet::Event)]
    struct RandomnessStatusChange {
        requestor_address: ContractAddress,
        request_id: u64,
        status: RequestStatus
    }

    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        RandomnessRequest: RandomnessRequest,
        RandomnessProof: RandomnessProof,
        RandomnessStatusChange: RandomnessStatusChange
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress, public_key: felt252) {
        let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref state, admin_address);
        self.public_key.write(public_key);
        return ();
    }

    #[external(v0)]
    impl IRandomnessImpl of IRandomness<ContractState> {
        fn update_status(
            ref self: ContractState,
            requestor_address: ContractAddress,
            request_id: u64,
            status: RequestStatus
        ) {
            assert_only_admin();
            self.request_status.write((requestor_address, request_id), status);
            return ();
        }

        fn request_random(
            ref self: ContractState,
            seed: u64,
            callback_address: ContractAddress,
            callback_gas_limit: u64,
            publish_delay: u64,
            num_words: u64
        ) -> u64 {
            let caller_address = get_caller_address();
            let current_block = get_block_number();
            let request_id = self.request_id.read(caller_address);
            assert(num_words == 1, 'no more than one word');
            let minimum_block_number = current_block + publish_delay;
            let hash_ = hash_request(
                request_id,
                caller_address,
                seed,
                minimum_block_number,
                callback_address,
                callback_gas_limit,
                num_words,
            );
            // hash request
            self.request_hash.write((caller_address, request_id), hash_);
            self
                .emit(
                    Event::RandomnessRequest(
                        RandomnessRequest {
                            request_id,
                            caller_address,
                            seed,
                            minimum_block_number,
                            callback_address,
                            callback_gas_limit,
                            num_words
                        }
                    )
                );
            self.request_status.write((caller_address, request_id), RequestStatus::RECEIVED(()));
            self.request_id.write(caller_address, request_id + 1);
            return (request_id);
        }

        fn cancel_random_request(
            ref self: ContractState,
            request_id: u64,
            requestor_address: ContractAddress,
            seed: u64,
            minimum_block_number: u64,
            callback_address: ContractAddress,
            callback_gas_limit: u64,
            num_words: u64,
        ) {
            let caller_address = get_caller_address();
            let _hashed_value = hash_request(
                request_id,
                requestor_address,
                seed,
                minimum_block_number,
                callback_address,
                callback_gas_limit,
                num_words,
            );
            let stored_hash_ = self.request_hash.read((caller_address, request_id));
            assert(_hashed_value == stored_hash_, 'invalid request configuration');
            assert(requestor_address == caller_address, 'invalid request owner');
            self
                .emit(
                    Event::RandomnessStatusChange(
                        RandomnessStatusChange {
                            requestor_address: requestor_address,
                            request_id: request_id,
                            status: RequestStatus::CANCELLED(())
                        }
                    )
                );
            return ();
        }

        fn submit_random(
            ref self: ContractState,
            request_id: u64,
            requestor_address: ContractAddress,
            seed: u64,
            minimum_block_number: u64,
            callback_address: ContractAddress,
            callback_gas_limit: u64,
            random_words: Span<felt252>,
            proof: Span<felt252>,
        ) {
            assert_only_admin();

            let _hashed_value = hash_request(
                request_id,
                requestor_address,
                seed,
                minimum_block_number,
                callback_address,
                callback_gas_limit,
                random_words.len().into(),
            );
            let stored_hash_ = self.request_hash.read((requestor_address, request_id));
            assert(stored_hash_ == _hashed_value, 'Randomness hash mismatch');

            let example_randomness_dispatcher = IExampleRandomnessDispatcher {
                contract_address: callback_address
            };
            example_randomness_dispatcher
                .receive_random_words(requestor_address, request_id, random_words);
            self
                .request_status
                .write((requestor_address, request_id), RequestStatus::FULFILLED(()));
            self
                .emit(
                    Event::RandomnessStatusChange(
                        RandomnessStatusChange {
                            requestor_address: requestor_address,
                            request_id: request_id,
                            status: RequestStatus::FULFILLED(())
                        }
                    )
                );

            self
                .emit(
                    Event::RandomnessProof(
                        RandomnessProof {
                            request_id: request_id,
                            requestor_address: requestor_address,
                            seed: seed,
                            minimum_block_number: minimum_block_number,
                            random_words: random_words,
                            proof: proof,
                        }
                    )
                );
            return ();
        }


        fn get_pending_requests(
            self: @ContractState, requestor_address: ContractAddress, offset: u64, max_len: u64
        ) -> Span<felt252> {
            let max_index = self.request_id.read(requestor_address);
            let mut requests = ArrayTrait::<felt252>::new();
            allocate_requests(self, 0, offset, max_index, max_len, requestor_address, ref requests);
            return requests.span();
        }

        fn get_request_status(
            self: @ContractState, requestor_address: ContractAddress, request_id: u64
        ) -> RequestStatus {
            let request_status = self.request_status.read((requestor_address, request_id));
            return request_status;
        }


        fn requestor_current_index(
            self: @ContractState, requestor_address: ContractAddress
        ) -> u64 {
            let current_index = self.request_id.read(requestor_address);
            return current_index;
        }


        fn get_public_key(self: @ContractState, requestor_address: ContractAddress) -> felt252 {
            let pub_key_ = self.public_key.read();
            return pub_key_;
        }
    }

    fn hash_request(
        request_id: u64,
        requestor_address: ContractAddress,
        seed: u64,
        minimum_block_number: u64,
        callback_address: ContractAddress,
        callback_gas_limit: u64,
        num_words: u64,
    ) -> felt252 {
        let input = array![
            request_id.into(),
            requestor_address.into(),
            seed.into(),
            minimum_block_number.into(),
            callback_address.into(),
            callback_gas_limit.into(),
            num_words.into()
        ];
        let hash_ = poseidon_hash_span(input.span());
        return hash_;
    }

    fn assert_only_admin() {
        let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        let admin = Ownable::OwnableImpl::owner(@state);
        let caller = get_caller_address();
        assert(caller == admin, 'Admin: unauthorized');
    }

    fn allocate_requests(
        self: @ContractState,
        cur_idx: u64,
        offset: u64,
        max_index: u64,
        max_len: u64,
        requestor_address: ContractAddress,
        ref request_ids: Array<felt252>
    ) {
        if (cur_idx + offset == max_index) {
            return ();
        }
        if (request_ids.len().into() == max_len) {
            return ();
        }

        let status_ = self.request_status.read((requestor_address, cur_idx + offset));

        if (status_ == RequestStatus::UNINITIALIZED(())) {
            return ();
        }

        if (status_ == RequestStatus::RECEIVED(())) {
            request_ids.append((cur_idx + offset).into());
            return allocate_requests(
                self, cur_idx + 1, offset, max_index, max_len, requestor_address, ref request_ids
            );
        } else {
            return allocate_requests(
                self, cur_idx + 1, offset, max_index, max_len, requestor_address, ref request_ids
            );
        }
    }
}

