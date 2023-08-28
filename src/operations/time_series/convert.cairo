use alexandria_math::math::fpow;
use traits::Into;
use debug::PrintTrait;

fn div_decimals(a_price: u128, b_price: u128, output_decimals: u128) -> u128 {
    let power = fpow(10_u128, output_decimals);

    let max_power = fpow(10_u128, 31_u128);

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    a_price * power / b_price
}

fn mul_decimals(a_price: u128, b_price: u128, output_decimals: u128) -> u128 {
    let power = fpow(10_u128, output_decimals);

    let max_power = fpow(10_u128, 31_u128);

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    a_price * b_price * power
}

fn convert_via_usd(a_price_in_usd: u128, b_price_in_usd: u128, output_decimals: u32) -> u128 {
    let power: u128 = fpow(10_u128, output_decimals.into()).into();
    let max_power: u128 = fpow(10_u128, 31_u128).into();

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price_in_usd <= max_power, 'Conversion overflow');

    a_price_in_usd * power / b_price_in_usd
}


//------------------------------
//Tests

#[test]
#[available_gas(10000000000)]
fn test_convert_via_usd() {
    let a_price: u128 = 100;
    let b_price: u128 = 100;
    let output_decimals: u32 = 6;
    let result: u128 = convert_via_usd(a_price, b_price, output_decimals);
    assert(result == 1000000, 'div failed'); //10**6 output decimals 

    let a_price: u128 = 250;
    let b_price: u128 = 12;
    let output_decimals: u32 = 6;
    let result: u128 = convert_via_usd(a_price, b_price, output_decimals);
    assert(result == 20833333, 'div failed'); //10**6 output decimals 
}
