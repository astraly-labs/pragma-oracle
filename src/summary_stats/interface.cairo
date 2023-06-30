use array::ArrayTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use pragma::entry::structs::{DataType, AggregationMode};
trait ISummaryStats<TContractState> {
    fn calculate_mean(self : @TContractState, oracle_address: ContractAddress, key: felt252, start: u64, stop: u64) -> u128;
    fn calculate_volatility(
        self:  @TContractState,
        oracle_address: ContractAddress,
        data_type: DataType,
        start_tick: u64,
        end_tick: u64,
        num_samples: u64,
        aggregation_mode: AggregationMode,
    ) -> u128;
}
