use array::ArrayTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use pragma::entry::structs::{DataType, AggregationMode};
trait ISummaryStats<TContractState> {
    fn calculate_mean(
        self: @TContractState,
        data_type: DataType,
        start: u64,
        stop: u64,
        aggregation_mode: AggregationMode
    ) -> (u128, u32);
    fn calculate_volatility(
        self: @TContractState,
        data_type: DataType,
        start_tick: u64,
        end_tick: u64,
        num_samples: u64,
        aggregation_mode: AggregationMode,
    ) -> (u128, u32);

    fn calculate_twap(
        self: @TContractState,
        data_type: DataType,
        aggregation_mode: AggregationMode,
        time: u64,
        start_time: u64,
    ) -> (u128, u32);
}
