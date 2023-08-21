use starknet::ContractAddress;
use pragma::entry::structs::{DataType, AggregationMode};
use result::ResultTrait;
use cubit::f128::types::fixed::{FixedTrait, Fixed, ONE_u128};
use debug::PrintTrait;
#[starknet::interface]
trait ISummaryStatsABI<TContractState> {
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
        aggregation_mode: AggregationMode
    ) -> (u128, u32);

    fn calculate_twap(
        self: @TContractState,
        data_type: DataType,
        aggregation_mode: AggregationMode,
        time: u64,
        start_time: u64,
    ) -> (u128, u32);


    fn get_oracle_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod SummaryStats {
    use starknet::ContractAddress;

    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use result::ResultTrait;
    use array::ArrayTrait;
    use traits::Into;
    use traits::TryInto;
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use pragma::entry::structs::{DataType, AggregationMode};
    use pragma::operations::time_series::structs::TickElem;
    use pragma::operations::time_series::metrics::{volatility, mean, twap};
    use pragma::operations::time_series::scaler::scale_data;
    use super::{FixedTrait, Fixed, ONE_u128, PrintTrait, ISummaryStatsABI};
    const SCALED_ARR_SIZE: u32 = 30;
    #[storage]
    struct Storage {
        oracle_address: ContractAddress, 
    }

    #[constructor]
    fn constructor(ref self: ContractState, oracle_address: ContractAddress) {
        self.oracle_address.write(oracle_address);
    }

    #[external(v0)]
    impl SummaryStatsImpl of ISummaryStatsABI<ContractState> {
        fn calculate_mean(
            self: @ContractState,
            data_type: DataType,
            start: u64,
            stop: u64,
            aggregation_mode: AggregationMode
        ) -> (u128, u32) {
            let oracle_address = self.oracle_address.read();
            let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };

            let (latest_checkpoint_index, _) = oracle_dispatcher
                .get_latest_checkpoint_index(data_type, aggregation_mode);
            let (cp, start_index) = oracle_dispatcher
                .get_last_checkpoint_before(data_type, start, aggregation_mode);
            let decimals = oracle_dispatcher.get_decimals(data_type);

            let (stop_cp, stop_index) = oracle_dispatcher
                .get_last_checkpoint_before(data_type, stop, aggregation_mode);
            if (start_index == stop_index) {
                return (cp.value.try_into().unwrap(), decimals);
            }

            if start_index == latest_checkpoint_index {
                return (cp.value.try_into().unwrap(), decimals);
            }

            let scaled_arr = _make_scaled_array(
                oracle_address,
                data_type,
                start,
                stop,
                stop_index - start_index,
                stop_index,
                1,
                aggregation_mode
            );

            let mean = mean(scaled_arr.span()) / ONE_u128;

            (mean, decimals)
        }

        fn calculate_volatility(
            self: @ContractState,
            data_type: DataType,
            start_tick: u64,
            end_tick: u64,
            num_samples: u64,
            aggregation_mode: AggregationMode,
        ) -> (u128, u32) {
            let oracle_address = self.oracle_address.read();

            assert(num_samples > 0, 'num_samples must be > 0');
            assert(num_samples <= 200, 'num_samples is too large');

            let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
            let (latest_checkpoint_index, _) = oracle_dispatcher
                .get_latest_checkpoint_index(data_type, aggregation_mode);
            let (_start_cp, start_index) = oracle_dispatcher
                .get_last_checkpoint_before(data_type, start_tick, aggregation_mode);
            let decimals = oracle_dispatcher.get_decimals(data_type);

            let mut end_index = 0;
            if (end_tick == 0) {
                end_index = latest_checkpoint_index;
            } else {
                let (_end_cp, _end_idx) = oracle_dispatcher
                    .get_last_checkpoint_before(data_type, end_tick, aggregation_mode);
                end_index = _end_idx;
            }
            assert(start_index != latest_checkpoint_index, 'Not enough data');
            let mut tick_arr = ArrayTrait::<TickElem>::new();
            let skip_frequency = calculate_skip_frequency(end_index - start_index, num_samples);
            let total_samples = (end_index - start_index) / skip_frequency;
            let mut idx = 0;
            loop {
                if (end_index <= idx * skip_frequency + start_index) {
                    break ();
                }
                let cp = oracle_dispatcher
                    .get_checkpoint(
                        data_type, idx * skip_frequency + start_index, aggregation_mode
                    );
                let val = cp.value.into();
                let u128_val: u128 = val.try_into().unwrap();
                let fixed_val = FixedTrait::new(u128_val, false);
                tick_arr.append(TickElem { tick: cp.timestamp, value: fixed_val });
                idx += 1;
            };

            (volatility(tick_arr.span()), decimals)
        }


        fn calculate_twap(
            self: @ContractState,
            data_type: DataType,
            aggregation_mode: AggregationMode,
            time: u64,
            start_time: u64
        ) -> (u128, u32) {
            let oracle_address = self.oracle_address.read();
            let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
            let (_start_cp, start_index) = oracle_dispatcher
                .get_last_checkpoint_before(data_type, start_time, aggregation_mode);
            let (_stop_cp, stop_index) = oracle_dispatcher
                .get_last_checkpoint_before(data_type, start_time + time, aggregation_mode);
            let decimals = oracle_dispatcher.get_decimals(data_type);
            assert(start_index != stop_index, 'Not enough data');
            let mut tick_arr = ArrayTrait::<TickElem>::new();
            let mut idx = start_index;
            loop {
                if (stop_index < idx) {
                    break ();
                }
                let cp = oracle_dispatcher.get_checkpoint(data_type, idx, aggregation_mode);
                let val = cp.value.into();
                let u128_val: u128 = val.try_into().unwrap();
                let fixed_val = FixedTrait::new(u128_val, false);
                tick_arr.append(TickElem { tick: cp.timestamp, value: fixed_val });
                idx += 1;
            };
            (twap(tick_arr.span()), decimals)
        }


        fn get_oracle_address(self: @ContractState) -> ContractAddress {
            self.oracle_address.read()
        }
    }

    //
    // Views
    //

    fn calculate_skip_frequency(total_samples: u64, num_samples: u64) -> u64 {
        let skip_frequency = total_samples / num_samples;
        if (skip_frequency == 0) {
            return 1;
        }
        let r = total_samples % num_samples;
        if (r * 2 < num_samples) {
            return skip_frequency;
        } else {
            return skip_frequency + 1;
        }
    }

    fn _make_scaled_array(
        oracle_address: ContractAddress,
        data_type: DataType,
        start_tick: u64,
        end_tick: u64,
        num_datapoints: u64,
        latest_checkpoint_index: u64,
        skip_frequency: u64,
        aggregation_mode: AggregationMode
    ) -> Array<TickElem> {
        let mut tick_arr = ArrayTrait::<TickElem>::new();
        let mut idx = 0;
        loop {
            let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
            let offset = latest_checkpoint_index - num_datapoints;
            if (latest_checkpoint_index < idx * skip_frequency + offset) {
                break ();
            }
            let test = idx * skip_frequency + offset;

            let cp = oracle_dispatcher
                .get_checkpoint(data_type, idx * skip_frequency + offset, aggregation_mode);

            tick_arr
                .append(
                    TickElem {
                        tick: cp.timestamp, value: FixedTrait::new(cp.value.low * ONE_u128, false)
                    }
                );
            idx += 1;
        };
        let first = *tick_arr.at(0).value;
        let first_t = *tick_arr.at(0).tick;
        // let _scaled_arr = scale_data(start_tick, end_tick, tick_arr.span(), SCALED_ARR_SIZE);
        return tick_arr;
    }
}
