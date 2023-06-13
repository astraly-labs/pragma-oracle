use starknet::ContractAddress;

const MEDIAN: felt252 = 'MEDIAN'; // str_to_felt("MEDIAN")
const SPOT: felt252 = 'SPOT';
const FUTURE: felt252 = 'FUTURE';
const GENERIC: felt252 = 'GENERIC';
const OPTION: felt252 = 'OPTION';
const BOTH_TRUE: felt252 = 2;
const USD_CURRENCY_ID: felt252 = 'USD';


#[derive(Copy, Drop, PartialOrd, Serde)]
struct BaseEntry {
    timestamp: u256,
    source: felt252,
    publisher: felt252,
}


struct GenericEntryStorage {
    timestamp__value: u256, 
}

#[derive(Copy, Drop, PartialOrd, Serde)]
struct SpotEntry {
    base: BaseEntry,
    price: u256,
    pair_id: felt252,
    volume: u256,
}

#[derive(Copy, Drop, PartialOrd, Serde)]
struct FutureEntry {
    base: BaseEntry,
    price: u256,
    pair_id: felt252,
    volume: u256,
    timestamp: u256,
    expiration_timestamp: u256,
}

#[derive(Serde, Drop, Copy)]
struct OptionEntry {
    base: BaseEntry,
    rawParameters: rawSVI,
    essviParameters: eSSVI,
    forwardPrice: u256,
    strikePrice: u256,
    expirationTimestamp: u256,
}

#[derive(Serde, Drop, Copy)]
struct rawSVI {
    a: u256,
    b: u256,
    rho: u256,
    m: u256,
    sigma: u256,
    decimals: u32
}

#[derive(Serde, Drop, Copy)]
struct eSSVI {
    theta: u256,
    rho: u256,
    phi: u256
}

#[derive(Serde, Drop, Copy)]
struct SpotEntryStorage {
    timestamp__volume__price: u256, 
}

#[derive(Serde, Drop, Copy)]
struct FutureEntryStorage {
    timestamp__volume__price: u256, 
}

/// Data Types
/// The value is the `pair_id` of the data
/// For future option, pair_id and expiration timestamp
///
/// * `Spot` - Spot price
/// * `Future` - Future price
/// * `Generic` - Generic price
#[derive(Drop, Copy)]
enum DataType {
    SpotEntry: felt252,
    FutureEntry: (felt252, u256),
// OptionEntry: (felt252, felt252),
}

#[derive(Drop, Copy)]
enum PossibleEntryStorage {
    Spot: SpotEntryStorage, //structure SpotEntryStorage
    Future: FutureEntryStorage, //structure FutureEntryStorage
// Option: OptionEntryStorage, //structure OptionEntryStorage
}

enum simpleDataType {
    SpotEntry: (),
    FutureEntry: (),
    OptionEntry: (),
}

enum possibleEntries {
    Spot: SpotEntry,
    Future: FutureEntry,
// Option: OptionEntry,
}

enum entryDataType {
    SpotEntry: SpotEntry,
    FutureEntry: FutureEntry,
// OptionEntry: OptionEntry,
}


#[derive(Serde, Drop, Copy)]
struct Pair {
    id: felt252, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
    quote_currency_id: felt252, // currency id - str_to_felt encode the ticker
    base_currency_id: felt252, // currency id - str_to_felt encode the ticker
}

#[derive(Serde, Drop, Copy)]
struct Currency {
    id: felt252,
    decimals: u32,
    is_abstract_currency: felt252, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
    starknet_address: ContractAddress, // optional, e.g. can have synthetics for non-bridged assets
    ethereum_address: ContractAddress, // optional
}

#[derive(Serde, Drop)]
struct Checkpoint {
    timestamp: u256,
    value: u256,
    aggregation_mode: AggregationMode,
    num_sources_aggregated: u32,
}

struct PragmaPricesResponse {
    price: u256,
    decimals: u32,
    last_updated_timestamp: u256,
    num_sources_aggregated: u32,
    expiration_timestamp: Option<u256>,
}

#[derive(Serde, Drop, Copy)]
enum AggregationMode {
    Median: (), 
}
