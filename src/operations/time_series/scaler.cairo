use core::traits::TryInto;
use pragma::operations::time_series::structs::TickElem;
use array::{ArrayTrait, SpanTrait};
use alexandria_math::signed_integers::i129;
use zeroable::Zeroable;
use traits::Into;
use option::OptionTrait;
use box::BoxTrait;

fn calculate_slope(x1: i129, x2: i129, y1: i129, y2: i129) -> i129 {
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
    let mut index: u32 = 0;

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

        let (idx, _before, _after) = get_bounded_tick_idx(tick, index, tick_array);

        if *tick_array.get(idx).unwrap().unbox().tick == tick {
            output.append(*tick_array.get(idx).unwrap().unbox());
            continue;
        }

        let mut slope: i129 = i129 { inner: 0_u128, sign: false };
        if _after {
            let z = tick_array.len() - 1;
            slope =
                calculate_slope(
                    i129 {
                        inner: (*tick_array.get(z - 1).unwrap().unbox().tick).into(), sign: false
                    },
                    i129 { inner: (*tick_array.get(z).unwrap().unbox().tick).into(), sign: false },
                    i129 { inner: (*tick_array.get(z - 1).unwrap().unbox().value), sign: false },
                    i129 { inner: (*tick_array.get(z).unwrap().unbox().value), sign: false }
                );
        } else {
            let x1 = i129 {
                inner: (*tick_array.get(idx).unwrap().unbox().tick).into(), sign: false
            };
            let x2 = i129 {
                inner: (*tick_array.get(idx + 1).unwrap().unbox().tick).into(), sign: false
            };
            let y1 = i129 { inner: (*tick_array.get(idx).unwrap().unbox().value), sign: false };
            let y2 = i129 { inner: (*tick_array.get(idx + 1).unwrap().unbox().value), sign: false };
            slope = calculate_slope(x1, x2, y1, y2);
        }

        let offset = i129 {
            inner: (*tick_array.get(index).unwrap().unbox().value), sign: false
        }
            - (slope * i129 {
                inner: (*tick_array.get(index).unwrap().unbox().tick).into(), sign: false
            });
        let z = slope * i129 { inner: tick.into(), sign: false } + offset;

        output.append(TickElem { tick, value: z.inner });

        cur_index += 1;
        index = idx;
    };

    output
}

fn get_bounded_tick_idx(
    cur_position: u64, cur_index: u32, tick_array: Span<TickElem>
) -> (u32, bool, bool) {
    if cur_index == tick_array.len() {
        return (cur_index - 1, false, true);
    }

    if cur_index == tick_array.len() - 1 {
        return (tick_array.len() - 1, false, true);
    }

    let _is_before_start = cur_position < *tick_array.get(0).unwrap().unbox().tick;
    let _is_zero = cur_position == 0;
    if _is_before_start & _is_zero {
        return (0, true, false);
    }
    let cur_tick: u64 = *tick_array.get(cur_index).unwrap().unbox().tick;
    let next_tick: u64 = *tick_array.get(cur_index + 1).unwrap().unbox().tick;
    if cur_tick <= cur_position && cur_position <= next_tick {
        return (cur_index, false, false);
    }

    return get_bounded_tick_idx(cur_position, cur_index + 1, tick_array);
}
