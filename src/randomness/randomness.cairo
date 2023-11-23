use starknet::{ContractAddress, ClassHash};

#[derive(Serde, Drop, Copy, PartialEq, starknet::Store)]
enum RequestStatus {
    UNINITIALIZED: (),
    RECEIVED: (),
    FULFILLED: (),
    CANCELLED: (),
    OUT_OF_GAS: (),
}


#[starknet::interface]
trait IRandomness<TContractState> {
    fn update_status(
        ref self: TContractState,
        requestor_address: ContractAddress,
        request_id: u64,
        new_status: RequestStatus
    );
    fn request_random(
        ref self: TContractState,
        seed: u64,
        callback_address: ContractAddress,
        callback_fee_limit: u128,
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
        callback_fee_limit: u128,
        num_words: u64
    );
    fn submit_random(
        ref self: TContractState,
        request_id: u64,
        requestor_address: ContractAddress,
        seed: u64,
        minimum_block_number: u64,
        callback_address: ContractAddress,
        callback_fee_limit: u128,
        callback_fee: u128,
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
    fn get_payment_token(self: @TContractState) -> ContractAddress;
    fn set_payment_token(ref self: TContractState, token_contract: ContractAddress);
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
    fn refund_operation(ref self: TContractState, caller_address: ContractAddress, request_id: u64);
    fn get_total_fees(
        self: @TContractState, caller_address: ContractAddress, request_id: u64
    ) -> u256;
}


#[starknet::contract]
mod Randomness {
    use super::{ContractAddress, IRandomness, RequestStatus, ClassHash};
    use pragma::upgradeable::upgradeable::Upgradeable;
    use starknet::{get_caller_address};
    use starknet::info::{get_block_number};
    use pragma::randomness::example_randomness::{
        IExampleRandomnessDispatcher, IExampleRandomnessDispatcherTrait
    };
    use pragma::entry::structs::DataType;
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use pragma::admin::admin::Ownable;
    use poseidon::poseidon_hash_span;
    use openzeppelin::token::erc20::interface::{
        ERC20CamelABIDispatcher, ERC20CamelABIDispatcherTrait
    };
    use openzeppelin::security::reentrancyguard::ReentrancyGuard;
    use array::{ArrayTrait, SpanTrait};
    use debug::PrintTrait;
    use traits::{TryInto, Into};
    const MAX_PREMIUM_FEE: u128 = 100000000; // 1$ with 8 decimals

    #[storage]
    struct Storage {
        public_key: felt252,
        payment_token: ContractAddress,
        //TODO: Handle fee/payment in future version
        oracle_address: ContractAddress,
        total_fees: LegacyMap::<(ContractAddress, u64), u256>,
        request_id: LegacyMap::<ContractAddress, u64>,
        request_hash: LegacyMap::<(ContractAddress, u64), felt252>,
        request_status: LegacyMap::<(ContractAddress, u64), RequestStatus>,
        number_of_request: LegacyMap::<ContractAddress, u64>,
    }

    #[derive(Drop, starknet::Event)]
    struct RandomnessRequest {
        request_id: u64,
        caller_address: ContractAddress,
        seed: u64,
        minimum_block_number: u64,
        callback_address: ContractAddress,
        callback_fee_limit: u128,
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
    fn constructor(
        ref self: ContractState,
        admin_address: ContractAddress,
        public_key: felt252,
        payment_token_address: ContractAddress,
        oracle_address: ContractAddress,
    ) {
        let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref state, admin_address);
        self.public_key.write(public_key);
        self.payment_token.write(payment_token_address);
        self.oracle_address.write(oracle_address);
        return ();
    }

    #[external(v0)]
    impl IRandomnessImpl of IRandomness<ContractState> {
        fn update_status(
            ref self: ContractState,
            requestor_address: ContractAddress,
            request_id: u64,
            new_status: RequestStatus
        ) {
            assert_only_admin();
            let status = self.request_status.read((requestor_address, request_id));
            //The management is handled by the admin contract, he cannot change the status of a fulfilled or cancelled request
            assert(status != RequestStatus::FULFILLED(()), 'request already fulfilled');
            assert(status != RequestStatus::CANCELLED(()), 'request already cancelled');
            self.request_status.write((requestor_address, request_id), new_status);
            return ();
        }

        fn request_random(
            ref self: ContractState,
            seed: u64,
            callback_address: ContractAddress,
            callback_fee_limit: u128, //the max amount the user can pay for the callback
            publish_delay: u64,
            num_words: u64
        ) -> u64 {
            let mut state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref state);
            let caller_address = get_caller_address();
            let contract_address = starknet::info::get_contract_address();
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
                callback_fee_limit,
                num_words,
            );
            // get the current number of requests for the caller
            let request_number = self.number_of_request.read(caller_address);
            // get the contract dispatcher
            let token_address = self.payment_token.read();
            let token_dispatcher = ERC20CamelABIDispatcher { contract_address: token_address };
            // get the balance of the caller
            let user_balance = token_dispatcher.balanceOf(caller_address);
            // compute the premium fee
            let premium_fee = compute_premium_fee(@self, caller_address);
            let oracle_dispatcher = IOracleABIDispatcher {
                contract_address: self.oracle_address.read()
            };
            let response = oracle_dispatcher.get_data_median(DataType::SpotEntry('ETH/USD'));

            // Convert the premium fee in dollar to wei
            let wei_premium_fee = dollar_to_wei(premium_fee, response.price);
            // Check if the balance is greater than premium fee 
            let total_fee: u256 = wei_premium_fee.into() + callback_fee_limit.into();
            assert(user_balance >= total_fee, 'insufficient balance');
            // transfer the premium fee to the contract
            self.request_hash.write((caller_address, request_id), hash_);
            token_dispatcher.allowance(callback_address, contract_address);
            token_dispatcher.transferFrom(caller_address, contract_address, total_fee);
            self
                .emit(
                    Event::RandomnessRequest(
                        RandomnessRequest {
                            request_id,
                            caller_address,
                            seed,
                            minimum_block_number,
                            callback_address,
                            callback_fee_limit,
                            num_words
                        }
                    )
                );
            self.number_of_request.write(caller_address, request_id + 1);
            self.request_status.write((caller_address, request_id), RequestStatus::RECEIVED(()));
            self.request_id.write(caller_address, request_id + 1);
            self.total_fees.write((caller_address, request_id), total_fee);
            ReentrancyGuard::InternalImpl::end(ref state);
            return (request_id);
        }

        fn cancel_random_request(
            ref self: ContractState,
            request_id: u64,
            requestor_address: ContractAddress,
            seed: u64,
            minimum_block_number: u64,
            callback_address: ContractAddress,
            callback_fee_limit: u128,
            num_words: u64,
        ) {
            let mut state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref state);
            let caller_address = get_caller_address();
            let _hashed_value = hash_request(
                request_id,
                requestor_address,
                seed,
                minimum_block_number,
                callback_address,
                callback_fee_limit,
                num_words,
            );
            let stored_hash_ = self.request_hash.read((caller_address, request_id));
            assert(_hashed_value == stored_hash_, 'invalid request configuration');
            assert(requestor_address == caller_address, 'invalid request owner');
            let status = self.request_status.read((requestor_address, request_id));

            assert(status != RequestStatus::FULFILLED(()), 'request already fulfilled');
            assert(status != RequestStatus::CANCELLED(()), 'request already cancelled');

            let token_address = self.payment_token.read();
            let token_dispatcher = ERC20CamelABIDispatcher { contract_address: token_address };
            let total_fee = self.total_fees.read((requestor_address, request_id));
            self.total_fees.write((requestor_address, request_id), 0);
            token_dispatcher.transfer(requestor_address, total_fee);

            self
                .request_status
                .write((requestor_address, request_id), RequestStatus::CANCELLED(()));
            self
                .request_status
                .write((requestor_address, request_id), RequestStatus::CANCELLED(()));
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
            ReentrancyGuard::InternalImpl::end(ref state);
            return ();
        }

        fn submit_random(
            ref self: ContractState,
            request_id: u64,
            requestor_address: ContractAddress,
            seed: u64,
            minimum_block_number: u64,
            callback_address: ContractAddress,
            callback_fee_limit: u128,
            callback_fee: u128, //the actual fee estimated off chain
            random_words: Span<felt252>,
            proof: Span<felt252>,
        ) {
            let mut state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref state);
            assert_only_admin();
            let status = self.request_status.read((requestor_address, request_id));
            assert(status != RequestStatus::FULFILLED(()), 'request already fulfilled');
            assert(status != RequestStatus::CANCELLED(()), 'request already cancelled');
            let _hashed_value = hash_request(
                request_id,
                requestor_address,
                seed,
                minimum_block_number,
                callback_address,
                callback_fee_limit,
                random_words.len().into(),
            );
            let stored_hash_ = self.request_hash.read((requestor_address, request_id));
            assert(stored_hash_ == _hashed_value, 'Randomness hash mismatch');

            let example_randomness_dispatcher = IExampleRandomnessDispatcher {
                contract_address: callback_address
            };
            example_randomness_dispatcher
                .receive_random_words(requestor_address, request_id, random_words);

            // pay callback_fee_limit - callback_fee
            let token_address = self.payment_token.read();
            let token_dispatcher = ERC20CamelABIDispatcher { contract_address: token_address };
            token_dispatcher.transfer(callback_address, (callback_fee_limit - callback_fee).into());
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
            ReentrancyGuard::InternalImpl::end(ref state);
            return ();
        }

        fn refund_operation(
            ref self: ContractState, caller_address: ContractAddress, request_id: u64
        ) {
            let mut state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref state);
            let total_fees = self.total_fees.read((caller_address, request_id));
            assert(total_fees != 0, 'no due amount');
            let status = self.request_status.read((caller_address, request_id));
            assert(status == RequestStatus::OUT_OF_GAS(()), 'request not out of gas');
            let token_address = self.payment_token.read();
            let token_dispatcher = ERC20CamelABIDispatcher { contract_address: token_address };
            self.total_fees.write((caller_address, request_id), 0);
            token_dispatcher.transfer(caller_address, total_fees);
            ReentrancyGuard::InternalImpl::end(ref state);
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

        fn get_payment_token(self: @ContractState) -> ContractAddress {
            self.payment_token.read()
        }
        fn set_payment_token(ref self: ContractState, token_contract: ContractAddress) {
            assert_only_admin();
            self.payment_token.write(token_contract);
            return ();
        }

        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert_only_admin();
            let mut upstate: Upgradeable::ContractState = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::upgrade(ref upstate, impl_hash);
        }

        fn get_total_fees(
            self: @ContractState, caller_address: ContractAddress, request_id: u64
        ) -> u256 {
            self.total_fees.read((caller_address, request_id))
        }
    }

    fn hash_request(
        request_id: u64,
        requestor_address: ContractAddress,
        seed: u64,
        minimum_block_number: u64,
        callback_address: ContractAddress,
        callback_fee_limit: u128,
        num_words: u64,
    ) -> felt252 {
        let input = array![
            request_id.into(),
            requestor_address.into(),
            seed.into(),
            minimum_block_number.into(),
            callback_address.into(),
            callback_fee_limit.into(),
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

    fn compute_premium_fee(self: @ContractState, caller_address: ContractAddress) -> u128 {
        let request_number = self.number_of_request.read(caller_address);
        if (request_number < 10) {
            MAX_PREMIUM_FEE
        } else if (request_number < 30) {
            MAX_PREMIUM_FEE / 2
        } else if (request_number < 100) {
            MAX_PREMIUM_FEE / 4
        } else {
            MAX_PREMIUM_FEE / 10
        }
    }

    fn dollar_to_wei(usd: u128, price: u128) -> u128 {
        (usd * 1000000000000000000) / price
    }

    fn amount_to_wei(amount: u256, price: u128) -> u256 {
        amount * 1000000000000000000 * price.into() / 100000000
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

