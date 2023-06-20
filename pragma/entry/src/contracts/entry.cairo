#[contract]
mod Entry {
    use array::ArrayTrait;
    use entry::contracts::structs::{BaseEntry, AggregationMode};
    use pragma::sorting::merge_sort::merge;
    use entry::contracts::structs::{SpotEntry, FutureEntry};
    use traits::TryInto;
    use traits::Into;
    use option::OptionTrait;

    trait hasBaseEntry<T> {
        fn get_base_entry(self: @T) -> BaseEntry;
        fn get_base_timestamp(self: @T) -> u256;
    }

    impl ShasBaseEntryImpl of hasBaseEntry<SpotEntry> {
        fn get_base_entry(self: @SpotEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @SpotEntry) -> u256 {
            (*self).base.timestamp
        }
    }
    impl FhasBaseEntryImpl of hasBaseEntry<FutureEntry> {
        fn get_base_entry(self: @FutureEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @FutureEntry) -> u256 {
            (*self).base.timestamp
        }
    }

    trait hasPrice<T> {
        fn get_price(self: @T) -> u256;
    }

    impl ShasPriceImpl of hasPrice<SpotEntry> {
        fn get_price(self: @SpotEntry) -> u256 {
            (*self).price
        }
    }
    impl FhasPriceImpl of hasPrice<FutureEntry> {
        fn get_price(self: @FutureEntry) -> u256 {
            (*self).price
        }
    }

    //
    // Helpers
    //

    // @notice Aggregates entries for a specific value
    // @param entries_len: length of entries array
    // @param entries: pointer to first Entry in array
    // @return value: the aggregation value
    fn aggregate_entries<
        T,
        impl ThasPrice: hasPrice<T>, // impl TPartialOrd: PartialOrd<T>,
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>
    >(
        entries: @Array<T>, aggregation_mode: AggregationMode
    ) -> u256 {
        match aggregation_mode {
            AggregationMode::Median(()) => {
                let value: u256 = entries_median(entries);
                value
            }
        }
    }


    // @notice returns the max timestamp of an entries array
    // @param entries: pointer to first Entry in array
    // @return last_updated_timestamp: the latest timestamp from the array
    fn aggregate_timestamps_max<
        T,
        impl THasBaseEntry: hasBaseEntry<T>, // impl TPartialOrd: PartialOrd<T>,
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>
    >(
        entries: @Array<T>
    ) -> u256 {
        let mut max_timestamp: u256 = (*entries[0_usize]).get_base_timestamp();
        let mut index = 1_usize;
        loop {
            if index >= entries.len() {
                break max_timestamp;
            }
            if (*entries[index]).get_base_timestamp() > max_timestamp {
                max_timestamp = (*entries[index]).get_base_timestamp();
            }
            index = index + 1;
        }
    }
    // @notice returns the median value from an entries array
    // @param entries_len: length of entries array
    // @param entries: pointer to first Entry in array
    // @return value: the median value from the array of entries

    fn entries_median<
        T,
        impl ThasPrice: hasPrice<T>,
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>,
        impl TPartialOrd: PartialOrd<T>
    >(
        entries: @Array<T>
    ) -> u256 {
        let mut sorted_entries = ArrayTrait::<T>::new();
        sorted_entries = merge(entries);
        let entries_len = sorted_entries.len();
        assert(entries_len > 0_usize, 'entries must not be empty');
        let is_even = 1 - entries_len % 2_usize;
        if (is_even == 0) {
            let median_idx = (entries_len + 1) / 2;
            let median_entry = *sorted_entries.at(median_idx);
            median_entry.get_price()
        } else {
            let median_idx_1 = entries_len / 2;
            let median_idx_2 = median_idx_1 - 1;
            let median_entry_1 = (*sorted_entries.at(median_idx_1)).get_price();
            let median_entry_2 = (*sorted_entries.at(median_idx_2)).get_price();
            (median_entry_1 + median_entry_2) / (2.into())
        }
    }
    fn entries_mean<T, impl ThasPrice: hasPrice<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>>(
        entries: @Array<T>
    ) -> u256 {
        let mut sum: u256 = 0.into();
        let mut index = 0_usize;
        let entries_len: u32 = entries.len();
        let entries_len_u256 = u256 { low: entries_len.into(), high: 0_u128 };
        loop {
            if index >= entries.len() {
                break (sum / entries_len_u256);
            }
            sum = sum + (*entries.at(index)).get_price();
            index = index + 1;
        }
    }
}

