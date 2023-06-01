use alexandria_math::math::fpow;
use traits::Into;

fn div_decimals(a_price: u256, b_price: u256, output_decimals: u128) {
    let power = fpow(10_u128, output_decimals);
    let power_felt = power.into();
    let power_u256 = power_felt.into();

    let max_power = fpow(10_u128, 36_u128);
    let max_power_felt = max_power.into();
    let max_power_u256 = max_power_felt.into();

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power_u256, 'Conversion overflow');

    a_price * power_u256 / b_price;
}

fn mul_decimals(a_price: u256, b_price: u256, output_decimals: u128) {
    let power = fpow(10_u128, output_decimals);
    let power_felt = power.into();
    let power_u256 = power_felt.into();

    let max_power = fpow(10_u128, 36_u128);
    let max_power_felt = max_power.into();
    let max_power_u256 = max_power_felt.into();

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power_u256, 'Conversion overflow');

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power_u256, 'Conversion overflow');

    a_price * b_price * power_u256;
}