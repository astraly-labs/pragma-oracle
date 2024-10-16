use starknet::{ContractAddress, contract_address_const};

/// Represents a Pool.
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
    fn get_pool_usd_price(self: @TContractState, pool_address: ContractAddress) -> u256;

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
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait, DataType};
    use openzeppelin::token::erc20::interface::{
        ERC20CamelABIDispatcher, ERC20CamelABIDispatcherTrait
    };
    use super::{
        PoolInfo, ILpPricer, IPoolDispatcher, IPoolDispatcherTrait, Pool, PoolTrait, Token,
        TokenTrait
    };
    use pragma::utils::strings::StringTrait;

    const USD_PAIR_SUFFIX: felt252 = '/USD';

    // ================== ERRORS ==================

    mod errors {
        const NOT_ADMIN: felt252 = 'Caller is not the admin';
        const ZERO_ADDRESS_ADMIN: felt252 = 'New admin is the zero address';
        const ZERO_ADDRESS_ORACLE: felt252 = 'Oracle is the zero address';
        const ALREADY_ADMIN: felt252 = 'Already admin';
        const POOL_ALREADY_REGISTED: felt252 = 'Pool already registered';
        const UNSUPPORTED_POOL: felt252 = 'Pool not supported';
        const UNSUPPORTED_CURRENCY: felt252 = 'Currency not supported';
    }

    // ================== STORAGE ==================

    #[storage]
    struct Storage {
        oracle: IOracleABIDispatcher,
        supported_pools: LegacyMap<ContractAddress, Pool>,
    }

    // ================== EVENTS ==================

    #[derive(Drop, starknet::Event)]
    struct RegisteredPool {
        pool_symbol: felt252,
        pool_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct RemovedPool {
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
        // [Check] Addresses are not zero
        assert(!admin_address.is_zero(), errors::ZERO_ADDRESS_ADMIN);
        assert(!oracle_address.is_zero(), errors::ZERO_ADDRESS_ORACLE);

        // [Effect] Set owner
        let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref state, admin_address);

        // [Effect] Set Oracle
        let oracle = IOracleABIDispatcher { contract_address: oracle_address };
        self.oracle.write(oracle);
    }

    // ================== PUBLIC ABI ==================

    #[external(v0)]
    impl LpPricerImpl of ILpPricer<ContractState> {
        /// Prices a pool in USD.
        /// 
        /// The current formula is:
        /// (token A reserve * token A price + token B reserve * token B price) / total supply
        /// 
        /// The prices of the underlying tokens are retrieved from the Pragma Oracle.
        fn get_pool_usd_price(self: @ContractState, pool_address: ContractAddress) -> u256 {
            // [Check] Pool is supported
            assert(self.is_supported_pool(pool_address), errors::UNSUPPORTED_POOL);

            // [Effect] Get the addresses, symbols & reserves 
            let pool = self.supported_pools.read(pool_address);
            let (token_a_address, token_b_address) = pool.get_tokens_addresses();
            let (token_a_id, token_b_id) = pool.get_tokens_symbols();
            let (token_a_reserve, token_b_reserve) = pool.dispatcher.get_reserves();

            // [Effect] Get token prices
            let oracle = self.oracle.read();
            let token_a_price = get_currency_price_in_usd(oracle, token_a_id);
            let token_b_price = get_currency_price_in_usd(oracle, token_b_id);

            (token_a_reserve * token_a_price + token_b_reserve * token_b_price) / pool.total_supply
        }

        /// Register a pool into the supported list.
        /// 
        /// Can only be called by the admin.
        fn add_pool(ref self: ContractState, pool_address: ContractAddress) {
            // [Check] Only admin
            assert_only_admin();
            // [Check] Pool is not already registered
            assert(!self.is_supported_pool(pool_address), errors::POOL_ALREADY_REGISTED);

            // [Effect] Fetch the underlying token of the pool (address + symbol)
            let pool_dispatcher = IPoolDispatcher { contract_address: pool_address };
            let (token_a_address, token_b_address) = fetch_tokens_addresses(pool_dispatcher);
            let (token_a_id, token_b_id) = fetch_tokens_symbols(token_a_address, token_b_address);

            // [Check] Assert that both pool assets are supported by Pragma
            let oracle = self.oracle.read();
            assert(currency_is_supported(oracle, token_a_id), errors::UNSUPPORTED_CURRENCY);
            assert(currency_is_supported(oracle, token_b_id), errors::UNSUPPORTED_CURRENCY);

            // [Effect] Add the pool to the storage
            let pool = Pool {
                id: pool_dispatcher.symbol(),
                token_a: TokenTrait::new(token_a_id, token_a_address),
                token_b: TokenTrait::new(token_b_id, token_b_address),
                total_supply: pool_dispatcher.total_supply(),
                dispatcher: pool_dispatcher,
            };
            self.supported_pools.write(pool_address, pool);

            // [Interaction] Pool registered event
            self
                .emit(
                    Event::RegisteredPool(
                        RegisteredPool {
                            pool_symbol: pool.id, pool_address: pool.dispatcher.contract_address,
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
            let non_existing_pool = PoolTrait::zero();
            self.supported_pools.write(pool_address, non_existing_pool);

            // [Interaction] Pool unregistered event
            self
                .emit(
                    Event::RemovedPool(
                        RemovedPool { pool_symbol: pool.id, pool_address: pool_address, }
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
                address: pool.dispatcher.contract_address,
                name: pool.dispatcher.name(),
                symbol: pool.id,
                decimals: pool.dispatcher.decimals(),
                total_supply: pool.total_supply,
                token_a: pool.token_a.address,
                token_b: pool.token_b.address,
            }
        }

        /// Returns true if the pool is supported, else false.
        fn is_supported_pool(self: @ContractState, pool_address: ContractAddress) -> bool {
            // [Interaction] Return if the pool is supported
            !self.supported_pools.read(pool_address).id.is_zero()
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
    // Utilities used in the Public ABI.

    /// Asserts that the caller is the Admin.
    fn assert_only_admin() {
        let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        let admin = Ownable::OwnableImpl::owner(@state);
        let caller = get_caller_address();
        assert(caller == admin, errors::NOT_ADMIN);
    }

    /// Retrieves the token addresses from from the Pool Dispatcher.
    fn fetch_tokens_addresses(
        pool_dispatcher: IPoolDispatcher
    ) -> (ContractAddress, ContractAddress) {
        (pool_dispatcher.token_0(), pool_dispatcher.token_1())
    }

    /// Retrieves the token symbols from the underlying currencies.
    fn fetch_tokens_symbols(
        token_a_address: ContractAddress, token_b_address: ContractAddress
    ) -> (felt252, felt252) {
        let token_a = ERC20CamelABIDispatcher { contract_address: token_a_address };
        let token_b = ERC20CamelABIDispatcher { contract_address: token_b_address };
        (token_a.symbol(), token_b.symbol())
    }

    /// Returns true if the currency is supported by Pragma, else false.
    fn currency_is_supported(oracle: IOracleABIDispatcher, currency_id: felt252) -> bool {
        oracle.get_currency(currency_id).id != 0
    }

    /// Returns the price in USD for a currency by fetching it from the Pragma Oracle.
    fn get_currency_price_in_usd(oracle: IOracleABIDispatcher, currency_id: felt252) -> u256 {
        let pair_id = StringTrait::concat(currency_id, USD_PAIR_SUFFIX);
        let data_type = DataType::SpotEntry(pair_id);
        let data = oracle.get_data_median(data_type);
        data.price.into()
    }
}

// ===================== STRUCTS =====================
//
// Below, you will find utils structs used for the LpPricer contract.

#[derive(Copy, Drop, Serde, Debug)]
struct Token {
    symbol: felt252,
    address: ContractAddress,
}

#[generate_trait]
impl TokenImpl of TokenTrait {
    fn new(symbol: felt252, address: ContractAddress) -> Token {
        Token { symbol, address }
    }
}

#[derive(Copy, Drop, Serde, Debug)]
struct Pool {
    id: felt252,
    dispatcher: IPoolDispatcher,
    token_a: Token,
    token_b: Token,
    total_supply: u256,
}

#[generate_trait]
impl PoolImpl of PoolTrait {
    fn zero() -> Pool {
        Pool {
            id: 0,
            dispatcher: IPoolDispatcher { contract_address: contract_address_const::<0>() },
            token_a: TokenTrait::new(0, contract_address_const::<0>()),
            token_b: TokenTrait::new(0, contract_address_const::<0>()),
            total_supply: 0,
        }
    }

    /// Retrieves both underlying tokens addresses of a Pool.
    fn get_tokens_addresses(self: @Pool) -> (ContractAddress, ContractAddress) {
        (*self.token_a.address, *self.token_b.address)
    }

    /// Retrieves the token symbols from the underlying currencies.
    fn get_tokens_symbols(self: @Pool) -> (felt252, felt252) {
        (*self.token_a.symbol, *self.token_b.symbol)
    }
}

#[derive(Copy, Drop, Serde, Debug)]
struct PoolInfo {
    address: ContractAddress,
    name: felt252,
    symbol: felt252,
    decimals: u8,
    total_supply: u256,
    token_a: ContractAddress,
    token_b: ContractAddress,
}
