use pragma::operations::time_series::structs::{TickElem};

use cubit::f128::types::fixed::{
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
    SUBTRACTION: (),
    MULTIPLICATION: (),
}

/// Returns an array of `u128` from `TickElem` array
fn extract_value(mut tick_arr: Span<TickElem>) -> Array<Fixed> {
    let mut output = ArrayTrait::<Fixed>::new();
    loop {
        match tick_arr.pop_front() {
            Option::Some(cur_val) => {
                output.append(*cur_val.value);
            },
            Option::None(_) => {
                break ();
            }
        };
    };
    output
}

/// Sum the values of an array of `TickElem`
fn sum_tick_array(mut tick_arr: Span<TickElem>) -> u128 {
    let mut output = 0;
    loop {
        match tick_arr.pop_front() {
            Option::Some(cur_val) => {
                output += *cur_val.value.mag;
            },
            Option::None(_) => {
                break ();
            }
        };
    };

    output
}

/// Sum the elements of an array of `u128`
fn sum_array(mut tick_arr: Span<Fixed>) -> u128 {
    let mut output: u128 = 0;

    loop {
        match tick_arr.pop_front() {
            Option::Some(cur_val) => {
                if (*cur_val.sign == false) {
                    output = output + (*cur_val).mag;
                } else {
                    panic_with_felt252('Square operation failed')
                }
            },
            Option::None(_) => {
                break ();
            }
        };
    };
    output
}

/// Computes the mean of a `TickElem` array
fn mean(tick_arr: Span<TickElem>) -> u128 {
    let sum_ = sum_tick_array(tick_arr);
    sum_ / tick_arr.len().into()
}

/// Computes the variance of a `TickElem` array
fn variance(tick_arr: Span<TickElem>) -> u128 {
    let arr_ = extract_value(tick_arr);

    let arr_len = arr_.len();
    let mean_ = mean(tick_arr);
    let tick_arr_len = tick_arr.len();
    let diff_arr = pairwise_1D_sub(arr_len, arr_.span(), FixedTrait::new(mag: mean_, sign: false));

    let diff_squared = pairwise_1D_mul(arr_len, diff_arr, diff_arr);

    let sum_ = sum_array(diff_squared);

    let variance_ = sum_ / arr_len.into();

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
    if (arr.len() == 0) {
        return 0;
    }
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
        if (cur_idx >= arr.len()) {
            break ();
        }
        let cur_val = *arr.at(cur_idx);
        let prev_val = *arr.at(cur_idx - 1);
        let cur_value = cur_val.value;
        let prev_value = prev_val.value;
        assert(prev_value.mag > 0, 'failed to compute vol');
        let cur_timestamp = cur_val.tick;
        let prev_timestamp = prev_val.tick;
        assert(cur_timestamp > prev_timestamp, 'failed to compute vol');
        if (prev_timestamp > cur_timestamp) {
            //edge case
            assert(1 == 1, 'failed to compute vol');
            break ();
        }

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

fn twap(arr: Span<TickElem>) -> u128 {
    let mut cur_idx = 1;
    let mut twap = 0;
    let mut sum_p = 0;
    let mut sum_t = 0;
    if (arr.len() == 0) {
        return 0;
    }

    if (arr.len() == 1) {
        return *arr.at(0).value.mag;
    }

    if (*arr.at(0).tick == *arr.at(arr.len() - 1).tick) {
        //we assume that all tick values are the same
        assert(1 == 1, 'failed to compute twap');
        return 0;
    }
    loop {
        if (cur_idx == arr.len()) {
            break ();
        }
        if *arr.at(cur_idx - 1).tick > *arr.at(cur_idx).tick {
            //edge case
            assert(1 == 1, 'failed to compute twap');
            break ();
        }
        let sub_timestamp = *arr.at(cur_idx).tick - *arr.at(cur_idx - 1).tick;

        let weighted_prices = *arr.at(cur_idx - 1).value.mag * sub_timestamp.into();
        sum_p = sum_p + weighted_prices;
        sum_t = sum_t + sub_timestamp;
        cur_idx = cur_idx + 1;
    };
    twap = sum_p / sum_t.into();
    return twap;
}

/// Computes a result array given two arrays and one operation
/// e.g : [1, 2, 3] - 1 = [0,1, 2]
fn pairwise_1D_sub(x_len: u32, x: Span<Fixed>, y: Fixed) -> Span<Fixed> {
    //We assume, for simplicity, that the input arrays (x & y) are arrays of positive elements
    let mut cur_idx: u32 = 0;
    let mut output = ArrayTrait::<Fixed>::new();

    loop {
        if (cur_idx >= x_len) {
            break ();
        }
        let x1 = *x.get(cur_idx).unwrap().unbox();
        if x1 < y {
            output.append(FixedTrait::new(mag: y.mag - x1.mag, sign: true));
        } else {
            output.append(FixedTrait::new(mag: x1.mag - y.mag, sign: false));
        }

        cur_idx = cur_idx + 1;
    };
    output.span()
}

/// Computes a result array given two arrays and one operation
/// e.g : [1, 2, 3] * [1, 2, 3] = [2, 4, 9]
fn pairwise_1D_mul(x_len: u32, x: Span<Fixed>, y: Span<Fixed>) -> Span<Fixed> {
    //We assume, for simplicity, that the input arrays (x & y) are arrays of positive
    let mut cur_idx: u32 = 0;
    let mut output = ArrayTrait::<Fixed>::new();
    loop {
        if (cur_idx >= x_len) {
            break ();
        }
        let x1 = *x.get(cur_idx).unwrap().unbox();
        let y1 = *y.get(cur_idx).unwrap().unbox();
        if x1.sign == y1.sign {
            output.append(FixedTrait::new(mag: x1.mag * y1.mag, sign: false));
        } else {
            output.append(FixedTrait::new(mag: x1.mag * y1.mag, sign: true));
        }
        cur_idx = cur_idx + 1;
    };
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
    let z = pairwise_1D_sub(3, x.span(), FixedTrait::new(mag: 2, sign: false));
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
    let z = pairwise_1D_mul(3, x.span(), y.span());
    assert(*z.at(0).mag == 6, 'wrong value');
    assert(*z.at(0).sign == false, 'wrong value');
    assert(*z.at(1).mag == 6, 'wrong value');
    assert(*z.at(2).mag == 6, 'wrong value');
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

