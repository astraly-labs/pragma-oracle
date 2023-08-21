use array::ArrayTrait;
use pragma::entry::structs::{BaseEntry, AggregationMode};
use pragma::operations::sorting::merge_sort::merge;
use pragma::entry::structs::{SpotEntry, FutureEntry, GenericEntry};
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


impl GHasPriceImpl of HasPrice<GenericEntry> {
    fn get_price(self: @GenericEntry) -> u256 {
        (*self).value
    }
}

mod Entry {
    use super::{
        ArrayTrait, BaseEntry, AggregationMode, merge, SpotEntry, FutureEntry, GenericEntry,
        TryInto, Into, OptionTrait, HasPrice
    };

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
    impl OhasBaseEntryImpl of hasBaseEntry<GenericEntry> {
        fn get_base_entry(self: @GenericEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @GenericEntry) -> u64 {
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
        impl THasPrice: HasPrice<T>, // impl TPartialOrd: PartialOrd<T>,
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
            AggregationMode::Mean(()) => {
                let value: u256 = entries_mean(entries);
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
    // @param entries: array of entries to aggregate
    // @return value: the median value from the array of entries
    fn entries_median<
        T,
        impl TCopy: Copy<T>,
        impl TDrop: Drop<T>, // impl TPartialOrd: PartialOrd<T>,
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
            let median_idx = (entries_len) / 2;
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

    // @notice Returns the mean value from an entries array
    // @param entries: entries array to aggregate
    // @return value: the mean value from the array of entries
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


//-----------------------------------------------
// Tests

use debug::PrintTrait;

#[test]
#[available_gas(100000000)]
fn test_aggregate_entries_median() {
    let mut entries = ArrayTrait::<SpotEntry>::new();
    let entry_1 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000000, source: 1, publisher: 1001
        }, price: 10.into(), pair_id: 1, volume: 10.into()
    };
    let entry_2 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000001, source: 1, publisher: 0234
        }, price: 20.into(), pair_id: 1, volume: 30.into()
    };
    let entry_3 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 30.into(), pair_id: 1, volume: 30.into()
    };
    let entry_4 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 40.into(), pair_id: 1, volume: 30.into()
    };
    let entry_5 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 50.into(), pair_id: 1, volume: 30.into()
    };
    //1 element 
    entries.append(entry_1);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Median(())) == 10.into(),
        'median aggregation failed(1)'
    );

    //2 elements
    entries.append(entry_2);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Median(())) == 15.into(),
        'median aggregation failed(even)'
    );

    //3 elements
    entries.append(entry_3);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Median(())) == 20.into(),
        'median aggregation failed(odd)'
    );

    //4 elements
    entries.append(entry_4);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Median(())) == 25.into(),
        'median aggregation failed(even)'
    );

    //5 elements
    entries.append(entry_5);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Median(())) == 30.into(),
        'median aggregation failed(odd)'
    );

    //FUTURES

    let mut f_entries = ArrayTrait::<FutureEntry>::new();
    let entry_1 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000000, source: 1, publisher: 1001
        }, price: 10.into(), pair_id: 1, volume: 10.into(), expiration_timestamp: 1111111
    };
    let entry_2 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000001, source: 1, publisher: 0234
        }, price: 20.into(), pair_id: 1, volume: 30.into(), expiration_timestamp: 1111111
    };
    let entry_3 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 30.into(), pair_id: 1, volume: 30.into(), expiration_timestamp: 1111111
    };
    let entry_4 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 40.into(), pair_id: 1, volume: 30.into(), expiration_timestamp: 1111111
    };
    let entry_5 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 50.into(), pair_id: 1, volume: 30.into(), expiration_timestamp: 1111111
    };
    //1 element 
    f_entries.append(entry_1);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Median(())) == 10.into(),
        'median aggregation failed(1)'
    );
    //2 elements
    f_entries.append(entry_2);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Median(())) == 15.into(),
        'median aggregation failed(even)'
    );

    //3 elements
    f_entries.append(entry_3);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Median(())) == 20.into(),
        'median aggregation failed(odd)'
    );

    //4 elements
    f_entries.append(entry_4);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Median(())) == 25.into(),
        'median aggregation failed(even)'
    );

    //5 elements
    f_entries.append(entry_5);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Median(())) == 30.into(),
        'median aggregation failed(odd)'
    );
}


#[test]
#[available_gas(100000000)]
fn test_aggregate_entries_mean() {
    let mut entries = ArrayTrait::<SpotEntry>::new();
    let entry_1 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000000, source: 1, publisher: 1001
        }, price: 10.into(), pair_id: 1, volume: 10.into()
    };
    let entry_2 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000001, source: 1, publisher: 0234
        }, price: 20.into(), pair_id: 1, volume: 30.into()
    };
    let entry_3 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 30.into(), pair_id: 1, volume: 30.into()
    };
    let entry_4 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 40.into(), pair_id: 1, volume: 30.into()
    };
    let entry_5 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 50.into(), pair_id: 1, volume: 30.into()
    };
    //1 element 
    entries.append(entry_1);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Mean(())) == 10.into(),
        'Mean aggregation failed(1)'
    );

    //2 elements
    entries.append(entry_2);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Mean(())) == 15.into(),
        'Mean aggregation failed(even)'
    );

    //3 elements
    entries.append(entry_3);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Mean(())) == 20.into(),
        'Mean aggregation failed(odd)'
    );

    //4 elements
    entries.append(entry_4);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Mean(())) == 25.into(),
        'Mean aggregation failed(even)'
    );

    //5 elements
    entries.append(entry_5);
    assert(
        Entry::aggregate_entries(@entries, AggregationMode::Mean(())) == 30.into(),
        'Mean aggregation failed(odd)'
    );
    //FUTURES

    let mut f_entries = ArrayTrait::<FutureEntry>::new();
    let entry_1 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000000, source: 1, publisher: 1001
        }, price: 10.into(), pair_id: 1, volume: 10.into(), expiration_timestamp: 1111111
    };
    let entry_2 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000001, source: 1, publisher: 0234
        }, price: 20.into(), pair_id: 1, volume: 30.into(), expiration_timestamp: 1111111
    };
    let entry_3 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 30.into(), pair_id: 1, volume: 30.into(), expiration_timestamp: 1111111
    };
    let entry_4 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 40.into(), pair_id: 1, volume: 30.into(), expiration_timestamp: 1111111
    };
    let entry_5 = FutureEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 50.into(), pair_id: 1, volume: 30.into(), expiration_timestamp: 1111111
    };
    //1 element 
    f_entries.append(entry_1);

    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Mean(())) == 10.into(),
        'median aggregation failed(1)'
    );
    //2 elements
    f_entries.append(entry_2);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Mean(())) == 15.into(),
        'median aggregation failed(even)'
    );

    //3 elements
    f_entries.append(entry_3);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Mean(())) == 20.into(),
        'median aggregation failed(odd)'
    );

    //4 elements
    f_entries.append(entry_4);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Mean(())) == 25.into(),
        'median aggregation failed(even)'
    );

    //5 elements
    f_entries.append(entry_5);
    assert(
        Entry::aggregate_entries(@f_entries, AggregationMode::Mean(())) == 30.into(),
        'median aggregation failed(odd)'
    );
}


#[test]
#[available_gas(100000000)]
fn test_aggregate_timestamp_max() {
    let mut entries = ArrayTrait::<SpotEntry>::new();
    let entry_1 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000000, source: 1, publisher: 1001
        }, price: 10.into(), pair_id: 1, volume: 10.into()
    };
    let entry_2 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000001, source: 1, publisher: 0234
        }, price: 20.into(), pair_id: 1, volume: 30.into()
    };
    let entry_3 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 30.into(), pair_id: 1, volume: 30.into()
    };
    let entry_4 = SpotEntry {
        base: BaseEntry {
            timestamp: 1000002, source: 1, publisher: 1334
        }, price: 40.into(), pair_id: 1, volume: 30.into()
    };
    let entry_5 = SpotEntry {
        base: BaseEntry {
            timestamp: 1003002, source: 1, publisher: 1334
        }, price: 50.into(), pair_id: 1, volume: 30.into()
    };
    //1 element 
    entries.append(entry_1);
    assert(
        Entry::aggregate_timestamps_max(@entries) == 1000000.try_into().unwrap(),
        'max timestp aggregation failed'
    );
    entries.append(entry_2);
    assert(
        Entry::aggregate_timestamps_max(@entries) == 1000001.try_into().unwrap(),
        'max timestp aggregation failed'
    );
    entries.append(entry_3);
    assert(
        Entry::aggregate_timestamps_max(@entries) == 1000002.try_into().unwrap(),
        'max timestp aggregation failed'
    );
    entries.append(entry_4);
    assert(
        Entry::aggregate_timestamps_max(@entries) == 1000002.try_into().unwrap(),
        'max timestp aggregation failed'
    );
    entries.append(entry_5);
    assert(
        Entry::aggregate_timestamps_max(@entries) == 1003002.try_into().unwrap(),
        'max timestp aggregation failed'
    );
}
