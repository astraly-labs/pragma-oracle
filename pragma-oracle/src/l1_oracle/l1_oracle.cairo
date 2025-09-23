use pragma::entry::structs::PragmaPricesResponse;
use pragma::admin::admin::Ownable;
use starknet::{ContractAddress, get_caller_address};
use starknet::{
    storage_read_syscall, storage_write_syscall, storage_address_from_base_and_offset,
    storage_access::storage_base_address_from_felt252, Store, StorageBaseAddress, SyscallResult,
};

#[derive(starknet::Store, Copy, Drop, Serde)]
struct EntryStorage {
    price: u128,
    timestamp: u64,
    decimals: u8
}

#[starknet::interface]
trait IL1Oracle<TContractState> {
    fn get_yield_token_price(self: @TContractState, pair_id: felt252) -> PragmaPricesResponse;
    fn set_yield_token_price(ref self: TContractState, pair_id: felt252, entry: EntryStorage);
    fn get_admin_address(self: @TContractState) -> ContractAddress;
    fn set_admin_address(ref self: TContractState, new_admin_address: ContractAddress);
}


#[starknet::contract]
mod L1OracleImpl {
    use super::{
        IL1Oracle, PragmaPricesResponse, EntryStorage, Ownable, ContractAddress, get_caller_address,
        Store
    };


    #[storage]
    struct Storage {
        yield_asset_prices: LegacyMap<felt252, EntryStorage>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref state, admin_address);
    }

    #[external(v0)]
    impl IL1OracleImpl of IL1Oracle<ContractState> {
        fn get_yield_token_price(self: @ContractState, pair_id: felt252) -> PragmaPricesResponse {
            let entry = self.yield_asset_prices.read(pair_id);

            PragmaPricesResponse {
                price: entry.price,
                decimals: entry.decimals.into(),
                last_updated_timestamp: entry.timestamp,
                num_sources_aggregated: 1,
                expiration_timestamp: Option::None,
            }
        }

        fn set_yield_token_price(ref self: ContractState, pair_id: felt252, entry: EntryStorage) {
            let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::assert_only_owner(@state);
            self.yield_asset_prices.write(pair_id, entry);
        }

        fn get_admin_address(self: @ContractState) -> ContractAddress {
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::owner(@state)
        }

        fn set_admin_address(ref self: ContractState, new_admin_address: ContractAddress) {
            let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::transfer_ownership(ref state, new_admin_address);
        }
    }
}
