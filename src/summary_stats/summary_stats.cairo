use starknet::ContractAddress;
use pragma::entry::structs::{DataType, AggregationMode};
use result::ResultTrait;
use cubit::types::fixed::{FixedTrait, Fixed};

#[starknet::interface]
trait SummaryStatsABI<TContractState> {
    fn calculate_mean(self: @TContractState, data_type: DataType, start: u64, stop: u64) -> u128;

    fn calculate_volatility(
        self: @TContractState,
        data_type: DataType,
        start_tick: u64,
        end_tick: u64,
        num_samples: u64,
        aggregation_mode: AggregationMode
    ) -> u128;

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
    use pragma::summary_stats::interface::ISummaryStats;
    use pragma::entry::structs::{DataType, AggregationMode};
    use pragma::operations::time_series::structs::TickElem;
    use pragma::operations::time_series::metrics::volatility;
    use super::{FixedTrait, Fixed};
    #[storage]
    struct Storage {
        oracle_address: ContractAddress, 
    }

    #[constructor]
    fn constructor(ref self: ContractState, oracle_address: ContractAddress) {
        self.oracle_address.write(oracle_address);
    }

    #[external(v0)]
    impl SummaryStatsImpl of ISummaryStats<ContractState> {
        fn calculate_mean(
            self: @ContractState,
            oracle_address: ContractAddress,
            key: felt252,
            start: u64,
            stop: u64
        ) -> u128 {
            // let oracle = IOracle { contract_address: oracle_address };
            // let (latest_checkpoint_index,_) = oracle.get_latest_checkpoint_index(key);
            // let (cp, start_index) = oracle.get_last_spot_checkpoint_before(key, start);

            // assert(start_index != latest_checkpoint_index, 'Not enough data');

            // let (_, scaled_arr) = _make_scaled_array(oracle_address, key, start, stop, latest_checkpoint_index - start_index, latest_checkpoint_index, 1);
            // let mean = mean(SCALED_ARR_SIZE, scaled_arr);
            // let mean = to_wei(mean);

            // mean
            0
        }

        fn calculate_volatility(
            self: @ContractState,
            oracle_address: ContractAddress,
            data_type: DataType,
            start_tick: u64,
            end_tick: u64,
            num_samples: u64,
            aggregation_mode: AggregationMode,
        ) -> u128 {
            assert(num_samples > 0, 'num_samples must be > 0');
            assert(num_samples <= 200, 'num_samples is too large');

            let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
            let (latest_checkpoint_index,_) = oracle_dispatcher
                .get_latest_checkpoint_index(data_type, aggregation_mode);
            let (_start_cp, start_index) = oracle_dispatcher
                .get_last_checkpoint_before(data_type, aggregation_mode, start_tick);
            let mut end_index = 0;
            if (end_tick == 0) {
                end_index = latest_checkpoint_index;
            } else {
                let (_end_cp, _end_idx) = oracle_dispatcher
                    .get_last_checkpoint_before(data_type, aggregation_mode, end_tick);
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
                    .get_checkpoint(data_type, idx * skip_frequency + start_index);
                let val = cp.value.into();
                let u128_val: u128 = val.try_into().unwrap();
                let fixed_val = FixedTrait::new(u128_val, false);
                tick_arr.append(TickElem { tick: cp.timestamp, value: fixed_val });
                idx += 1;
            };

            volatility(tick_arr.span())
        }
    }

    //
    // Views
    //

    fn get_oracle_address(self: @ContractState) -> ContractAddress {
        self.oracle_address.read()
    }


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
}
