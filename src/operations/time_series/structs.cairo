use array::ArrayTrait;
use integer::u32;
use alexandria_math::signed_integers::i129;
use cubit::types::fixed::Fixed;
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

struct PAIRWISE_OPERATION {
    ADDITION: (), // DEFAULT
    SUBTRACTION: (),
    MULTIPLICATION: (),
    DIVISION: (),
    FIXED_POINT_MULTIPLICATION: (),
}
