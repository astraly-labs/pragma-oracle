use pragma::operations::time_series::structs::{TickElem, PAIRWISE_OPERATION};

use cubit::types::fixed::{
    HALF_u128, MAX_u128, ONE_u128, Fixed, FixedInto, FixedTrait, FixedAdd, FixedDiv, FixedMul,
    FixedNeg
};
use array::{ArrayTrait, SpanTrait};
use traits::{Into, TryInto};
use option::OptionTrait;
use box::BoxTrait;

const ONE_YEAR_IN_SECONDS: u128 = 31536000_u128;

#[derive(Copy, Drop)]
enum Operations {
    SUBSTRACTION: (),
    MULTIPLICATION: (),
}

/// Returns an array of `u128` from `TickElem` array
fn extract_value(tick_arr: Span<TickElem>) -> Array<u128> {
    let mut output = ArrayTrait::<u128>::new();
    let mut cur_idx = 0;
    loop {
        if (cur_idx >= tick_arr.len()) {
            break ();
        }
        let cur_val = *tick_arr.get(cur_idx).unwrap().unbox();
        output.append(cur_val.value);
        cur_idx = cur_idx + 1;
    };
    output
}

/// Sum the values of an array of `TickElem`
fn sum_tick_array(tick_arr: Span<TickElem>) -> u128 {
    let mut output = 0;
    let mut cur_idx = 0;
    loop {
        if (cur_idx >= tick_arr.len()) {
            break ();
        }
        let cur_val = *tick_arr.get(cur_idx).unwrap().unbox();
        output += cur_val.value;
        cur_idx = cur_idx + 1;
    };
    output
}

/// Sum the elements of an array of `u128`
fn sum_array(tick_arr: Span<u128>) -> u128 {
    let mut output = 0;
    let mut cur_idx = 0;
    loop {
        if (cur_idx >= tick_arr.len()) {
            break ();
        }
        let cur_val = *tick_arr.get(cur_idx).unwrap().unbox();
        output += cur_val;
        cur_idx = cur_idx + 1;
    };
    output
}

/// Computes the mean of a `TickElem` array
fn mean(tick_arr: Span<TickElem>) -> u128 {
    let sum_ = sum_tick_array(tick_arr);
    let felt_count: felt252 = tick_arr.len().into();
    let count: u128 = felt_count.try_into().unwrap();
    sum_ / count
}

/// Computes the variance of a `TickElem` array
fn variance(tick_arr: Span<TickElem>) -> u128 {
    let arr_ = extract_value(tick_arr);
    let arr_len = arr_.len();
    let mean_ = mean(tick_arr);
    let tick_arr_len = tick_arr.len();
    let mean_arr = fill_1d(tick_arr_len, mean_);
    let diff_arr = pairwise_1D(Operations::SUBSTRACTION(()), arr_len, arr_.span(), mean_arr.span());

    let diff_squared = pairwise_1D(Operations::MULTIPLICATION(()), arr_len, diff_arr, diff_arr);

    let sum_ = sum_array(diff_squared);
    let felt_arr_len: felt252 = arr_len.into();
    let variance_ = sum_ / (felt_arr_len.try_into().unwrap() - 1);

    return variance_;
}

/// Computes the standard deviation of a `TickElem` array
/// Calls `variance` and computes the squared root
fn standard_deviation(arr: Span<TickElem>) -> Fixed {
    let variance_ = variance(arr);
    let fixed_variance_ = FixedTrait::new(variance_, false);
    let std = FixedTrait::sqrt(fixed_variance_);
    std
}

/// Compute the volatility of a `TickElem` array
fn volatility(arr: Span<TickElem>) -> Fixed {
    let _volatility_sum = _sum_volatility(arr);
    let arr_len = arr.len();
    let fixed_len = FixedTrait::new(arr_len.into(), false);
    let _volatility = _volatility_sum / fixed_len;
    let sqrt_vol = FixedTrait::sqrt(_volatility);
    return sqrt_vol;
}

fn _sum_volatility(arr: Span<TickElem>) -> Fixed {
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
        let a = FixedTrait::from_felt(50143449209799256683);
        // let numerator_value = FixedTrait::ln(fixed_cur_value / fixed_prev_value);
        // let numerator = numerator_value.pow(FixedTrait::new(2, false));
        // let denominator = FixedTrait::new((cur_timestamp - prev_timestamp).into(), false)
        //     / FixedTrait::new(ONE_YEAR_IN_SECONDS, false);
        // let fraction_ = numerator / denominator;
        // sum = sum + fraction_;
        cur_idx = cur_idx + 1;
    };
    sum
}

/// Computes a result array given two arrays and one operation
/// e.g : [1, 2, 3] + [1, 2, 3] = [2, 4, 6]
fn pairwise_1D(operation: Operations, x_len: u32, x: Span<u128>, y: Span<u128>) -> Span<u128> {
    let mut cur_idx: u32 = 0;
    let mut output = ArrayTrait::<u128>::new();
    match operation {
        Operations::SUBSTRACTION(()) => {
            loop {
                if (cur_idx >= x_len) {
                    break ();
                }
                let x1 = *x.get(cur_idx).unwrap().unbox();
                let y1 = *y.get(cur_idx).unwrap().unbox();
                output.append(x1 - y1);
                cur_idx = cur_idx + 1;
            };
        },
        Operations::MULTIPLICATION(()) => {
            loop {
                if (cur_idx >= x_len) {
                    break ();
                }
                let x1 = *x.get(cur_idx).unwrap().unbox();
                let y1 = *y.get(cur_idx).unwrap().unbox();
                output.append(x1 * y1);
                cur_idx = cur_idx + 1;
            };
        },
    }
    output.span()
}

/// Fills an array with one `value`
fn fill_1d(arr_len: u32, value: u128) -> Array<u128> {
    let mut cur_idx = 0;
    let mut output = ArrayTrait::new();
    loop {
        if (cur_idx >= arr_len) {
            break ();
        }
        output.append(value);
        cur_idx = cur_idx + 1;
    };
    output
}
