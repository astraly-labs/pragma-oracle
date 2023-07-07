use array::ArrayTrait;
use integer::u32;

#[derive(Drop, Copy)]
struct TickElem {
    tick: u64,
    value: u128
}

struct List {
    length: u32,
    size: u32,
    arr: Array<u128>,
}

struct PAIRWISE_OPERATION {
    ADDITION: (), // DEFAULT
    SUBSTRACTION: (),
    MULTIPLICATION: (),
    DIVISION: (),
    FIXED_POINT_MULTIPLICATION: (),
}
