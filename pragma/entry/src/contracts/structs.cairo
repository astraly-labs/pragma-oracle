use starknet::ContractAddress;

const MEDIAN: felt252 = 'MEDIAN'; // str_to_felt("MEDIAN")
const SPOT: felt252 = 'SPOT';
const FUTURE: felt252 = 'FUTURE';
const GENERIC: felt252 = 'GENERIC';
const OPTION: felt252 = 'OPTION';
const BOTH_TRUE: felt252 = 2;
const USD_CURRENCY_ID: felt252 = 'USD';



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

#[derive(Copy, Drop, PartialOrd)]
struct FutureEntry { 
    base: BaseEntry,
    price: u256,
    pair_id: felt252,
    volume: u256,
    expiration_timestamp: u256,
}

struct OptionEntry { 
    rawParameters : rawSVI,
    essviParameters : eSSVI,
    forwardPrice : u256,
    strikePrice : u256,
    expirationTimestamp : u256,
    source : @Array<felt252>  //array containing all the sources used for the aggregation

}


struct rawSVI { 
    a : u256, 
    b : u256,
    rho : u256,
    m : u256,
    sigma : u256,
    decimals: u32

}

struct eSSVI { 
    theta : u256,
    rho : u256, 
    phi : u256
}
struct SpotEntryStorage {
    timestamp__volume__price: u256, 
}

struct FutureEntryStorage {
    timestamp__price: u256,
}

/// Data Types
/// The value is the `pair_id` of the data
/// For future option, pair_id and expiration timestamp
///
/// * `Spot` - Spot price
/// * `Future` - Future price
/// * `Generic` - Generic price
enum DataType {
    SpotEntry: felt252,
    FutureEntry: (felt252, u256),
    OptionEntry: felt252
}

enum PossibleEntries { 
    Spot : SpotEntryStorage,
    Future :FutureEntryStorage,
    // Option : OptionEntryStorage,
}

enum simpleDataType { 
        SpotEntry: (), 
        FutureEntry: (),
        OptionEntry: (),
    }



struct Pair {
    id: felt252, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
    quote_currency_id: felt252, // currency id - str_to_felt encode the ticker
    base_currency_id: felt252, // currency id - str_to_felt encode the ticker
}

struct Currency {
    id: felt252,
    decimals: u32,
    is_abstract_currency: felt252, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
    starknet_address: ContractAddress, // optional, e.g. can have synthetics for non-bridged assets
    ethereum_address: ContractAddress, // optional
}

struct Checkpoint {
    timestamp: u256,
    value: u256,
    aggregation_mode: felt252,
    num_sources_aggregated: u32,
}

struct PragmaPricesResponse {
    price: u256,
    decimals: u32,
    last_updated_timestamp: u256,
    num_sources_aggregated: u32,
}

