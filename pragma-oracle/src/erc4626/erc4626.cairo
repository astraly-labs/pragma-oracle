// Forked from https://github.com/0xEniotna/ERC4626/blob/main/src/erc4626/interface.cairo
use starknet::ContractAddress;

#[starknet::interface]
trait IERC4626<TState> {
    // ************************************
    // * Metadata
    // ************************************
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;

    // ************************************
    // * snake_case
    // ************************************
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // ************************************
    // * camelCase
    // ************************************
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;

    // ************************************
    // * Additional functions
    // ************************************
    fn asset(self: @TState) -> starknet::ContractAddress;
    fn convert_to_assets(self: @TState, shares: u256) -> u256;
    fn convert_to_shares(self: @TState, assets: u256) -> u256;
    fn deposit(ref self: TState, assets: u256, receiver: starknet::ContractAddress) -> u256;
    fn max_deposit(self: @TState, address: starknet::ContractAddress) -> u256;
    fn max_mint(self: @TState, receiver: starknet::ContractAddress) -> u256;
    fn max_redeem(self: @TState, owner: starknet::ContractAddress) -> u256;
    fn max_withdraw(self: @TState, owner: starknet::ContractAddress) -> u256;
    fn mint(ref self: TState, shares: u256, receiver: starknet::ContractAddress) -> u256;
    fn preview_deposit(self: @TState, assets: u256) -> u256;
    fn preview_mint(self: @TState, shares: u256) -> u256;
    fn preview_redeem(self: @TState, shares: u256) -> u256;
    fn preview_withdraw(self: @TState, assets: u256) -> u256;
    fn redeem(
        ref self: TState,
        shares: u256,
        receiver: starknet::ContractAddress,
        owner: starknet::ContractAddress
    ) -> u256;
    fn total_assets(self: @TState) -> u256;
    fn withdraw(
        ref self: TState,
        assets: u256,
        receiver: starknet::ContractAddress,
        owner: starknet::ContractAddress
    ) -> u256;
}


#[starknet::interface]
trait IERC4626Metadata<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
}

#[starknet::interface]
trait IERC4626Camel<TState> {
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::interface]
trait IERC4626Snake<TState> {
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
trait IERC4626Additional<TState> {
    fn asset(self: @TState) -> ContractAddress;
    fn convert_to_assets(self: @TState, shares: u256) -> u256;
    fn convert_to_shares(self: @TState, assets: u256) -> u256;
    fn deposit(ref self: TState, assets: u256, receiver: ContractAddress) -> u256;
    fn max_deposit(self: @TState, address: ContractAddress) -> u256;
    fn max_mint(self: @TState, receiver: ContractAddress) -> u256;
    fn max_redeem(self: @TState, owner: ContractAddress) -> u256;
    fn max_withdraw(self: @TState, owner: ContractAddress) -> u256;
    fn mint(ref self: TState, shares: u256, receiver: ContractAddress) -> u256;
    fn preview_deposit(self: @TState, assets: u256) -> u256;
    fn preview_mint(self: @TState, shares: u256) -> u256;
    fn preview_redeem(self: @TState, shares: u256) -> u256;
    fn preview_withdraw(self: @TState, assets: u256) -> u256;
    fn redeem(
        ref self: TState, shares: u256, receiver: ContractAddress, owner: ContractAddress
    ) -> u256;
    fn total_assets(self: @TState) -> u256;
    fn withdraw(
        ref self: TState, assets: u256, receiver: ContractAddress, owner: ContractAddress
    ) -> u256;
}
