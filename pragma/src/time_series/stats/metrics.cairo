use pragma::time_series::structs::{TickElem, PAIRWISE_OPERATION};
use pragma::time_series::matmul::{pairwise_1D, dot_product};
use pragma::time_series::reshape::fill_1d;
use cubit::types::fixed::{FixedTrait};
use cubit::math::core::{sqrt, div, ln};
fn extract_value(tick_arr: Span<TickElem>) -> Array<u256> {
    let mut output = ArrayTrait::new();
    loop {
        match tick_arr.pop_front() {
            Option::Some(tick) => {
                output.push(*tick.value);
            },
            Option::None => {
                break ();
            },
        }
    };
    output
}

fn sum_tick_array(tick_arr: Span<TickElem>) -> u256 {
    let mut output = 0;
    loop {
        match tick_arr.pop_front() {
            Option::Some(tick) => {
                output += *tick.value;
            },
            Option::None => {
                break ();
            },
        }
    };
    output
}


//TODO : Check if this is safe 
fn mean(tick_arr: Span<TickElem>) -> u256 {
    let sum_ = sum_tick_array(tick_arr);
    let count = tick_arr.len();
    sum / count
}

fn variance(tick_arr: Span<TickElem>) -> u256 {
    let arr_ = extract_value(tick_arr);
    let mean_ = mean(tick_arr);
    let tick_arr_len = tick_arr.len();
    let mean_arr = fill_1d(tick_arr_len, mean_);
    let diff_arr = pairwise_1D(PAIRWISE_OPERATION.SUBTRACTION, arr_len, arr_, mean_arr);

    let diff_squared = pairwise_1D(
        PAIRWISE_OPERATION.FIXED_POINT_MULTIPLICATION, arr_len, diff_arr, diff_arr
    );

    let sum_ = sum_array(arr_len, diff_squared);
    let variance_ = sum_ / (arr_len - 1);

    return variance;
}

fn standard_deviation(arr: Span<u256>) -> FixedType {
    let variance_ = variance(arr);
    let fixed_variance_ = FixedTrait::new(variance_, false);
    let std = sqrt(fixed_variance_);
    std
}

fn volatility(arr: Span<TickElem>) -> FixedType {
    let _volatility_sum = _sum_volatility(arr);
    let _volatility = _volatility_sum / (arr_len - 1);
    let sqrt_vol = sqrt(_volatility);
    return sqrt_vol;
}

fn _sum_volatility(arr: Span<TickElem>) -> FixedType {
    let mut cur_idx = 1;
    let mut sum = FixedTrait::new(0, false);

    loop {
        if (cur_idx == arr.len()) {
            break ();
        }
        let cur_val = *arr.at(cur_idx);
        let prev_val = *arr.at(cur_idx - 1);
        let cur_value = cur_val.value;
        let fixed_cur_value = FixedTrait::new(cur_value, false);
        let prev_value = prev_val.value;
        let fixed_prev_value = FixedTrait::new(prev_value, false);
        let cur_timestamp = cur_val.tick;
        let prev_timestamp = prev_val.tick;

        let numerator_value = ln(div(fixed_cur_value, fixed_prev_value));
        let numerator = numerator_value.pow(FixedTrait::new(2, false));
        let denominator = div(
            FixedTrait::new((cur_timestamp - fixed_prev_timestamp), false),
            FixedTrait::new(ONE_YEAR_IN_SECONDS, false)
        );
        let fraction_ = div(numerator, denominator);
        sum = add(sum, fraction_);
        cur_idx = cur_idx + 1;
    }
    sum
}
