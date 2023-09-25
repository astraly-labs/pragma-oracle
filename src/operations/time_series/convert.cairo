use alexandria_math::pow;
use traits::Into;
use debug::PrintTrait;

const MAX_POWER: u128 = 10000000000000000000000000000000;
fn div_decimals(a_price: u128, b_price: u128, output_decimals: u128) -> u128 {
    let power = pow(10_u128, output_decimals);

    assert(power <= MAX_POWER, 'Conversion overflow');
    assert(a_price <= MAX_POWER, 'Conversion overflow');

    a_price * power / b_price
}

fn mul_decimals(a_price: u128, b_price: u128, output_decimals: u128) -> u128 {
    let power = pow(10_u128, output_decimals);

    assert(power <= MAX_POWER, 'Conversion overflow');
    assert(a_price <= MAX_POWER, 'Conversion overflow');

    assert(power <= MAX_POWER, 'Conversion overflow');
    assert(a_price <= MAX_POWER, 'Conversion overflow');

    a_price * b_price * power
}

fn convert_via_usd(a_price_in_usd: u128, b_price_in_usd: u128, output_decimals: u32) -> u128 {
    let power: u128 = pow(10_u128, output_decimals.into()).into();

    assert(power <= MAX_POWER, 'Conversion overflow');
    assert(a_price_in_usd <= MAX_POWER, 'Conversion overflow');

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
