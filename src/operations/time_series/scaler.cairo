use core::traits::TryInto;
use pragma::operations::time_series::structs::TickElem;
use array::{ArrayTrait, SpanTrait};
use alexandria_math::signed_integers::i129;
use zeroable::Zeroable;
use traits::Into;
use option::OptionTrait;
use box::BoxTrait;
use debug::PrintTrait;

use cubit::types::fixed::{FixedTrait, Fixed, FixedPrint, ONE_u128};

fn calculate_slope(x1: Fixed, x2: Fixed, y1: Fixed, y2: Fixed) -> Fixed {
    (y2 - y1) / (x2 - x1)
}

/// Scales an array of `TickElem` by returning an array of `TickElem` with `num_intervals` elements
/// Takes a start and end tick as an input.
fn scale_data(
    start_tick: u64, end_tick: u64, tick_array: Span<TickElem>, num_intervals: u32
) -> Array<TickElem> {
    let interval = (end_tick - start_tick) / (num_intervals.into() - 1);
    let mut output: Array<TickElem> = ArrayTrait::new();

    let mut cur_index: u32 = 0;

    loop {
        if cur_index == num_intervals {
            break ();
        }

        let mut tick: u64 = 0;
        if cur_index == num_intervals - 1 {
            tick = end_tick;
        } else {
            let conv_cur_idx: felt252 = cur_index.into();
            tick = start_tick + (conv_cur_idx.try_into().unwrap() * interval);
        }

        //retrieve the index of the tick that is closest to the cur_position
        let (idx, _before, _after) = get_bounded_tick_idx(tick, 0, tick_array);

        if *tick_array.at(idx).tick == tick {
            let unscaled = FixedTrait::new(
                mag: (*tick_array.at(idx).value.mag / ONE_u128),
                sign: (*tick_array.at(idx).value.sign)
            );
            output.append(TickElem { tick, value: unscaled });
            cur_index += 1;
            continue;
        }

        let mut slope: Fixed = FixedTrait::from_unscaled_felt(0);

        if _after {
            //if _after is true, the cur_position is among in the tick_array
            let z = tick_array.len() - 1;
            slope =
                calculate_slope(
                    FixedTrait::from_unscaled_felt((*tick_array.at(z - 1).tick).into()),
                    FixedTrait::from_unscaled_felt((*tick_array.at(z).tick).into()),
                    *tick_array.at(z - 1).value,
                    *tick_array.at(z).value
                );
        } else {
            let x1 = FixedTrait::from_unscaled_felt((*tick_array.at(idx).tick).into());
            let x2 = FixedTrait::from_unscaled_felt((*tick_array.at(idx + 1).tick).into());
            let y1 = *tick_array.at(idx).value;
            let y2 = *tick_array.at(idx + 1).value;
            slope = calculate_slope(x1, x2, y1, y2);
        }

        let offset = *tick_array.at(idx).value
            - (slope * FixedTrait::from_unscaled_felt((*tick_array.at(idx).tick).into()));

        let z = slope * FixedTrait::from_unscaled_felt(tick.into()) + offset;
        let new_z = FixedTrait::new(mag: z.mag / ONE_u128, sign: z.sign);
        output.append(TickElem { tick, value: new_z });

        cur_index += 1;
    };

    output
}

fn get_bounded_tick_idx(
    //This function returns the index of the tick that is closest to the cur_position, and a couple of boolean, which indicates, if the cur_position is before the index or after. 
    cur_position: u64, cur_index: u32, tick_array: Span<TickElem>
) -> (u32, bool, bool) {
    //the cur_position is after the tick indicated by cur_index
    if cur_index == tick_array.len() {
        return (cur_index - 1, false, true);
    }

    //the cur_position is after the tick indicated by cur_index
    if cur_index == tick_array.len() - 1 {
        return (tick_array.len() - 1, false, true);
    }

    let _is_before_start = cur_position < *tick_array.at(0).tick;
    let _is_zero = cur_position == 0;
    //the cur_position is before the tick indicated by cur_index
    if _is_before_start && _is_zero {
        return (0, true, false);
    }
    let cur_tick: u64 = *tick_array.at(cur_index).tick;
    let next_tick: u64 = *tick_array.at(cur_index + 1).tick;
    if cur_tick <= cur_position && cur_position <= next_tick {
        return (cur_index, false, false);
    }

    return get_bounded_tick_idx(cur_position, cur_index + 1, tick_array);
}


#[test]
#[available_gas(10000000000)]
fn test_scaler() {
    let mut tick_array: Array<TickElem> = ArrayTrait::new();
    tick_array.append(TickElem { tick: 100, value: FixedTrait::from_unscaled_felt(2558) });
    tick_array.append(TickElem { tick: 204, value: FixedTrait::from_unscaled_felt(5791) });
    tick_array.append(TickElem { tick: 305, value: FixedTrait::from_unscaled_felt(3717) });

    let scaled_data = scale_data(0, 300, tick_array.span(), 4);
    assert(*scaled_data.at(0).tick == 0, 'wrong tick(0)');
    assert(*scaled_data.at(0).value.sign == true, 'wrong sign(0)');
    assert(*scaled_data.at(0).value.mag == 550, 'wrong value(0)');
    assert(*scaled_data.at(1).tick == 100, 'wrong tick(1)');
    assert(*scaled_data.at(1).value.mag == 2558, 'wrong value(1)');
    assert(*scaled_data.at(2).tick == 200, 'wrong tick(2)');
    assert(*scaled_data.at(2).value.mag == 5666, 'wrong value(2)');
    assert(*scaled_data.at(3).tick == 300, 'wrong tick(3)');
    assert(*scaled_data.at(3).value.mag == 3819, 'wrong value(3)');
}
