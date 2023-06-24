use starknet::ContractAddress;
use entry::contracts::structs::{DataType, AggregationMode};
#[abi]
trait SummaryStatsABI {
    #[view]
    fn calculate_mean(data_type: DataType, start: u64, stop: u64) -> u128;
    #[view]
    fn calculate_volatility(
        data_type: DataType,
        start_tick: u64,
        end_tick: u64,
        num_samples: u64,
        aggregation_mode: AggregationMode
    ) -> u128;
    #[view]
    fn get_oracle_address() -> ContractAddress;
}

#[contract]
mod SummaryStats {
    use super::ContractAddress;

    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use array::ArrayTrait;
    use array::ArrayTCloneImpl;
    use traits::Into;
    use traits::TryInto;
    use oracle::contracts::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use summary_stats::business_logic::interface::ISummaryStats;
    use entry::contracts::structs::{DataType, AggregationMode};
    use pragma::time_series::structs::TickElem;
    // use pragma::time_series::metrics::volatility;

    struct Storage {
        oracle_address: ContractAddress, 
    }

    #[constructor]
    fn constructor(oracle_address: ContractAddress) {
        oracle_address::write(oracle_address);
    }

    impl SummaryStatsImpl of ISummaryStats {
        fn calculate_mean(
            oracle_address: ContractAddress, key: felt252, start: u64, stop: u64
        ) -> u128 {
            // let oracle = IOracle { contract_address: oracle_address };
            // let latest_checkpoint_index = oracle.get_latest_checkpoint_index(key);
            // let (cp, start_index) = oracle.get_last_spot_checkpoint_before(key, start);

            // assert(start_index != latest_checkpoint_index, 'Not enough data');

            // let (_, scaled_arr) = _make_scaled_array(oracle_address, key, start, stop, latest_checkpoint_index - start_index, latest_checkpoint_index, 1);
            // let mean = mean(SCALED_ARR_SIZE, scaled_arr);
            // let mean = to_wei(mean);

            // mean
            0
        }

        fn calculate_volatility(
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
            let latest_checkpoint_index = oracle_dispatcher
                .get_latest_checkpoint_index(data_type, aggregation_mode);
            let (_start_cp, start_index) = oracle_dispatcher
                .get_last_checkpoint_before(start_tick, data_type);
            let mut end_index = 0;
            if (end_tick == 0) {
                end_index = latest_checkpoint_index;
            } else {
                let (_end_cp, _end_idx) = oracle_dispatcher
                    .get_last_checkpoint_before(end_tick, data_type);
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
                let u256{low: value_l, high: value_h } = cp.value.into();
                tick_arr.append(TickElem { tick: cp.timestamp, value: value_l });
            };

            // let volatility_ = volatility(tick_arr.span());
            return 0;
        }
    }

    //
    // Views
    //

    #[view]
    fn get_oracle_address() -> ContractAddress {
        oracle_address::read()
    }

    #[view]
    fn calculate_mean(key: felt252, start: u64, stop: u64) -> u128 {
        let oracle_address = oracle_address::read();
        SummaryStatsImpl::calculate_mean(oracle_address, key, start, stop)
    }

    #[view]
    fn calculate_volatility(
        data_type: DataType,
        start_tick: u64,
        end_tick: u64,
        num_samples: u64,
        aggregation_mode: AggregationMode
    ) -> u128 {
        let oracle_address = oracle_address::read();
        let volatility: u128 = SummaryStatsImpl::calculate_volatility(
            oracle_address, data_type, start_tick, end_tick, num_samples, aggregation_mode
        );

        volatility * 100
    }

    #[internal]
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
