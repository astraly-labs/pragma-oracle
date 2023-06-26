use array::ArrayTrait;
use entry::contracts::structs::{BaseEntry, AggregationMode};
use pragma::sorting::merge_sort::merge;
use entry::contracts::structs::{SpotEntry, FutureEntry};
use traits::TryInto;
use traits::Into;
use option::OptionTrait;

trait HasPrice<T> {
    fn get_price(self: @T) -> u256;
}

impl SHasPriceImpl of HasPrice<SpotEntry> {
    fn get_price(self: @SpotEntry) -> u256 {
        (*self).price
    }
}
impl FHasPriceImpl of HasPrice<FutureEntry> {
    fn get_price(self: @FutureEntry) -> u256 {
        (*self).price
    }
}

mod Entry {
    use array::ArrayTrait;
    use entry::contracts::structs::{BaseEntry, AggregationMode};
    use pragma::sorting::merge_sort::merge;
    use entry::contracts::structs::{SpotEntry, FutureEntry};
    use traits::TryInto;
    use traits::Into;
    use option::OptionTrait;
    use super::HasPrice;

    trait hasBaseEntry<T> {
        fn get_base_entry(self: @T) -> BaseEntry;
        fn get_base_timestamp(self: @T) -> u64;
    }

    impl ShasBaseEntryImpl of hasBaseEntry<SpotEntry> {
        fn get_base_entry(self: @SpotEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @SpotEntry) -> u64 {
            (*self).base.timestamp
        }
    }
    impl FhasBaseEntryImpl of hasBaseEntry<FutureEntry> {
        fn get_base_entry(self: @FutureEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @FutureEntry) -> u64 {
            (*self).base.timestamp
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
        impl THasPrice: HasPrice<T>,
        impl TPartialOrd: PartialOrd<T>,
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>,
    >(
        entries: @Array<T>, aggregation_mode: AggregationMode
    ) -> u256 {
        match aggregation_mode {
            AggregationMode::Median(()) => {
                let value: u256 = entries_median(entries);
                value
            },
            AggregationMode::Error(()) => {
                panic_with_felt252('Wrong aggregation mode');
                u256 { low: 0_u128, high: 0_u128 }
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
    ) -> u64 {
        let mut max_timestamp: u64 = (*entries[0_usize]).get_base_timestamp();
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
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>,
        impl TPartialOrd: PartialOrd<T>,
        impl THasPrice: HasPrice<T>,
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
    fn entries_mean<T, impl THasPrice: HasPrice<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>>(
        entries: @Array<T>
    ) -> u256 {
        let mut sum: u256 = 0.into();
        let mut index: u32 = 0;
        let entries_len: u32 = entries.len();
        loop {
            if index >= entries.len() {
                break (sum / u256 { low: entries_len.into(), high: 0_u128 });
            }
            sum = sum + (*entries.at(index)).get_price();
            index = index + 1;
        }
    }
}

