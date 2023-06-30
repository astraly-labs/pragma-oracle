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
