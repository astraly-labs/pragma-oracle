use array::ArrayTrait;
use cubit::f128::types::fixed::Fixed;
#[derive(Drop, Copy)]
struct TickElem {
    tick: u64,
    value: Fixed
}

struct List {
    length: u32,
    size: u32,
    arr: Array<u128>,
}

