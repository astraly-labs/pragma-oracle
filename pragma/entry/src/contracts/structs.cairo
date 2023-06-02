const MEDIAN: u256 = 120282243752302; // str_to_felt("MEDIAN")
const SPOT: u256 = 1397772116;
const FUTURE: u256 = 77332301042245;
const GENERIC: u256 = 20060925819242819;
const BOTH_TRUE: u256 = 2;
const USD_CURRENCY_ID: u256 = 5591876;

#[derive(Copy, Drop, PartialOrd)]
struct BaseEntry {
    timestamp: u256,
    source: felt252,
    publisher: felt252,
}


struct GenericEntryStorage {
    timestamp__value: u256, 
}

#[derive(Copy, Drop, PartialOrd)]
struct SpotEntry {
    base: BaseEntry,
    price: u256,
    pair_id: felt252,
    volume: u256,
}

struct SpotEntryStorage {
    timestamp__volume__price: u256, 
}

/// Data Types
/// The value is the `pair_id` of the data
///
/// * `Spot` - Spot price
/// * `Future` - Future price
/// * `Generic` - Generic price
enum DataType {
    SpotEntry: u256,
    FutureEntry: u256,
    OptionEntry: u256
}


struct Pair {
    id: felt252, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
    quote_currency_id: felt252, // currency id - str_to_felt encode the ticker
    base_currency_id: felt252, // currency id - str_to_felt encode the ticker
}

struct Currency {
    id: felt252,
    decimals: u256,
    is_abstract_currency: felt252, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
    starknet_address: felt252, // optional, e.g. can have synthetics for non-bridged assets
    ethereum_address: felt252, // optional
}

struct Checkpoint {
    timestamp: u256,
    value: u256,
    aggregation_mode: felt252,
    num_sources_aggregated: u256,
}

struct PragmaPricesResponse {
    price: u256,
    decimals: u256,
    last_updated_timestamp: u256,
    num_sources_aggregated: u256,
}

