use alexandria_math::math::fpow;
use traits::Into;
use debug::PrintTrait;

fn div_decimals(a_price: u256, b_price: u256, output_decimals: u128) -> u256 {
    let power = u256 { low: fpow(10_u128, output_decimals), high: 0 };

    let max_power = u256 { low: fpow(10_u128, 31_u128), high: 0 };

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    a_price * power / b_price
}

fn mul_decimals(a_price: u256, b_price: u256, output_decimals: u128) -> u256 {
    let power = u256 { low: fpow(10_u128, output_decimals), high: 0 };

    let max_power = u256 { low: fpow(10_u128, 31_u128), high: 0 };

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price <= max_power, 'Conversion overflow');

    a_price * b_price * power
}

fn convert_via_usd(a_price_in_usd: u256, b_price_in_usd: u256, output_decimals: u32) -> u256 {
    let power: u256 = fpow(10_u128, output_decimals.into()).into();
    let max_power: u256 = fpow(10_u128, 31_u128).into();

    assert(power <= max_power, 'Conversion overflow');
    assert(a_price_in_usd <= max_power, 'Conversion overflow');

    a_price_in_usd * power / b_price_in_usd
}


//------------------------------
//Tests

#[test]
#[available_gas(10000000000)]
fn test_convert_via_usd() {
    let a_price: u256 = 100.into();
    let b_price: u256 = 100.into();
    let output_decimals: u32 = 6;
    let result: u256 = convert_via_usd(a_price, b_price, output_decimals);
    assert(result == 1000000, 'div failed'); //10**6 output decimals 

    let a_price: u256 = 250.into();
    let b_price: u256 = 12.into();
    let output_decimals: u32 = 6;
    let result: u256 = convert_via_usd(a_price, b_price, output_decimals);
    assert(result == 20833333, 'div failed'); //10**6 output decimals 
}
