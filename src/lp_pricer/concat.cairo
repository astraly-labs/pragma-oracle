// Source:
// https://github.com/underware-gg/underdark/blob/258c3ca96a728a605b70b21a3fa697d290d31409/dojo/src/utils/string.cairo#L4

const U8_ONE_LEFT: u8 = 0x80;
const U16_ONE_LEFT: u16 = 0x8000;
const U32_ONE_LEFT: u32 = 0x80000000;
const U64_ONE_LEFT: u64 = 0x8000000000000000;
const U128_ONE_LEFT: u128 = 0x80000000000000000000000000000000;
const U256_ONE_LEFT: u256 = 0x8000000000000000000000000000000000000000000000000000000000000000;

trait Bitwise<T> {
    fn bit(n: usize) -> T;
    fn set(x: T, n: usize) -> T;
    fn unset(x: T, n: usize) -> T;
    fn shl(x: T, n: usize) -> T;
    fn shr(x: T, n: usize) -> T;
    fn is_set(x: T, n: usize) -> bool;
    fn count_bits(x: T) -> usize;
}

impl U8Bitwise of Bitwise<u8> {
    fn bit(n: usize) -> u8 {
        if n == 0 {
            return 0b00000001;
        }
        if n == 1 {
            return 0b00000010;
        }
        if n == 2 {
            return 0b00000100;
        }
        if n == 3 {
            return 0b00001000;
        }
        if n == 4 {
            return 0b00010000;
        }
        if n == 5 {
            return 0b00100000;
        }
        if n == 6 {
            return 0b01000000;
        }
        if n == 7 {
            return 0b10000000;
        }
        0
    }
    #[inline(always)]
    fn set(x: u8, n: usize) -> u8 {
        x | U8Bitwise::bit(n)
    }
    #[inline(always)]
    fn unset(x: u8, n: usize) -> u8 {
        x & ~U8Bitwise::bit(n)
    }
    #[inline(always)]
    fn shl(x: u8, n: usize) -> u8 {
        x * U8Bitwise::bit(n)
    }
    #[inline(always)]
    fn shr(x: u8, n: usize) -> u8 {
        if (n < 8) {
            return (x / U8Bitwise::bit(n));
        }
        0
    }
    #[inline(always)]
    fn is_set(x: u8, n: usize) -> bool {
        ((U8Bitwise::shr(x, n) & 1) != 0)
    }
    fn count_bits(x: u8) -> usize {
        let mut result: usize = 0;
        let mut bit: u8 = U8_ONE_LEFT;
        loop {
            if (x & bit > 0) {
                result += 1;
            };
            if (bit == 0x1) {
                break;
            }
            bit /= 2;
        };
        result
    }
}

impl U16Bitwise of Bitwise<u16> {
    fn bit(n: usize) -> u16 {
        if n < 8 {
            return U8Bitwise::bit(n).into();
        }
        if n < 16 {
            return U8Bitwise::bit(n - 8).into() * 0x100;
        }
        0
    }
    #[inline(always)]
    fn set(x: u16, n: usize) -> u16 {
        x | U16Bitwise::bit(n)
    }
    #[inline(always)]
    fn unset(x: u16, n: usize) -> u16 {
        x & ~U16Bitwise::bit(n)
    }
    #[inline(always)]
    fn shl(x: u16, n: usize) -> u16 {
        x * U16Bitwise::bit(n)
    }
    #[inline(always)]
    fn shr(x: u16, n: usize) -> u16 {
        if (n < 16) {
            return (x / U16Bitwise::bit(n));
        }
        0
    }
    #[inline(always)]
    fn is_set(x: u16, n: usize) -> bool {
        ((U16Bitwise::shr(x, n) & 1) != 0)
    }
    fn count_bits(x: u16) -> usize {
        let mut result: usize = 0;
        let mut bit: u16 = U16_ONE_LEFT;
        loop {
            if (x & bit > 0) {
                result += 1;
            };
            if (bit == 0x1) {
                break;
            }
            bit /= 2;
        };
        result
    }
}

impl U32Bitwise of Bitwise<u32> {
    fn bit(n: usize) -> u32 {
        if n < 16 {
            return U16Bitwise::bit(n).into();
        }
        if n < 32 {
            return U16Bitwise::bit(n - 16).into() * 0x10000;
        }
        0
    }
    #[inline(always)]
    fn set(x: u32, n: usize) -> u32 {
        x | U32Bitwise::bit(n)
    }
    #[inline(always)]
    fn unset(x: u32, n: usize) -> u32 {
        x & ~U32Bitwise::bit(n)
    }
    #[inline(always)]
    fn shl(x: u32, n: usize) -> u32 {
        x * U32Bitwise::bit(n)
    }
    #[inline(always)]
    fn shr(x: u32, n: usize) -> u32 {
        if (n < 32) {
            return (x / U32Bitwise::bit(n));
        }
        0
    }
    #[inline(always)]
    fn is_set(x: u32, n: usize) -> bool {
        ((U32Bitwise::shr(x, n) & 1) != 0)
    }
    fn count_bits(x: u32) -> usize {
        let mut result: usize = 0;
        let mut bit: u32 = U32_ONE_LEFT;
        loop {
            if (x & bit > 0) {
                result += 1;
            };
            if (bit == 0x1) {
                break;
            }
            bit /= 2;
        };
        result
    }
}

impl U64Bitwise of Bitwise<u64> {
    fn bit(n: usize) -> u64 {
        if n < 32 {
            return U32Bitwise::bit(n).into();
        }
        if n < 64 {
            return U32Bitwise::bit(n - 32).into() * 0x100000000;
        }
        0
    }
    #[inline(always)]
    fn set(x: u64, n: usize) -> u64 {
        x | U64Bitwise::bit(n)
    }
    #[inline(always)]
    fn unset(x: u64, n: usize) -> u64 {
        x & ~U64Bitwise::bit(n)
    }
    #[inline(always)]
    fn shl(x: u64, n: usize) -> u64 {
        x * U64Bitwise::bit(n)
    }
    #[inline(always)]
    fn shr(x: u64, n: usize) -> u64 {
        if (n < 64) {
            return (x / U64Bitwise::bit(n));
        }
        0
    }
    #[inline(always)]
    fn is_set(x: u64, n: usize) -> bool {
        ((U64Bitwise::shr(x, n) & 1) != 0)
    }
    fn count_bits(x: u64) -> usize {
        let mut result: usize = 0;
        let mut bit: u64 = U64_ONE_LEFT;
        loop {
            if (x & bit > 0) {
                result += 1;
            };
            if (bit == 0x1) {
                break;
            }
            bit /= 2;
        };
        result
    }
}

impl U128Bitwise of Bitwise<u128> {
    fn bit(n: usize) -> u128 {
        if n < 64 {
            return U64Bitwise::bit(n).into();
        }
        if n < 128 {
            return U64Bitwise::bit(n - 64).into() * 0x10000000000000000;
        }
        0
    }
    #[inline(always)]
    fn set(x: u128, n: usize) -> u128 {
        x | U128Bitwise::bit(n)
    }
    #[inline(always)]
    fn unset(x: u128, n: usize) -> u128 {
        x & ~U128Bitwise::bit(n)
    }
    #[inline(always)]
    fn shl(x: u128, n: usize) -> u128 {
        x * U128Bitwise::bit(n)
    }
    #[inline(always)]
    fn shr(x: u128, n: usize) -> u128 {
        if (n < 128) {
            return (x / U128Bitwise::bit(n));
        }
        0
    }
    #[inline(always)]
    fn is_set(x: u128, n: usize) -> bool {
        ((U128Bitwise::shr(x, n) & 1) != 0)
    }
    fn count_bits(x: u128) -> usize {
        let mut result: usize = 0;
        let mut bit: u128 = U128_ONE_LEFT;
        loop {
            if (x & bit > 0) {
                result += 1;
            };
            if (bit == 0x1) {
                break;
            }
            bit /= 2;
        };
        result
    }
}

impl U256Bitwise of Bitwise<u256> {
    fn bit(n: usize) -> u256 {
        if n < 128 {
            return u256 { low: U128Bitwise::bit(n), high: 0x0 };
        }
        if n < 256 {
            return u256 { low: 0x0, high: U128Bitwise::bit(n - 128) };
        }
        0
    }
    #[inline(always)]
    fn set(x: u256, n: usize) -> u256 {
        x | U256Bitwise::bit(n)
    }
    #[inline(always)]
    fn unset(x: u256, n: usize) -> u256 {
        x & ~U256Bitwise::bit(n)
    }
    #[inline(always)]
    fn shl(x: u256, n: usize) -> u256 {
        x * U256Bitwise::bit(n)
    }
    #[inline(always)]
    fn shr(x: u256, n: usize) -> u256 {
        if (n < 256) {
            return (x / U256Bitwise::bit(n));
        }
        0
    }
    #[inline(always)]
    fn is_set(x: u256, n: usize) -> bool {
        ((U256Bitwise::shr(x, n) & 1) != 0)
    }
    fn count_bits(x: u256) -> usize {
        let mut result: usize = 0;
        let mut bit: u256 = U256_ONE_LEFT;
        loop {
            if (x & bit > 0) {
                result += 1;
            };
            if (bit == 0x1) {
                break;
            }
            bit /= 2;
        };
        result
    }
}

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
