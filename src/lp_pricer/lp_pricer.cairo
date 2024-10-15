use starknet::ContractAddress;

#[starknet::interface]
trait ILpPricer<TContractState> {
    fn get_usd_price(self: @TContractState, lp_contract: ContractAddress) -> u128;
    fn get_oracle_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod LpPricer {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use box::BoxTrait;
    use array::{ArrayTrait, SpanTrait};
    use serde::Serde;
    use traits::Into;
    use traits::TryInto;
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use super::ILpPricer;

    // ================== STORAGE ==================

    #[storage]
    struct Storage {
        oracle: IOracleABIDispatcher,
    }

    // ================== CONSTRUCTOR ================================

    #[constructor]
    fn constructor(ref self: ContractState, oracle_address: ContractAddress) {
        let oracle = IOracleABIDispatcher { contract_address: oracle_address };
        self.oracle.write(oracle);
    }

    // ================== PUBLIC ABI ==================

    #[external(v0)]
    impl LpPricerImpl of ILpPricer<ContractState> {
        fn get_usd_price(self: @ContractState, lp_contract: ContractAddress) -> u128 {
            0
        }
        fn get_oracle_address(self: @ContractState) -> ContractAddress {
            self.oracle.read().contract_address
        }
    }
}
