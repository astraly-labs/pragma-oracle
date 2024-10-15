use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug)]
struct PoolInfo {
    name: felt252,
    symbol: felt252,
    address: ContractAddress,
    decimals: u8,
    total_supply: u256,
}

#[starknet::interface]
trait IPool<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn token_0(self: @TContractState) -> ContractAddress;
    fn token_1(self: @TContractState) -> ContractAddress;
    fn get_reserves(self: @TContractState) -> (u256, u256);
}

#[starknet::interface]
trait ILpPricer<TContractState> {
    /// Prices a pool in USD.
    fn get_usd_price(self: @TContractState, pool_address: ContractAddress) -> u128;

    /// Register a pool into the supported list.
    fn add_pool(ref self: TContractState, pool_address: ContractAddress);
    /// Removes a pool from the supported list.
    fn remove_pool(ref self: TContractState, pool_address: ContractAddress);
    /// Retrieves information about a Pool, i.e its name, the symbol, the address, the
    /// decimals and the total supply.
    fn get_pool_info(self: @TContractState, pool_address: ContractAddress) -> PoolInfo;
    /// Returns true if the pool is supported, else false.
    fn is_supported_pool(self: @TContractState, pool_address: ContractAddress) -> bool;

    /// Update the admin address.
    fn set_admin_address(ref self: TContractState, new_admin_address: ContractAddress);
    /// Returns the admin address.
    fn get_admin_address(self: @TContractState) -> ContractAddress;
    /// Returns the Pragma Oracle address.
    fn get_oracle_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod LpPricer {
    use starknet::get_caller_address;
    use starknet::{ContractAddress, contract_address_const};
    use zeroable::Zeroable;
    use option::OptionTrait;
    use box::BoxTrait;
    use array::{ArrayTrait, SpanTrait};
    use serde::Serde;
    use traits::Into;
    use traits::TryInto;
    use pragma::admin::admin::Ownable;
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use super::{PoolInfo, ILpPricer, IPoolDispatcher, IPoolDispatcherTrait};

    // ================== ERRORS ==================

    mod errors {
        const NOT_ADMIN: felt252 = 'Caller is not the admin';
        const ZERO_ADDRESS_ADMIN: felt252 = 'New admin is the zero address';
        const ALREADY_ADMIN: felt252 = 'Already admin';
        const POOL_ALREADY_REGISTED: felt252 = 'Pool already registered';
        const UNSUPPORTED_POOL: felt252 = 'Pool not supported';
    }

    // ================== STORAGE ==================

    #[storage]
    struct Storage {
        oracle: IOracleABIDispatcher,
        supported_pools: LegacyMap<ContractAddress, IPoolDispatcher>
    }

    // ================== EVENTS ==================

    #[derive(Drop, starknet::Event)]
    struct RegisteredPool {
        pool_name: felt252,
        pool_symbol: felt252,
        pool_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct RemovedPool {
        pool_name: felt252,
        pool_symbol: felt252,
        pool_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferOwnership {
        old_address: ContractAddress,
        new_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        RegisteredPool: RegisteredPool,
        RemovedPool: RemovedPool,
        TransferOwnership: TransferOwnership,
    }

    // ================== CONSTRUCTOR ================================

    #[constructor]
    fn constructor(
        ref self: ContractState, admin_address: ContractAddress, oracle_address: ContractAddress
    ) {
        let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref state, admin_address);
        let oracle = IOracleABIDispatcher { contract_address: oracle_address };
        self.oracle.write(oracle);
    }

    // ================== PUBLIC ABI ==================

    #[external(v0)]
    impl LpPricerImpl of ILpPricer<ContractState> {
        /// Prices a pool in USD.
        fn get_usd_price(self: @ContractState, pool_address: ContractAddress) -> u128 {
            0
        }

        /// Register a pool into the supported list.
        /// 
        /// Can only be called by the admin.
        fn add_pool(ref self: ContractState, pool_address: ContractAddress) {
            // [Check] Only admin
            assert_only_admin();
            // [Check] Pool is not already registered
            assert(!self.is_supported_pool(pool_address), errors::POOL_ALREADY_REGISTED);

            // [Effect] Add the pool to the storage
            let pool = IPoolDispatcher { contract_address: pool_address };
            self.supported_pools.write(pool_address, pool);

            // [Interaction] Pool registered event
            self
                .emit(
                    Event::RegisteredPool(
                        RegisteredPool {
                            pool_name: pool.name(),
                            pool_symbol: pool.symbol(),
                            pool_address: pool_address,
                        }
                    )
                );
        }

        /// Removes a pool from the supported list.
        /// 
        /// Can only be called by the admin.
        fn remove_pool(ref self: ContractState, pool_address: ContractAddress) {
            // [Check] Only admin
            assert_only_admin();
            // [Check] Pool is registered
            assert(self.is_supported_pool(pool_address), errors::UNSUPPORTED_POOL);

            // [Effect] Remove the Pool contract from the storage
            let pool = self.supported_pools.read(pool_address);
            let zero_pool = IPoolDispatcher { contract_address: contract_address_const::<0>() };
            self.supported_pools.write(pool_address, zero_pool);

            // [Interaction] Pool unregistered event
            self
                .emit(
                    Event::RemovedPool(
                        RemovedPool {
                            pool_name: pool.name(),
                            pool_symbol: pool.symbol(),
                            pool_address: pool_address,
                        }
                    )
                );
        }

        /// Retrieves information about a Pool, i.e its name, the symbol, the address, the
        /// decimals and the total supply.
        fn get_pool_info(self: @ContractState, pool_address: ContractAddress) -> PoolInfo {
            // [Check] Pool is registered
            assert(self.is_supported_pool(pool_address), errors::UNSUPPORTED_POOL);

            // [Effect] Retrieve the pool
            let pool = self.supported_pools.read(pool_address);

            // [Interaction] Return the pool informations
            PoolInfo {
                name: pool.name(),
                symbol: pool.symbol(),
                address: pool.contract_address,
                decimals: pool.decimals(),
                total_supply: pool.total_supply()
            }
        }

        /// Returns true if the pool is supported, else false.
        fn is_supported_pool(self: @ContractState, pool_address: ContractAddress) -> bool {
            // [Interaction] Return if the pool is supported
            !self.supported_pools.read(pool_address).contract_address.is_zero()
        }

        /// Update the admin address.
        /// 
        /// Can only be called by the admin.
        fn set_admin_address(ref self: ContractState, new_admin_address: ContractAddress) {
            // [Check] Only admin
            assert_only_admin();

            let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::assert_only_owner(@state);
            let old_admin = Ownable::OwnableImpl::owner(@state);
            // [Check] New admin is not already registered
            assert(new_admin_address != old_admin, errors::ALREADY_ADMIN);
            // [Check] New admin is not zero
            assert(new_admin_address.is_zero(), errors::ZERO_ADDRESS_ADMIN);

            // [Effect] Transfer ownership
            Ownable::OwnableImpl::transfer_ownership(ref state, new_admin_address);

            // [Interaction] Transfered ownership event
            self
                .emit(
                    Event::TransferOwnership(
                        TransferOwnership { old_address: old_admin, new_address: new_admin_address }
                    )
                );
        }

        /// Returns the admin address.
        fn get_admin_address(self: @ContractState) -> ContractAddress {
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            let res = Ownable::OwnableImpl::owner(@state);
            res
        }

        /// Returns the Pragma Oracle address.
        fn get_oracle_address(self: @ContractState) -> ContractAddress {
            self.get_oracle_address()
        }
    }

    // ================== PRIVATE FUNCTIONS ==================

    /// Asserts that the caller is the Admin.
    fn assert_only_admin() {
        let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        let admin = Ownable::OwnableImpl::owner(@state);
        let caller = get_caller_address();
        assert(caller == admin, errors::NOT_ADMIN);
    }
}
