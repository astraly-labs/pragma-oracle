#[contract]
mod Entry {
    use array::ArrayTrait;
    //
    // Helpers
    //

    // @notice Aggregates entries for a specific value
    // @param entries_len: length of entries array
    // @param entries: pointer to first Entry in array
    // @return value: the aggregation value
    fn aggregate_entries<T>(entries: Array<T>) -> felt252 {
        let value = entries_median(entries);
        value
    }

    // @notice returns the max timestamp of an entries array
    // @param entries: pointer to first Entry in array
    // @return last_updated_timestamp: the latest timestamp from the array
    fn aggregate_timestamps_max<
        T, impl TPartialOrd: PartialOrd<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>
    >(
        entries: @Array<T>
    ) -> felt {
        let mut max_timestamp = *entries[0_usize].timestamp;
        let mut index = 1_usize;
        loop {
            if index >= entries.len() {
                break max_timestamp;
            }
            if *entries[index].timestamp > max_timestamp {
                max_timestamp = *entries[index].timestamp;
            }
            index = index + 1;
        }
    }
    // @notice returns the median value from an entries array
    // @param entries_len: length of entries array
    // @param entries: pointer to first Entry in array
    // @return value: the median value from the array of entries

    fn entries_median<T>(entries: Array<T>) -> felt252 {
        let sorted_entries = entries_sort(entries);
        let entries_len = sorted_entries.len();
        assert(entries_len > 0_usize, 'entries must not be empty');
        let is_even = 1 - entries_len % 2_usize;
        if (is_even == 0) {
            let median_idx = (entries_len + 1) / 2_usize;
            let median_entry = sorted_entries[median_idx];
            median_entry.value
        } else {
            let median_idx_1 = entries_len / 2_usize;
            let median_idx_2 = median_idx_1 - 1_usize;
            let median_entry_1 = sorted_entries[median_idx_1];
            let median_entry_2 = sorted_entries[median_idx_2];
            (median_entry_1.value + median_entry_2.value) / 2_usize
        }
    }
}

