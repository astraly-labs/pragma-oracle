use alexandria_math::math::fpow;
use traits::Into;

fn div_decimals(a_price: u256, b_price: u256, output_decimals: u128) {
    let power = u256 { low: fpow(10_u128, output_decimals), high: 0 };

    let max_power = u256 { low: fpow(10_u128, 36_u128), high: 0 };

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    a_price * power / b_price;
}

fn mul_decimals(a_price: u256, b_price: u256, output_decimals: u128) {
    let power = u256 { low: fpow(10_u128, output_decimals), high: 0 };

    let max_power = u256 { low: fpow(10_u128, 36_u128), high: 0 };

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    a_price * b_price * power;
}