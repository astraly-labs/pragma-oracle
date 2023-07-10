use pragma::operations::time_series::structs::{TickElem, PAIRWISE_OPERATION};

use cubit::types::fixed::{
    HALF_u128, MAX_u128, ONE_u128, Fixed, FixedInto, FixedTrait, FixedAdd, FixedDiv, FixedMul,
    FixedNeg
};
use array::{ArrayTrait, SpanTrait};
use traits::{Into, TryInto};
use option::OptionTrait;
use debug::PrintTrait;
use box::BoxTrait;

const ONE_YEAR_IN_SECONDS: u128 = 31536000_u128;

#[derive(Copy, Drop)]
enum Operations {
    SUBTRACTION: (),
    MULTIPLICATION: (),
}

/// Returns an array of `u128` from `TickElem` array
fn extract_value(tick_arr: Span<TickElem>) -> Array<Fixed> {
    let mut output = ArrayTrait::<Fixed>::new();
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
        output += cur_val.value.mag;
        cur_idx = cur_idx + 1;
    };
    output
}

/// Sum the elements of an array of `u128`
fn sum_array(tick_arr: Span<Fixed>) -> u128 {
    let mut output: u128 = 0;
    let mut cur_idx = 0;
    loop {
        if (cur_idx >= tick_arr.len()) {
            break ();
        }
        let cur_val = *tick_arr.get(cur_idx).unwrap().unbox();
        if (cur_val.sign == false) {
            output = output + cur_val.mag;
        } else {
            panic_with_felt252('Square operation failed')
        }
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
    let diff_arr = pairwise_1D(Operations::SUBTRACTION(()), arr_len, arr_.span(), mean_arr.span());

    let diff_squared = pairwise_1D(Operations::MULTIPLICATION(()), arr_len, diff_arr, diff_arr);

    let sum_ = sum_array(diff_squared);
    let felt_arr_len: felt252 = arr_len.into();
    let variance_ = sum_ / (felt_arr_len.try_into().unwrap());

    return variance_;
}

/// Computes the standard deviation of a `TickElem` array
/// Calls `variance` and computes the squared root
fn standard_deviation(arr: Span<TickElem>) -> u128 {
    let variance_ = variance(arr);
    let fixed_variance_ = FixedTrait::new(variance_ * ONE_u128, false);
    let std = FixedTrait::sqrt(fixed_variance_);
    std.mag / ONE_u128
}

/// Compute the volatility of a `TickElem` array
fn volatility(arr: Span<TickElem>) -> u128 {
    let _volatility_sum = _sum_volatility(arr);
    let arr_len: u128 = arr.len().into() * ONE_u128;
    let fixed_len = FixedTrait::new(arr_len, false);
    let _volatility = _volatility_sum / fixed_len;
    let sqrt_vol = FixedTrait::sqrt(_volatility);
    return (sqrt_vol.mag * 100000000 / ONE_u128);
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
        let prev_value = prev_val.value;
        let cur_timestamp = cur_val.tick;
        let prev_timestamp = prev_val.tick;
        let numerator_value = FixedTrait::ln(cur_value / prev_value);
        let numerator = numerator_value.pow(FixedTrait::new(2 * ONE_u128, false));
        let denominator = FixedTrait::new((cur_timestamp - prev_timestamp).into(), false)
            / FixedTrait::new(ONE_YEAR_IN_SECONDS, false);
        let fraction_ = numerator / denominator;
        sum = sum + fraction_;
        cur_idx = cur_idx + 1;
    };
    sum
}

/// Computes a result array given two arrays and one operation
/// e.g : [1, 2, 3] + [1, 2, 3] = [2, 4, 6]
fn pairwise_1D(operation: Operations, x_len: u32, x: Span<Fixed>, y: Span<Fixed>) -> Span<Fixed> {
    //We assume, for simplicity, that the input arrays (x & y) are arrays of positive elements
    let mut cur_idx: u32 = 0;
    let mut output = ArrayTrait::<Fixed>::new();
    match operation {
        Operations::SUBTRACTION(()) => {
            loop {
                if (cur_idx >= x_len) {
                    break ();
                }
                let x1 = *x.get(cur_idx).unwrap().unbox();
                let y1 = *y.get(cur_idx).unwrap().unbox();
                if x1 < y1 {
                    output.append(FixedTrait::new(mag: y1.mag - x1.mag, sign: true));
                } else {
                    output.append(FixedTrait::new(mag: x1.mag - y1.mag, sign: false));
                }

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
                output.append(FixedTrait::new(mag: x1.mag * y1.mag, sign: false));
                cur_idx = cur_idx + 1;
            };
        },
    }
    output.span()
}

/// Fills an array with one `value`
fn fill_1d(arr_len: u32, value: u128) -> Array<Fixed> {
    let mut cur_idx = 0;
    let mut output = ArrayTrait::new();
    loop {
        if (cur_idx >= arr_len) {
            break ();
        }
        output.append(FixedTrait::new(mag: value, sign: false));
        cur_idx = cur_idx + 1;
    };
    output
}


//----------------------

//Tests

#[test]
#[available_gas(1000000000)]
fn test_utils() {
    //extract_value
    let mut array = ArrayTrait::<TickElem>::new();
    array.append(TickElem { tick: 1, value: FixedTrait::from_felt(1) });
    array.append(TickElem { tick: 2, value: FixedTrait::from_felt(2) });
    array.append(TickElem { tick: 3, value: FixedTrait::from_felt(3) });
    array.append(TickElem { tick: 4, value: FixedTrait::from_felt(4) });
    let new_arr = extract_value(array.span());
    assert(new_arr.len() == 4, 'wrong len');

    //sum_tick_array
    assert(*new_arr.at(0).mag == 1, 'wrong value');
    assert(*new_arr.at(1).mag == 2, 'wrong value');
    assert(*new_arr.at(2).mag == 3, 'wrong value');
    assert(*new_arr.at(3).mag == 4, 'wrong value');
    let sum_tick = sum_tick_array(array.span());
    assert(sum_tick == 10, 'wrong sum');

    //sum_array
    let mut fixed_arr = ArrayTrait::<Fixed>::new();
    fixed_arr.append(FixedTrait::new(mag: 1, sign: false));
    fixed_arr.append(FixedTrait::new(mag: 2, sign: false));
    fixed_arr.append(FixedTrait::new(mag: 3, sign: false));
    fixed_arr.append(FixedTrait::new(mag: 4, sign: false));
    assert(sum_array(fixed_arr.span()) == 10, 'wrong sum');

    //pairwise_1D
    let x = fill_1d(3, 1);
    let y = fill_1d(3, 2);
    let z = pairwise_1D(Operations::SUBTRACTION(()), 3, x.span(), y.span());
    assert(*z.at(0).mag == 1, 'wrong value');
    assert(*z.at(0).sign == true, 'wrong value');
    assert(*z.at(1).mag == 1, 'wrong value');
    assert(*z.at(2).mag == 1, 'wrong value');

    //fill_1d
    let arr = fill_1d(3, 1);
    assert(arr.len() == 3, 'wrong len');
    assert(*arr.at(0).mag == 1, 'wrong value');
    assert(*arr.at(1).mag == 1, 'wrong value');
    assert(*arr.at(2).mag == 1, 'wrong value');

    //pairwise_1D
    let x = fill_1d(3, 3);
    let y = fill_1d(3, 2);
    let z = pairwise_1D(Operations::SUBTRACTION(()), 3, x.span(), y.span());
    assert(*z.at(0).mag == 1, 'wrong value');
    assert(*z.at(0).sign == false, 'wrong value');
    assert(*z.at(1).mag == 1, 'wrong value');
    assert(*z.at(2).mag == 1, 'wrong value');
}


#[test]
#[available_gas(1000000000)]
fn test_metrics() {
    //mean
    let mut array = ArrayTrait::<TickElem>::new();
    array.append(TickElem { tick: 1, value: FixedTrait::from_felt(10) });
    array.append(TickElem { tick: 2, value: FixedTrait::from_felt(20) });
    array.append(TickElem { tick: 3, value: FixedTrait::from_felt(30) });
    array.append(TickElem { tick: 4, value: FixedTrait::from_felt(40) });
    assert(mean(array.span()) == 25, 'wrong mean');

    //variance
    let mut array = ArrayTrait::<TickElem>::new();
    array.append(TickElem { tick: 1, value: FixedTrait::from_felt(10) });
    array.append(TickElem { tick: 2, value: FixedTrait::from_felt(20) });
    array.append(TickElem { tick: 3, value: FixedTrait::from_felt(30) });
    array.append(TickElem { tick: 4, value: FixedTrait::from_felt(40) });
    array.append(TickElem { tick: 5, value: FixedTrait::from_felt(50) });
    assert(variance(array.span()) == 200, 'wrong variance');

    //standard deviation
    let mut array = ArrayTrait::<TickElem>::new();
    array.append(TickElem { tick: 1, value: FixedTrait::from_felt(10) });
    array.append(TickElem { tick: 2, value: FixedTrait::from_felt(20) });
    array.append(TickElem { tick: 3, value: FixedTrait::from_felt(30) });
    array.append(TickElem { tick: 4, value: FixedTrait::from_felt(40) });
    array.append(TickElem { tick: 5, value: FixedTrait::from_felt(50) });
    assert(standard_deviation(array.span()) == 14, 'wrong standard deviation');
    //volatility
    let mut array = ArrayTrait::<TickElem>::new();
    array.append(TickElem { tick: 1640995200, value: FixedTrait::from_felt(47686) });
    array.append(TickElem { tick: 1641081600, value: FixedTrait::from_felt(47345) });
    array.append(TickElem { tick: 1641168000, value: FixedTrait::from_felt(46458) });
    array.append(TickElem { tick: 1641254400, value: FixedTrait::from_felt(45897) });
    array.append(TickElem { tick: 1641340800, value: FixedTrait::from_felt(43569) });
    let value = volatility(array.span());
    assert(volatility(array.span()) == 48830960, 'wrong volatility'); //10^8
}
