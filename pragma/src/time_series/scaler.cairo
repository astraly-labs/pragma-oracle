use pragma::time_series::structs::TickElem;
use array::ArrayTrait;
use alexandria_math::math::signed_integers::i129;
use zeroable::Zeroable;

fn calculate_slope(x1: i129, x2: i129, y1: i129, y2: i129) -> i129 {
    (y2 - y1) / (x2 - x1)
}

fn scale_data(
    start_tick: u32, end_tick: u32, tick_array: @Array<TickElem>, num_intervals: u32
) -> Array<TickElem> {
    let interval = (end_tick - start_tick) / (num_intervals - 1);
    let mut output: Array<TickElem> = ArrayTrait::new();

    let mut cur_index: u32 = 0;
    let mut index: u32 = 0;

    loop {
        if cur_index == num_intervals {
            break ();
        }

        let mut tick: u32 = 0;
        if cur_index == num_intervals - 1 {
            tick = end_tick;
        } else {
            tick = start_tick + (cur_index * interval);
        }

        let (idx, _before, _after) = get_bounded_tick_idx(tick, index, tick_array);

        if *tick_array[idx].tick == tick {
            output.append(*tick_array[idx]);
            continue;
        }

        let mut slope: i129 = i129 { inner: 0_u128, sign: false };
        if _after {
            let z = tick_array.len() - 1;
            slope =
                calculate_slope(
                    tick_array[z - 1].tick,
                    tick_array[z].tick,
                    tick_array[z - 1].value,
                    tick_array[z].value
                );
        } else {
            let x1 = tick_array[idx].tick;
            let x2 = tick_array[idx + 1].tick;
            let y1 = tick_array[idx].value;
            let y2 = tick_array[idx + 1].value;
            slope = calculate_slope(x1, x2, y1, y2);
        }

        let offset = tick_array[index].value - (slope * tick_array[index].tick);
        let z = slope * tick + offset;

        output.append(TickElem { tick, value: z });

        cur_index += 1;
        index = idx;
    };

    output
}

fn get_bounded_tick_idx(
    cur_position: u32, cur_index: u32, tick_array: @Array<TickElem>
) -> (u32, bool, bool) {
    if cur_index == tick_array.len() {
        return (cur_index - 1, false, true);
    }

    if cur_index == tick_array.len() - 1 {
        return (tick_array.len() - 1, false, true);
    }

    let _is_before_start = cur_position < *tick_array[0].tick;
    let _is_zero = cur_position == 0;
    if _is_before_start & _is_zero {
        return (0, true, false);
    }

    if *tick_array[cur_index].tick <= cur_position & cur_position <= *tick_array[cur_index
        + 1].tick {
        return (cur_index, false, false);
    }

    return get_bounded_tick_idx(cur_position, cur_index + 1, tick_array);
}
