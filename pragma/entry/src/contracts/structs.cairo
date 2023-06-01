const MEDIAN: felt252 = 120282243752302; // str_to_felt("MEDIAN")
const SPOT: felt252 = 1397772116;
const FUTURE: felt252 = 77332301042245;
const GENERIC: felt252 = 20060925819242819;

#[derive(Copy, Drop, PartialOrd)]
struct BaseEntry {
    timestamp: felt252,
    source: felt252,
    publisher: felt252,
}


struct GenericEntryStorage {
    timestamp__value: felt252, 
}

#[derive(Copy, Drop, PartialOrd)]
struct SpotEntry {
    base: BaseEntry,
    price: felt252,
    pair_id: felt252,
    volume: felt252,
}

struct SpotEntryStorage {
    timestamp__volume__price: felt252, 
}

/// Data Types
/// The value is the `pair_id` of the data
///
/// * `Spot` - Spot price
/// * `Future` - Future price
/// * `Generic` - Generic price
enum DataType {
    SpotEntry: felt252,
    FutureEntry: felt252,
    OptionEntry: felt252
}


struct Pair {
    id: felt252, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
    quote_currency_id: felt252, // currency id - str_to_felt encode the ticker
    base_currency_id: felt252, // currency id - str_to_felt encode the ticker
}

struct Currency {
    id: felt252,
    decimals: felt252,
    is_abstract_currency: felt252, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
    starknet_address: felt252, // optional, e.g. can have synthetics for non-bridged assets
    ethereum_address: felt252, // optional
}

struct Checkpoint {
    timestamp: felt252,
    value: felt252,
    aggregation_mode: felt252,
    num_sources_aggregated: felt252,
}

struct PragmaPricesResponse {
    price: felt252,
    decimals: felt252,
    last_updated_timestamp: felt252,
    num_sources_aggregated: felt252,
}

