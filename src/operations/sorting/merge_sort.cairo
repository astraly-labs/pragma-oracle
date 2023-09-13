use array::{ArrayTrait, SpanTrait};
use pragma::entry::structs::{SpotEntry, FutureEntry, BaseEntry};
use pragma::entry::entry::HasPrice;
use traits::TryInto;
use traits::Into;

//
//Traits
//

// // Merge Sort
// /// # Arguments
// /// * `arr` - Array to sort
// /// # Returns
// /// * `Array<T>` - Sorted array
fn merge<
    T,
    impl TCopy: Copy<T>,
    impl TDrop: Drop<T>, // impl TPartialOrd: PartialOrd<T>,
    impl THasPrice: HasPrice<T>,
>(
    arr: Span<T>
) -> Span<T> {
    if arr.len() > 1_u32 {
        // Create left and right arrays
        let middle = arr.len() / 2;
        let (mut left_arr, mut right_arr) = (
            arr.slice(0, middle), arr.slice(middle, arr.len() - middle)
        );
        // Recursively sort the left and right arrays
        let mut sorted_left = merge(left_arr);
        let mut sorted_right = merge(right_arr);
        let mut result_arr = ArrayTrait::<T>::new();
        merge_recursive(ref sorted_left, ref sorted_right, ref result_arr, 0, 0);
        result_arr.span()
    } else {
        let mut result_arr = ArrayTrait::<T>::new();
        result_arr.append(*arr.at(0));
        result_arr.span()
    }
}
// Merge two sorted arrays
// /// # Arguments
// /// * `left_arr` - Left array
// /// * `right_arr` - Right array
// /// * `result_arr` - Result array
// /// * `left_arr_ix` - Left array index
// /// * `right_arr_ix` - Right array index
// /// # Returns
// /// * `Array<usize>` - Sorted array
fn merge_recursive<
    T,
    impl TCopy: Copy<T>,
    impl TDrop: Drop<T>, // impl TPartialOrd: PartialOrd<T>,
    impl THasPrice: HasPrice<T>
>(
    ref left_arr: Span<T>,
    ref right_arr: Span<T>,
    ref result_arr: Array<T>,
    left_arr_ix: usize,
    right_arr_ix: usize
) {
    if result_arr.len() == left_arr.len() + right_arr.len() {
        return ();
    }

    if left_arr_ix == left_arr.len() {
        result_arr.append(*right_arr[right_arr_ix]);
        return merge_recursive(
            ref left_arr, ref right_arr, ref result_arr, left_arr_ix, right_arr_ix + 1
        );
    }

    if right_arr_ix == right_arr.len() {
        result_arr.append(*left_arr[left_arr_ix]);
        return merge_recursive(
            ref left_arr, ref right_arr, ref result_arr, left_arr_ix + 1, right_arr_ix
        );
    }

    if (*left_arr[left_arr_ix]).get_price() < (*right_arr[right_arr_ix]).get_price() {
        result_arr.append(*left_arr[left_arr_ix]);
        merge_recursive(ref left_arr, ref right_arr, ref result_arr, left_arr_ix + 1, right_arr_ix)
    } else {
        result_arr.append(*right_arr[right_arr_ix]);
        merge_recursive(ref left_arr, ref right_arr, ref result_arr, left_arr_ix, right_arr_ix + 1)
    }
}


//-----------------------------
// Tests

#[test]
#[available_gas(100000000)]
fn test_merge() {
    let mut entries = ArrayTrait::<SpotEntry>::new();
    let entry_1 = SpotEntry {
        base: BaseEntry { timestamp: 1000000, source: 1, publisher: 1001 },
        price: 50,
        pair_id: 1,
        volume: 10
    };
    let entry_2 = SpotEntry {
        base: BaseEntry { timestamp: 1000001, source: 1, publisher: 0234 },
        price: 100,
        pair_id: 1,
        volume: 30
    };
    let entry_3 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 200,
        pair_id: 1,
        volume: 30
    };
    let entry_4 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 80,
        pair_id: 1,
        volume: 30
    };
    let entry_5 = SpotEntry {
        base: BaseEntry { timestamp: 1000002, source: 1, publisher: 1334 },
        price: 50,
        pair_id: 1,
        volume: 30
    };
    entries.append(entry_1);
    entries.append(entry_2);
    entries.append(entry_3);
    entries.append(entry_4);
    entries.append(entry_5);
    let sorted_entries = merge::<SpotEntry>(entries.span());
    assert(sorted_entries.len() == 5, 'not good length');
    assert((*sorted_entries.at(0)).get_price() == 50, 'sorting failed(merge)');
    assert((*sorted_entries.at(1)).get_price() == 50, 'sorting failed(merge)');
    assert((*sorted_entries.at(2)).get_price() == 80, 'sorting failed(merge)');
    assert((*sorted_entries.at(3)).get_price() == 100, 'sorting failed(merge)');
}


#[test]
#[available_gas(10000000)]
fn test_slice() {
    let array = array![10, 20, 30, 40, 50].span();
    let middle = array.len() / 2;

    let (arr_1, arr_2) = (array.slice(0, middle), array.slice(middle, array.len() - middle));
    assert(arr_1.len() == 2, 'wrong len');
    assert(arr_2.len() == 3, 'wrong len');
    assert(*arr_1.at(0) == 10, 'wrong value');
    assert(*arr_1.at(1) == 20, 'wrong value');
    assert(*arr_2.at(0) == 30, 'wrong value');
    assert(*arr_2.at(1) == 40, 'wrong value');
    assert(*arr_2.at(2) == 50, 'wrong value');
}
