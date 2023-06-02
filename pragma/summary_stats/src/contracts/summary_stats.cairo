#[contract]
mod SummaryStats {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use array::ArrayTrait;
    use array::ArrayTCloneImpl;
    use traits::Into;
    use traits::TryInto;

    use summary_stats::business_logic::interface::ISummaryStats;

    const SCALED_ARR_SIZE: u32 = 30;


    struct Storage {
        oracle_address: ContractAddress
    }

    #[constructor]
    fn constructor(oracle_address: ContractAddress) {
        oracle_address::write(oracle_address);
    }

    impl SummaryStatsImpl for ISummaryStats {
        fn calculate_mean(oracle_address: ContractAddress, key: felt252, start: u32, stop: u32) -> u256 {
        }

        fn calculate_volatility(oracle_address: ContractAddress, key: felt252, start: u32, stop: u32, num_samples: u32) -> u256 {
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
        volatility * 100
   }
}

