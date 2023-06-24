use array::ArrayTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use entry::contracts::structs::{DataType, AggregationMode};
trait ISummaryStats {
    fn calculate_mean(oracle_address: ContractAddress, key: felt252, start: u64, stop: u64) -> u128;
    fn calculate_volatility(
        oracle_address: ContractAddress,
        data_type: DataType,
        start_tick: u64,
        end_tick: u64,
        num_samples: u64,
        aggregation_mode: AggregationMode,
    ) -> u128;
}
