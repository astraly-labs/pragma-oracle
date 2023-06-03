use starknet::ContractAddress;


#[abi]
trait SummaryStatsABI {
    #[view]
    fn calculate_mean(key: felt252, start: u32, stop: u32) -> u256;
    #[view]
    fn calculate_volatility(key: felt252, start: u32, stop: u32, num_samples: u32) -> u256;
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

    use summary_stats::business_logic::interface::ISummaryStats;

    struct Storage {
        oracle_address: ContractAddress,
    }

    #[constructor]
    fn constructor(oracle_address: ContractAddress) {
        oracle_address::write(oracle_address);
    }

    impl SummaryStatsImpl of ISummaryStats {
        fn calculate_mean(oracle_address: ContractAddress, key: felt252, start: u32, stop: u32) -> u256 {
            // let oracle = IOracle { contract_address: oracle_address };
            // let latest_checkpoint_index = oracle.get_latest_checkpoint_index(key);
            // let (cp, start_index) = oracle.get_last_spot_checkpoint_before(key, start);

            // assert(start_index != latest_checkpoint_index, 'Not enough data');

            // let (_, scaled_arr) = _make_scaled_array(oracle_address, key, start, stop, latest_checkpoint_index - start_index, latest_checkpoint_index, 1);
            // let mean = mean(SCALED_ARR_SIZE, scaled_arr);
            // let mean = to_wei(mean);

            // mean
            u256 { low: 0, high: 0}
        }

        fn calculate_volatility(oracle_address: ContractAddress, key: felt252, start: u32, stop: u32, num_samples: u32) -> u256 {
            u256 { low: 0, high: 0}
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
    fn calculate_mean(key: felt252, start: u32, stop: u32) -> u256 {
        let oracle_address = oracle_address::read();
        SummaryStatsImpl::calculate_mean(oracle_address, key, start, stop)
    }

    #[view]
    fn calculate_volatility(key: felt252, start: u32, stop: u32, num_samples: u32) -> u256 {
        let oracle_address = oracle_address::read();
        let volatility = SummaryStatsImpl::calculate_volatility(oracle_address, key, start, stop, num_samples);
        
        // Reporting in percentage
        volatility * 100.into()
   }
}