use pragma::operations::time_series::structs::{TickElem, PAIRWISE_OPERATION};

use cubit::types::fixed::{FixedTrait, Fixed};
use cubit::math::core::{sqrt, div, ln, add};
use array::{ArrayTrait, SpanTrait};
use traits::{Into, TryInto};
use option::OptionTrait;
use box::BoxTrait;
const ONE_YEAR_IN_SECONDS : u128 = 31536000_u128;
#[derive(Copy, Drop)]
enum Operations {
    SUBSTRACTION: (),
    MULTIPLICATION: (),
}


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


fn mean(tick_arr: Span<TickElem>) -> u128 {
    let sum_ = sum_tick_array(tick_arr);
    let felt_count: felt252 = tick_arr.len().into();
    let count: u128 = felt_count.try_into().unwrap();
    sum_ / count
}

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

fn standard_deviation(arr: Span<TickElem>) -> Fixed {
    let variance_ = variance(arr);
    let fixed_variance_ = FixedTrait::new(variance_, false);
    let std = sqrt(fixed_variance_);
    std
}

fn volatility(arr: Span<TickElem>) -> Fixed {
    let _volatility_sum = _sum_volatility(arr);
    let arr_len = arr.len();
    let fixed_len = FixedTrait::new(arr_len.into(), false);
    let _volatility = _volatility_sum /fixed_len;
    let sqrt_vol = sqrt(_volatility);
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

        let numerator_value = ln(div(fixed_cur_value, fixed_prev_value));
        let numerator = numerator_value.pow(FixedTrait::new(2, false));
        let denominator = div(
            FixedTrait::new((cur_timestamp - prev_timestamp).into(), false),
            FixedTrait::new(ONE_YEAR_IN_SECONDS, false)
        );
        let fraction_ = div(numerator, denominator);
        sum = add(sum, fraction_);
        cur_idx = cur_idx + 1;
    };
    sum
}

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

