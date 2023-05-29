use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use serde::Serde;
use serde::deserialize_array_helper;
use serde::serialize_array_helper;
use starknet::ContractAddress;

use account::business_logic::interface::Call;

const TRANSACTION_VERSION: felt252 = 1;
// 2**128 + TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457;

#[abi]
trait AccountABI {
    #[external]
    fn __execute__(calls: Array<Call>) -> Array<Span<felt252>>;
    #[external]
    fn __validate__(calls: Array<Call>) -> felt252;
    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252;
    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252;
    #[external]
    fn set_public_key(new_public_key: felt252);
    #[view]
    fn get_public_key() -> felt252;
    #[view]
    fn is_valid_signature(message: felt252, signature: Array<felt252>) -> u32;
    #[view]
    fn supports_interface(interface_id: u32) -> bool;
}

#[account_contract]
mod Account {
    use array::SpanTrait;
    use array::ArrayTrait;
    use box::BoxTrait;
    use ecdsa::check_ecdsa_signature;
    use serde::ArraySerde;
    use starknet::get_tx_info;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use option::OptionTrait;
    use zeroable::Zeroable;

    use account::business_logic::interface::ERC1271_VALIDATED;
    use account::business_logic::interface::IAccount;
    use account::business_logic::interface::IACCOUNT_ID;

    use super::Call;
    use super::QUERY_VERSION;
    use super::SpanSerde;
    use super::TRANSACTION_VERSION;

}

impl SpanSerde<
    T, impl TSerde: Serde<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>
> of Serde<Span<T>> {
    fn serialize(self: @Span<T>, ref output: Array<felt252>) {
        (*self).len().serialize(ref output);
        serialize_array_helper(*self, ref output);
    }
    fn deserialize(ref serialized: Span<felt252>) -> Option<Span<T>> {
        let length = *serialized.pop_front()?;
        let mut arr = ArrayTrait::new();
        Option::Some(deserialize_array_helper(ref serialized, arr, length)?.span())
    }
}