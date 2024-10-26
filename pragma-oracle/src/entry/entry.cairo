use array::{ArrayTrait, SpanTrait};
use pragma::entry::structs::{BaseEntry, AggregationMode};
use pragma::operations::sorting::merge_sort::merge;
use pragma::entry::structs::{
    SpotEntry, FutureEntry, GenericEntry, PragmaPricesResponse, HasPrice, HasBaseEntry,
};
use traits::TryInto;
use traits::Into;
use option::OptionTrait;


mod Entry {
    use super::{
        ArrayTrait, BaseEntry, AggregationMode, merge, SpotEntry, FutureEntry, GenericEntry,
        TryInto, Into, OptionTrait, HasPrice, SpanTrait, PragmaPricesResponse, HasBaseEntry,
    };


    //
    // Helpers
    //

    // @notice Aggregates entries for a specific value
    // @param entries_len: length of entries array
    // @param entries: pointer to first Entry in array
    // @return value: the aggregation value
    fn aggregate_entries<
        T,
        impl THasPrice: HasPrice<T>, // impl TPartialOrd: PartialOrd<T>,
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>,
    >(
        entries: Span<T>, aggregation_mode: AggregationMode
    ) -> u128 {
        if (entries.len() == 0) {
            return 0;
        }
        match aggregation_mode {
            AggregationMode::Median(()) => {
                let value: u128 = entries_median(entries);
                value
            },
            AggregationMode::Mean(()) => {
                let value: u128 = entries_mean(entries);
                value
            },
            AggregationMode::Error(()) => {
                panic_with_felt252('Wrong aggregation mode');
                0
            }
        }
    }


    // @notice returns the max timestamp of an entries array
    // @param entries: pointer to first Entry in array
    // @return last_updated_timestamp: the latest timestamp from the array
    fn aggregate_timestamps_max<
        T,
        impl THasBaseEntry: HasBaseEntry<T>, // impl TPartialOrd: PartialOrd<T>,
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>
    >(
        mut entries: Span<T>
    ) -> u64 {
        if (entries.len() == 0) {
            return 0;
        }
        let mut max_timestamp: u64 = (*entries[0_usize]).get_base_timestamp();
        let mut index = 1_usize;
        loop {
            match entries.pop_front() {
                Option::Some(entry) => {
                    if (*entry).get_base_timestamp() > max_timestamp {
                        max_timestamp = (*entry).get_base_timestamp();
                    }
                },
                Option::None(_) => {
                    break max_timestamp;
                }
            };
        }
    }

    //

    // @notice returns the median value from an entries array
    // @param entries: array of entries to aggregate
    // @return value: the median value from the array of entries
    fn entries_median<
        T,
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>, // impl TPartialOrd: PartialOrd<T>,
        impl THasPrice: HasPrice<T>,
    >(
        entries: Span<T>
    ) -> u128 {
        let sorted_entries = merge(entries);
        let entries_len = sorted_entries.len();
        assert(entries_len > 0_usize, 'entries must not be empty');
        let is_even = 1 - entries_len % 2_usize;
        if (is_even == 0) {
            let median_idx = (entries_len) / 2;
            let median_entry = *sorted_entries.at(median_idx);
            median_entry.get_price()
        } else {
            let median_idx_1 = entries_len / 2;
            let median_idx_2 = median_idx_1 - 1;
            let median_entry_1 = (*sorted_entries.at(median_idx_1)).get_price();
            let median_entry_2 = (*sorted_entries.at(median_idx_2)).get_price();
            (median_entry_1 + median_entry_2) / (2)
        }
    }


    // @notice Returns the mean value from an entries array
    // @param entries: entries array to aggregate
    // @return value: the mean value from the array of entries
    fn entries_mean<T, impl THasPrice: HasPrice<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>>(
        mut entries: Span<T>
    ) -> u128 {
        let mut sum: u128 = 0;
        let mut index: u32 = 0;
        let entries_len: u32 = entries.len();
        loop {
            match entries.pop_front() {
                Option::Some(entry) => {
                    sum += (*entry).get_price();
                },
                Option::None(_) => {
                    break sum / entries_len.into();
                }
            };
        }
    }

    fn compute_median(entry_array: Array<u128>) -> u128 {
        let sorted_array = alexandria_sorting::merge_sort::merge(entry_array);
        let entries_len = sorted_array.len();
        assert(entries_len > 0_usize, 'entries must not be empty');
        let is_even = 1 - entries_len % 2_usize;
        if (is_even == 0) {
            let median_idx = (entries_len) / 2;
            let median_entry = *sorted_array.at(median_idx);
            median_entry
        } else {
            let median_idx_1 = entries_len / 2;
            let median_idx_2 = median_idx_1 - 1;
            let median_entry_1 = (*sorted_array.at(median_idx_1));
            let median_entry_2 = (*sorted_array.at(median_idx_2));
            (median_entry_1 + median_entry_2) / 2
        }
    }
}


//-----------------------------------------------
// Tests

#[test]
#[available_gas(100000000)]
fn test_aggregate_entries_median() {
    let mut entries = ArrayTrait::<SpotEntry>::new();
    let entry_1 = SpotEntry {
        base: BaseEntry { timestamp: 1000000, source: 1, publisher: 1001 },
        price: 10,
        pair_id: 1,
        volume: 10
    };
    let entry_2 = SpotEntry {
        base: BaseEntry { timestamp: 1000001, source: 1, publisher: 0234 },
        price: 20,
        pair_id: 1,
        volume: 30
    };
    let entry_3 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 30,
        pair_id: 1,
        volume: 30
    };
    let entry_4 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 40,
        pair_id: 1,
        volume: 30
    };
    let entry_5 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 50,
        pair_id: 1,
        volume: 30
    };
    //1 element 
    entries.append(entry_1);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Median(())) == 10,
        'median aggregation failed(1)'
    );

    //2 elements
    entries.append(entry_2);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Median(())) == 15,
        'median aggregation failed(even)'
    );

    //3 elements
    entries.append(entry_3);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Median(())) == 20,
        'median aggregation failed(odd)'
    );

    //4 elements
    entries.append(entry_4);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Median(())) == 25,
        'median aggregation failed(even)'
    );

    //5 elements
    entries.append(entry_5);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Median(())) == 30,
        'median aggregation failed(odd)'
    );

    //FUTURES

    let mut f_entries = ArrayTrait::<FutureEntry>::new();
    let entry_1 = FutureEntry {
        base: BaseEntry { timestamp: 1000000, source: 1, publisher: 1001 },
        price: 10,
        pair_id: 1,
        volume: 10,
        expiration_timestamp: 1111111
    };
    let entry_2 = FutureEntry {
        base: BaseEntry { timestamp: 1000001, source: 1, publisher: 0234 },
        price: 20,
        pair_id: 1,
        volume: 30,
        expiration_timestamp: 1111111
    };
    let entry_3 = FutureEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 30,
        pair_id: 1,
        volume: 30,
        expiration_timestamp: 1111111
    };
    let entry_4 = FutureEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 40,
        pair_id: 1,
        volume: 30,
        expiration_timestamp: 1111111
    };
    let entry_5 = FutureEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 50,
        pair_id: 1,
        volume: 30,
        expiration_timestamp: 1111111
    };
    //1 element 
    f_entries.append(entry_1);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Median(())) == 10,
        'median aggregation failed(1)'
    );
    //2 elements
    f_entries.append(entry_2);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Median(())) == 15,
        'median aggregation failed(even)'
    );

    //3 elements
    f_entries.append(entry_3);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Median(())) == 20,
        'median aggregation failed(odd)'
    );

    //4 elements
    f_entries.append(entry_4);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Median(())) == 25,
        'median aggregation failed(even)'
    );

    //5 elements
    f_entries.append(entry_5);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Median(())) == 30,
        'median aggregation failed(odd)'
    );
}


#[test]
#[available_gas(100000000)]
fn test_aggregate_entries_mean() {
    let mut entries = ArrayTrait::<SpotEntry>::new();
    let entry_1 = SpotEntry {
        base: BaseEntry { timestamp: 1000000, source: 1, publisher: 1001 },
        price: 10,
        pair_id: 1,
        volume: 10
    };
    let entry_2 = SpotEntry {
        base: BaseEntry { timestamp: 1000001, source: 1, publisher: 0234 },
        price: 20,
        pair_id: 1,
        volume: 30
    };
    let entry_3 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 30,
        pair_id: 1,
        volume: 30
    };
    let entry_4 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 40,
        pair_id: 1,
        volume: 30
    };
    let entry_5 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 50,
        pair_id: 1,
        volume: 30
    };
    //1 element 
    entries.append(entry_1);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Mean(())) == 10,
        'Mean aggregation failed(1)'
    );

    //2 elements
    entries.append(entry_2);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Mean(())) == 15,
        'Mean aggregation failed(even)'
    );

    //3 elements
    entries.append(entry_3);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Mean(())) == 20,
        'Mean aggregation failed(odd)'
    );

    //4 elements
    entries.append(entry_4);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Mean(())) == 25,
        'Mean aggregation failed(even)'
    );

    //5 elements
    entries.append(entry_5);
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Mean(())) == 30,
        'Mean aggregation failed(odd)'
    );
    //FUTURES

    let mut f_entries = ArrayTrait::<FutureEntry>::new();
    let entry_1 = FutureEntry {
        base: BaseEntry { timestamp: 1000000, source: 1, publisher: 1001 },
        price: 10,
        pair_id: 1,
        volume: 10,
        expiration_timestamp: 1111111
    };
    let entry_2 = FutureEntry {
        base: BaseEntry { timestamp: 1000001, source: 1, publisher: 0234 },
        price: 20,
        pair_id: 1,
        volume: 30,
        expiration_timestamp: 1111111
    };
    let entry_3 = FutureEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 30,
        pair_id: 1,
        volume: 30,
        expiration_timestamp: 1111111
    };
    let entry_4 = FutureEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 40,
        pair_id: 1,
        volume: 30,
        expiration_timestamp: 1111111
    };
    let entry_5 = FutureEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 50,
        pair_id: 1,
        volume: 30,
        expiration_timestamp: 1111111
    };
    //1 element 
    f_entries.append(entry_1);

    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Mean(())) == 10,
        'median aggregation failed(1)'
    );
    //2 elements
    f_entries.append(entry_2);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Mean(())) == 15,
        'median aggregation failed(even)'
    );

    //3 elements
    f_entries.append(entry_3);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Mean(())) == 20,
        'median aggregation failed(odd)'
    );

    //4 elements
    f_entries.append(entry_4);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Mean(())) == 25,
        'median aggregation failed(even)'
    );

    //5 elements
    f_entries.append(entry_5);
    assert(
        Entry::aggregate_entries(f_entries.span(), AggregationMode::Mean(())) == 30,
        'median aggregation failed(odd)'
    );
}


#[test]
#[available_gas(100000000)]
fn test_aggregate_timestamp_max() {
    let mut entries = ArrayTrait::<SpotEntry>::new();
    let entry_1 = SpotEntry {
        base: BaseEntry { timestamp: 1000000, source: 1, publisher: 1001 },
        price: 10,
        pair_id: 1,
        volume: 10
    };
    let entry_2 = SpotEntry {
        base: BaseEntry { timestamp: 1000001, source: 1, publisher: 0234 },
        price: 20,
        pair_id: 1,
        volume: 30
    };
    let entry_3 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 30,
        pair_id: 1,
        volume: 30
    };
    let entry_4 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 40,
        pair_id: 1,
        volume: 30
    };
    let entry_5 = SpotEntry {
        base: BaseEntry { timestamp: 1003002, source: 1, publisher: 1334 },
        price: 50,
        pair_id: 1,
        volume: 30
    };
    //1 element 
    entries.append(entry_1);
    assert(
        Entry::aggregate_timestamps_max(entries.span()) == 1000000.try_into().unwrap(),
        'max timestp aggregation failed'
    );
    entries.append(entry_2);
    assert(
        Entry::aggregate_timestamps_max(entries.span()) == 1000001.try_into().unwrap(),
        'max timestp aggregation failed'
    );
    entries.append(entry_3);
    assert(
        Entry::aggregate_timestamps_max(entries.span()) == 1000002.try_into().unwrap(),
        'max timestp aggregation failed'
    );
    entries.append(entry_4);
    assert(
        Entry::aggregate_timestamps_max(entries.span()) == 1000002.try_into().unwrap(),
        'max timestp aggregation failed'
    );
    entries.append(entry_5);
    assert(
        Entry::aggregate_timestamps_max(entries.span()) == 1003002.try_into().unwrap(),
        'max timestp aggregation failed'
    );
}


#[test]
#[available_gas(10000000000)]
fn test_empty_array() {
    let mut entries = ArrayTrait::<SpotEntry>::new();
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Mean(())) == 0,
        'wrong agg for empty array'
    );
    assert(
        Entry::aggregate_entries(entries.span(), AggregationMode::Median(())) == 0,
        'wrong agg for empty array'
    );
    assert(Entry::aggregate_timestamps_max(entries.span()) == 0, 'wrong tmstp for empty array');
}
