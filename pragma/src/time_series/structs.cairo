use array::ArrayTrait;

#[derive(Drop, Copy)]
struct TickElem {
    tick: u32,
    value: u128
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
