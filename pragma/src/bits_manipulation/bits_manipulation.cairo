fn actual_get_element_at(input: felt252, at: felt252, number_of_bits: felt252) -> felt252 {
    let mask = generate_get_mask(at, number_of_bits);
    let masked_response = input & mask;
    let divider = pow2(at);
    let response = masked_response / divider;
    response
}

// @notice Will return the a new felt with the felt encoded at a certain position on a certain number of bits
// @dev This method can fail
// @param input: The felt from which it needs to be included in
// @param at: The position of the element that needs to be added, starts a 0
// @param number_of_bits: The size of the element that needs to be added
// @param element: The element that needs to be encoded
// @return response: The new felt containing the encoded value a the given position on the given number of bits
fn actual_set_element_at(
    input: felt252,
    at: felt252,
    number_of_bits: felt252,
    element: felt252,
) -> felt252 {
    assert_valid_felt(element, number_of_bits);
    let mask = generate_set_mask(at, number_of_bits);
    let masked_input = input & mask;
}

// @notice Will check that the given element isn't to big to be stored
// @dev Will fail if the felt is too big, which is relative to number_of_bits
// @param element: the element that needs to be checked
// @param number_of_bits: the number of bits on which each element is encoded
fn assert_valid_felt(element: felt252, number_of_bits: felt252) {
    let max_element = pow2(number_of_bits) - 1;
    assert(element <= max_element, 'Error felt too big');
}

// @notice Will check that the given position finumber_of_bitsts within the 251 bits available
// @dev Will fail if the position is too big +
// @param position: The position of the element, starts a 0
// @param number_of_bits: the number of bits on which each element is encoded
fn assert_within_range(position: felt252, number_of_bits: felt252) {
    assert(position + number_of_bits <= 251, 'Error out of bound');
}

// @notice Will generate a bit mask to be able to insert a felt within another felt
// @dev Will fail if the position given would make it out of the 251 available bits
// @param position: The position of the element that needs to be inserted, starts a 0
// @param number_of_bits: the number of bits on which each element is encoded
// @return mask: the "set" mask corresponding to the position and the number of bits
fn generate_set_mask(position: felt252, number_of_bits: felt252) -> felt252 {
    assert_within_range(position, number_of_bits);
    let mask = generate_mask(position, number_of_bits);
    let inverted_mask = 0xffffffffffffffffffffffffffffffff - mask;
    inverted_mask
}

// @notice Will generate the mask part that is common to set_mask and get_mask
// @dev Will fail if the position given would make it out of the 251 available bits
// @param position: The position of the element that needs to be inserted, starts a 0
// @param number_of_bits: the number of bits on which each element is encoded
// @return mask: the mask corresponding to the position and the number of bits
fn generate_mask(position: felt252, number_of_bits: felt252) -> felt252 {
    assert_within_range(position, number_of_bits);
    let pow_big = pow2(position + number_of_bits);
    let pow_small = pow2(position);
    let mask = (pow_big - 1) - (pow_small - 1);
    mask
}

// @notice Will set the input at tjhe given position
// @dev Cannot fail
// @param position: The position of the element that needs to be set, starts a 0
// @param element: The element that needs to be encoded
// @return response: The new felt containing the encoded value a the given position on the given number of bits
fn unsafe_set_element_at(input: felt252, at: felt252, element: felt252) -> felt252 {
    let multiplier = pow2(at);
    let multiplied_element = element * multiplier;
    input + multiplied_element
}

// @notice Will generate a bit mask to extract a felt within another felt
// @dev Will fail if the position given would make it out of the 251 available bits
// @param position: The position of the element that needs to be extracted, starts a 0
// @param number_of_bits: The size of the element that needs to be extracted
// @return mask: the "get" mask corresponding to the position and the number of bits
fn generate_get_mask(position: felt252, number_of_bits: felt252) -> felt252 {
    generate_mask(position, number_of_bits);
}