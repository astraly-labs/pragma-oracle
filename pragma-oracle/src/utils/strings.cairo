// Needed so we can construct a pair id from two felts.
// Source:
// https://github.com/underware-gg/underdark/blob/258c3ca96a728a605b70b21a3fa697d290d31409/dojo/src/utils/string.cairo#L4
use pragma::utils::bitwise::U256Bitwise;

trait StringTrait {
    fn concat(left: felt252, right: felt252) -> felt252;
    fn join(left: felt252, right: felt252) -> felt252;
}

impl String of StringTrait {
    fn concat(left: felt252, right: felt252) -> felt252 {
        let _left: u256 = left.into();
        let _right: u256 = right.into();
        let mut offset: usize = 0;
        let mut i: usize = 0;
        loop {
            if (i == 256) {
                break;
            }
            if (_right & U256Bitwise::shl(0xff, i) != 0) {
                offset = i + 8;
            }
            i += 8;
        };
        (_right | U256Bitwise::shl(_left, offset)).try_into().unwrap()
    }

    fn join(left: felt252, right: felt252) -> felt252 {
        String::concat(String::concat(left, '_'), right)
    }
}
