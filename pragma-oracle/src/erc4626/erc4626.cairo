// Forked from https://github.com/0xEniotna/ERC4626/blob/main/src/erc4626/interface.cairo
// Mock contract to be used for TESTING PURPOSE ONLY
use starknet::ContractAddress;

#[starknet::interface]
trait IERC4626<TContractState> {
    // Metadata (match implementation)
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;

    // ERC20-like methods (match implementation)
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    // Remove camelCase methods as they're not in the implementation

    // Additional ERC4626 methods (match implementation)
    fn asset(self: @TContractState) -> ContractAddress;
    fn total_assets(self: @TContractState) -> u256;
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    fn max_deposit(self: @TContractState, receiver: ContractAddress) -> u256;
    fn preview_deposit(self: @TContractState, assets: u256) -> u256;
    fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
    fn max_mint(self: @TContractState, receiver: ContractAddress) -> u256;
    fn preview_mint(self: @TContractState, shares: u256) -> u256;
    fn mint(ref self: TContractState, shares: u256, receiver: ContractAddress) -> u256;
    fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
    fn preview_withdraw(self: @TContractState, assets: u256) -> u256;
    fn withdraw(
        ref self: TContractState, assets: u256, receiver: ContractAddress, owner: ContractAddress
    ) -> u256;
    fn max_redeem(self: @TContractState, owner: ContractAddress) -> u256;
    fn preview_redeem(self: @TContractState, shares: u256) -> u256;
    fn redeem(
        ref self: TContractState, shares: u256, receiver: ContractAddress, owner: ContractAddress
    ) -> u256;
}

#[starknet::contract]
mod ERC4626 {
    use super::IERC4626;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::ContractAddress;
    use starknet::contract_address::ContractAddressZeroable;
    use zeroable::Zeroable;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use integer::BoundedInt;
    use debug::PrintTrait;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl ERC4626Impl of IERC4626<ContractState> {
        ////////////////////////////////
        // ERC20 implementation
        ////////////////////////////////

        fn name(self: @ContractState) -> felt252 {
            0
        }

        fn symbol(self: @ContractState) -> felt252 {
            0
        }

        fn decimals(self: @ContractState) -> u8 {
            0
        }

        fn total_supply(self: @ContractState) -> u256 {
            0
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            0
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            0
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            true
        }

        ////////////////////////////////
        // ERC4626-specific implementation
        ////////////////////////////////

        fn asset(self: @ContractState) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn total_assets(self: @ContractState) -> u256 {
            0
        }

        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            0
        }

        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            0
        }

        fn max_deposit(self: @ContractState, receiver: ContractAddress) -> u256 {
            0
        }

        fn preview_deposit(self: @ContractState, assets: u256) -> u256 {
            0
        }

        fn deposit(ref self: ContractState, assets: u256, receiver: ContractAddress) -> u256 {
            0
        }

        fn max_mint(self: @ContractState, receiver: ContractAddress) -> u256 {
            BoundedInt::<u256>::max()
        }

        fn preview_mint(self: @ContractState, shares: u256) -> u256 {
            // TESTING
            1002465544733197129
        }

        fn mint(ref self: ContractState, shares: u256, receiver: ContractAddress) -> u256 {
            0
        }

        fn max_withdraw(self: @ContractState, owner: ContractAddress) -> u256 {
            0
        }

        fn preview_withdraw(self: @ContractState, assets: u256) -> u256 {
            0
        }

        fn withdraw(
            ref self: ContractState, assets: u256, receiver: ContractAddress, owner: ContractAddress
        ) -> u256 {
            0
        }

        fn max_redeem(self: @ContractState, owner: ContractAddress) -> u256 {
            0
        }

        fn preview_redeem(self: @ContractState, shares: u256) -> u256 {
            0
        }

        fn redeem(
            ref self: ContractState, shares: u256, receiver: ContractAddress, owner: ContractAddress
        ) -> u256 {
            0
        }
    }
}
