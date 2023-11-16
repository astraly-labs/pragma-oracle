use starknet::ContractAddress;
use pragma::entry::structs::{DataType, AggregationMode};
use cubit::f128::types::fixed::{FixedTrait, ONE_u128};
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

    use array::ArrayTrait;
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use pragma::entry::structs::{DataType, AggregationMode};
    use pragma::operations::time_series::structs::TickElem;
    use pragma::operations::time_series::metrics::{volatility, mean, twap};
    use pragma::operations::time_series::scaler::scale_data;
    use super::{FixedTrait, ONE_u128, ISummaryStatsABI};
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
        // @notice: compute the mean price for a given data type, for a given interval 
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param start: initial timestamp, combined with final_timestamp, it helps define the period over which the mean is computed
        // @param stop : final timestamp. 
        // @param aggregation_mode: specifies the method by which the oracle aggregates each price used in the computation 
        // @returns the mean price
        // @returns the precision, the number of decimals (the real mean value is mean / (10**decimals))
        fn calculate_mean(
            self: @ContractState,
            data_type: DataType,
            start: u64,
            stop: u64,
            aggregation_mode: AggregationMode
        ) -> (u128, u32) {
            assert(start < stop, 'start must be < stop');
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
                return (cp.value, decimals);
            }

            if start_index == latest_checkpoint_index {
                return (cp.value, decimals);
            }

            let scaled_arr = _make_scaled_array(
                oracle_address, data_type, stop_index - start_index, stop_index, 1, aggregation_mode
            );

            let mean = mean(scaled_arr.span()) / ONE_u128;

            (mean, decimals)
        }


        // @notice computes the realised volatility for a given data type and a given interval
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param start_tick: initial timestamp, combined with final_timestamp, it helps define the period over which the mean is computed
        // @param end_tick : final timestamp. 
        // @param num_samples: the number of subdivision of the initial interval used for the computation
        // @param aggregation_mode: specifies the method by which the oracle aggregates each price used in the computation 
        // @returns the realized volatility
        // @returns the precision, the number of decimals (the real mean value is mean / (10**decimals))
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

            let mut end_index = 0;
            if (end_tick == 0) {
                end_index = latest_checkpoint_index;
            } else {
                let (_end_cp, _end_idx) = oracle_dispatcher
                    .get_last_checkpoint_before(data_type, end_tick, aggregation_mode);
                end_index = _end_idx;
            }
            assert(start_index < end_index, 'start_tick must be < end_tick');
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

                let fixed_val = FixedTrait::new(cp.value, false);
                tick_arr.append(TickElem { tick: cp.timestamp, value: fixed_val });
                idx += 1;
            };
            //the number of decimals is hardcoded to 8 by the volatilty computation in metrics.cairo
            (volatility(tick_arr.span()), 8)
        }


        // @notice compute the time weighted average price for a given data type, and a give interval
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param aggregation_mode: specifies the method by which the oracle aggregates each price used in the computation 
        // @param time : represent the DURATION, used for the computation
        // @param start_time: the initial timestamp, the working interval is then [start_time, start_time+time]
        // @returns the time weighted average price 
        // @returns the precision, the number of decimals (the real mean value is mean / (10**decimals))
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

                let fixed_val = FixedTrait::new(cp.value, false);
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

    // @notice create the subdivision, e.g the number by which we need to increment the cursor in order to comply with the given num_samples
    // @param total_samples: the total number of data available within the interval
    // @param num_samples: the number of samples needed
    // @returns the incrementation
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


    // @notice generate an array with incremented entries, complying with the calculate_skip_freqency specification
    // @param oracle_address: the oracle address, used to call functions within the oracle
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param num_datapoints: the total number of checkpoints available within the given interval
    // @param latest_checkpoint_index : the latest checkpoint index within the given interval
    // @param skip_frequency: the incrementation
    // @param aggregation_mode: specifies the method by which the oracle aggregates each price used in the computation 
    fn _make_scaled_array(
        oracle_address: ContractAddress,
        data_type: DataType,
        num_datapoints: u64,
        latest_checkpoint_index: u64,
        skip_frequency: u64,
        aggregation_mode: AggregationMode
    ) -> Array<TickElem> {
        let mut tick_arr = ArrayTrait::<TickElem>::new();
        let mut idx = 0;
        let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
        let offset = latest_checkpoint_index - num_datapoints;
        loop {
            if (latest_checkpoint_index < idx * skip_frequency + offset) {
                break ();
            }
            let test = idx * skip_frequency + offset;

            let cp = oracle_dispatcher
                .get_checkpoint(data_type, idx * skip_frequency + offset, aggregation_mode);

            tick_arr
                .append(
                    TickElem {
                        tick: cp.timestamp, value: FixedTrait::new(cp.value * ONE_u128, false)
                    }
                );
            idx += 1;
        };
        // let _scaled_arr = scale_data(start_tick, end_tick, tick_arr.span(), SCALED_ARR_SIZE);
        return tick_arr;
    }
}
