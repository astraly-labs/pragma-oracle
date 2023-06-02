use array::ArrayTrait;
use option::OptionTrait;

trait ISummaryStats {
    fn calculate_mean(key: felt252, start: u32, stop: u32) -> u256;
    fn calculate_volatility(key: felt252, start: u32, stop: u32, num_samples: u32) -> u256;
}
