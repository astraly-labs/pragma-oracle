use traits::Into;

// Raise a number to a power.
/// * `base` - The number to raise.
/// * `exp` - The exponent.
/// # Returns
/// * `u256` - The result of base raised to the power of exp.
fn pow2(exp: u256) -> u256 {
    if exp == 0.into() {
        return 1.into();
    } else {
        return 2.into() * pow2(exp - 1.into());
    }
}


// Raise a number to a power.
/// * `base` - The number to raise.
/// * `exp` - The exponent.
/// # Returns
/// * `u128` - The result of base raised to the power of exp.
fn pow2_u128(exp: u128) -> u128 {
    if exp == 0 {
        return 1;
    } else {
        return 2 * pow2_u128(exp - 1);
    }
}
