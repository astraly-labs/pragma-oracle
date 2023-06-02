use array::ArrayTrait;
use option::OptionTrait;
use starknet::ContractAddress;

trait ISummaryStats {
    fn calculate_mean(oracle_address: ContractAddress, key: felt252, start: u32, stop: u32) -> u256;
    fn calculate_volatility(oracle_address: ContractAddress, key: felt252, start: u32, stop: u32, num_samples: u32) -> u256;
}
