use traits::Into;
use pragma::operations::bits_manipulation::pow2::{pow2,u256_fast_pow2};


// @notice Will returns the corresponding u256, located a a certain position given by the at and number_of_bits parameters
// @param input: the u256 from which it needs to be extracted
// @param at: The position of the element that needs to be extracted
// @param number_of_bits: The size of the element that needs to be extracted
// @returns the requested element(since every element added to the input are u128 - see structs implementation, we can safely returns the .low part, without removing information)
fn actual_get_element_at(input: u256, at: u256, number_of_bits: u256) -> u128 {
    let mask = generate_get_mask(at, number_of_bits);
    let masked_response = input & mask;
    let divider = u256_fast_pow2(at);
    let response = masked_response / divider;
    response.low
}


// @notice Will return the a new u256 with the given u256 encoded at a certain position on a certain number of bits
// @dev This method can fail
// @param input: The felt from which it needs to be included in
// @param at: The position of the element that needs to be added, starts a 0
// @param number_of_bits: The size of the element that needs to be added
// @param element: The element that needs to be encoded
// @return response: The new felt containing the encoded value a the given position on the given number of bits
fn actual_set_element_at(input: u256, at: u256, number_of_bits: u256, element: u256,) -> u256 {
    assert_valid_felt(element, number_of_bits);
    let mask = generate_set_mask(at, number_of_bits);
    let masked_input = input & mask;
    unsafe_set_element_at(masked_input, at, element)
}


// @notice Will check that the given element isn't to big to be stored
// @dev Will fail if the felt is too big, which is relative to number_of_bits
// @param element: the element that needs to be checked
// @param number_of_bits: the number of bits on which each element is encoded
fn assert_valid_felt(element: u256, number_of_bits: u256) {
    let max_element = u256_fast_pow2(number_of_bits) - 1.into();

    assert(element.into() <= max_element, 'Error u256 too big');
}


// @notice Will check that the given position finumber_of_bitsts within the 256 bits available
// @dev Will fail if the position is too big +
// @param position: The position of the element, starts a 0
// @param number_of_bits: the number of bits on which each element is encoded
fn assert_within_range(position: u256, number_of_bits: u256) {
    assert(position + number_of_bits <= 255.into(), 'Error out of bound');
}


// @notice Will generate a bit mask to be able to insert a felt within another felt
// @dev Will fail if the position given would make it out of the 256 available bits
// @param position: The position of the element that needs to be inserted, starts a 0
// @param number_of_bits: the number of bits on which each element is encoded
// @return mask: the "set" mask corresponding to the position and the number of bits
fn generate_set_mask(position: u256, number_of_bits: u256) -> u256 {
    assert_within_range(position, number_of_bits);
    let mask = generate_mask(position, number_of_bits);
    let inverted_mask = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffff - mask;
    inverted_mask
}


// @notice Will generate the mask part that is common to set_mask and get_mask
// @dev Will fail if the position given would make it out of the 256 available bits
// @param position: The position of the element that needs to be inserted, starts a 0
// @param number_of_bits: the number of bits on which each element is encoded
// @return mask: the mask corresponding to the position and the number of bits
fn generate_mask(position: u256, number_of_bits: u256) -> u256 {
    assert_within_range(position, number_of_bits);
    let pow_big = u256_fast_pow2(position + number_of_bits);
    //TODO: need to determine why we cannot apply fast_pow2 without thread panicked here
    let pow_small = pow2(position); 
    let mask = (pow_big - 1) - (pow_small - 1);
    mask
}

// @notice Will set the input at the given position
// @dev Cannot fail
// @param position: The position of the element that needs to be set, starts a 0
// @param element: The element that needs to be encoded
// @return response: The new felt containing the encoded value a the given position on the given number of bits
fn unsafe_set_element_at(input: u256, at: u256, element: u256) -> u256 {
    let multiplier = u256_fast_pow2(at);
    let multiplied_element = element * multiplier;
    input + multiplied_element
}

// @notice Will generate a bit mask to extract a felt within another felt
// @dev Will fail if the position given would make it out of the 251 available bits
// @param position: The position of the element that needs to be extracted, starts a 0
// @param number_of_bits: The size of the element that needs to be extracted
// @return mask: the "get" mask corresponding to the position and the number of bits
fn generate_get_mask(position: u256, number_of_bits: u256) -> u256 {
    generate_mask(position, number_of_bits)
}


//--------------------------------
// Tests

use debug::PrintTrait;
#[test]
#[available_gas(100000000)]
fn test_bits_manipulation() {
    let element = actual_set_element_at(0, 0, 31, 1688646892);
    let element = actual_set_element_at(element, 32, 100, 1231452345234524523);
    let element = actual_set_element_at(element, 133, 65, 1232092993);
    let u128_timestamp: u128 = actual_get_element_at(element, 0, 31);
    let volume = actual_get_element_at(element, 32, 100);
    let price = actual_get_element_at(element, 133, 65);
    assert(u128_timestamp == 1688646892, 'Error timestamp');
    assert(volume == 1231452345234524523, 'Error volume');
    assert(price == 1232092993, 'Error price');
}
