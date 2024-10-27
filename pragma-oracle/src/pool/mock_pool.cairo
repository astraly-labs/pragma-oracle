use starknet::ContractAddress;

// A simple mock pool contract
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
trait ISetPool<TContractState> {
    fn set_total_supply(ref self: TContractState, supply: u256);
    fn set_reserves(ref self: TContractState, reserves: (u256, u256));
}

#[starknet::contract]
mod Pool {
    use super::{ISetPool, IPool};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        token_0: ContractAddress,
        token_1: ContractAddress,
        reserves: (u256, u256)
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_0: ContractAddress, token_1: ContractAddress) {
        self.name.write('POOL_TEST');
        self.symbol.write('PT');
        self.decimals.write(8);
        self.total_supply.write(100);
        self.token_0.write(token_0);
        self.token_1.write(token_1);
        self.reserves.write((10000, 1000));
    }

    #[external(v0)]
    impl IPoolImpl of IPool<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn token_0(self: @ContractState) -> ContractAddress {
            self.token_0.read()
        }

        fn token_1(self: @ContractState) -> ContractAddress {
            self.token_1.read()
        }

        fn get_reserves(self: @ContractState) -> (u256, u256) {
            self.reserves.read()
        }
    }


    // Additional implementation for testing purpose only
    #[external(v0)]
    impl ISetPoolImpl of ISetPool<ContractState> {
        fn set_total_supply(ref self: ContractState, supply: u256) {
            self.total_supply.write(supply);
        }

        fn set_reserves(ref self: ContractState, reserves: (u256, u256)) {
            self.reserves.write(reserves)
        }
    }
}
