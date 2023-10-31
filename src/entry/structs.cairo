use starknet::ContractAddress;
use array::ArrayTrait;

const MEDIAN: felt252 = 'MEDIAN'; // str_to_felt("MEDIAN")
const SPOT: felt252 = 'SPOT';
const FUTURE: felt252 = 'FUTURE';
const GENERIC: felt252 = 'GENERIC';
const OPTION: felt252 = 'OPTION';
const USD_CURRENCY_ID: felt252 = 'USD';


#[derive(Copy, Drop, Serde, starknet::Store)]
struct BaseEntry {
    timestamp: u64,
    source: felt252,
    publisher: felt252,
}

#[derive(Serde, Drop, Copy)]
struct GenericEntryStorage {
    timestamp__value: u256,
}

#[derive(Copy, Drop, Serde)]
struct SpotEntry {
    base: BaseEntry,
    price: u128,
    pair_id: felt252,
    volume: u128,
}
#[derive(Copy, Drop, Serde)]
struct GenericEntry {
    base: BaseEntry,
    key: felt252,
    value: u128,
}

#[derive(Copy, Drop, PartialOrd, Serde)]
struct FutureEntry {
    base: BaseEntry,
    price: u128,
    pair_id: felt252,
    volume: u128,
    expiration_timestamp: u64,
}

#[derive(Serde, Drop, Copy)]
struct OptionEntry {
    base: BaseEntry,
    rawParameters: rawSVI,
    essviParameters: eSSVI,
    forwardPrice: u256,
    strikePrice: u256,
    expirationTimestamp: u64,
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
struct EntryStorage {
    timestamp: u64,
    volume: u128,
    price: u128,
}


/// Data Types
/// The value is the `pair_id` of the data
/// For future option, pair_id and expiration timestamp
///
/// * `Spot` - Spot price
/// * `Future` - Future price
/// * `Option` - Option price
#[derive(Drop, Copy, Serde)]
enum DataType {
    SpotEntry: felt252,
    FutureEntry: (felt252, u64),
    GenericEntry: felt252,
// OptionEntry: (felt252, felt252),
}

#[derive(Drop, Copy)]
enum PossibleEntryStorage {
    Spot: u256, //structure SpotEntryStorage
    Future: u256, //structure FutureEntryStorage
//  Option: OptionEntryStorage, //structure OptionEntryStorage
}

#[derive(Drop, Copy, Serde)]
enum SimpleDataType {
    SpotEntry: (),
    FutureEntry: (),
//  OptionEntry: (),
}

#[derive(Drop, Copy, Serde)]
enum PossibleEntries {
    Spot: SpotEntry,
    Future: FutureEntry,
    Generic: GenericEntry,
//  Option: OptionEntry,
}


#[derive(Drop, Serde)]
enum ArrayEntry {
    SpotEntry: Array<SpotEntry>,
    FutureEntry: Array<FutureEntry>,
    GenericEntry: Array<GenericEntry>,
//  OptionEntry: Array<OptionEntry>,
}


#[derive(Serde, Drop, Copy, starknet::Store)]
struct Pair {
    id: felt252, // same as key currently (e.g. str_to_felt("ETH/USD") - force uppercase)
    quote_currency_id: felt252, // currency id - str_to_felt encode the ticker
    base_currency_id: felt252, // currency id - str_to_felt encode the ticker
}

#[derive(Serde, Drop, Copy, starknet::Store)]
struct Currency {
    id: felt252,
    decimals: u32,
    is_abstract_currency: bool, // True (1) if not a specific token but abstract, e.g. USD or ETH as a whole
    starknet_address: ContractAddress, // optional, e.g. can have synthetics for non-bridged assets
    ethereum_address: ContractAddress, // optional
}

#[derive(Serde, Drop)]
struct Checkpoint {
    timestamp: u64,
    value: u128,
    aggregation_mode: AggregationMode,
    num_sources_aggregated: u32,
}

#[derive(Serde, Drop, Copy, starknet::Store)]
struct FetchCheckpoint {
    pair_id: felt252,
    type_of: felt252,
    index: u64,
    expiration_timestamp: u64,
    aggregation_mode: u8,
}

#[derive(Serde, Drop, Copy)]
struct PragmaPricesResponse {
    price: u128,
    decimals: u32,
    last_updated_timestamp: u64,
    num_sources_aggregated: u32,
    expiration_timestamp: Option<u64>,
}

#[derive(Serde, Drop, Copy)]
enum AggregationMode {
    Median: (),
    Mean: (),
    Error: (),
}


/// DataType should implement this trait
/// If it has a `base_entry` field defined by `BaseEntry` struct
trait HasBaseEntry<T> {
    fn get_base_entry(self: @T) -> BaseEntry;
    fn get_base_timestamp(self: @T) -> u64;
}

impl SpothasBaseEntry of HasBaseEntry<SpotEntry> {
    fn get_base_entry(self: @SpotEntry) -> BaseEntry {
        (*self).base
    }
    fn get_base_timestamp(self: @SpotEntry) -> u64 {
        (*self).base.timestamp
    }
}

impl FuturehasBaseEntry of HasBaseEntry<FutureEntry> {
    fn get_base_entry(self: @FutureEntry) -> BaseEntry {
        (*self).base
    }
    fn get_base_timestamp(self: @FutureEntry) -> u64 {
        (*self).base.timestamp
    }
}

impl GenericBaseEntry of HasBaseEntry<GenericEntry> {
    fn get_base_entry(self: @GenericEntry) -> BaseEntry {
        (*self).base
    }
    fn get_base_timestamp(self: @GenericEntry) -> u64 {
        (*self).base.timestamp
    }
}

impl ResponseHasBaseEntryImpl of HasBaseEntry<PragmaPricesResponse> {
    fn get_base_entry(self: @PragmaPricesResponse) -> BaseEntry {
        BaseEntry { timestamp: 0, source: 0, publisher: 0 }
    }
    fn get_base_timestamp(self: @PragmaPricesResponse) -> u64 {
        (*self).last_updated_timestamp
    }
}

impl OptionhasBaseEntry of HasBaseEntry<OptionEntry> {
    fn get_base_entry(self: @OptionEntry) -> BaseEntry {
        (*self).base
    }
    fn get_base_timestamp(self: @OptionEntry) -> u64 {
        (*self).base.timestamp
    }
}

/// DataType should implement this trait
/// If it has a `price` field defined in `self`
trait HasPrice<T> {
    fn get_price(self: @T) -> u128;
}

impl SHasPriceImpl of HasPrice<SpotEntry> {
    fn get_price(self: @SpotEntry) -> u128 {
        (*self).price
    }
}
impl FHasPriceImpl of HasPrice<FutureEntry> {
    fn get_price(self: @FutureEntry) -> u128 {
        (*self).price
    }
}

impl GHasPriceImpl of HasPrice<GenericEntry> {
    fn get_price(self: @GenericEntry) -> u128 {
        (*self).value
    }
}
impl ResponseHasPriceImpl of HasPrice<PragmaPricesResponse> {
    fn get_price(self: @PragmaPricesResponse) -> u128 {
        (*self).price
    }
}

impl SpotPartialOrd of PartialOrd<SpotEntry> {
    #[inline(always)]
    fn le(lhs: SpotEntry, rhs: SpotEntry) -> bool {
        lhs.price <= rhs.price
    }
    fn ge(lhs: SpotEntry, rhs: SpotEntry) -> bool {
        lhs.price >= rhs.price
    }
    fn lt(lhs: SpotEntry, rhs: SpotEntry) -> bool {
        lhs.price < rhs.price
    }
    fn gt(lhs: SpotEntry, rhs: SpotEntry) -> bool {
        lhs.price > rhs.price
    }
}

impl FuturePartialOrd of PartialOrd<FutureEntry> {
    #[inline(always)]
    fn le(lhs: FutureEntry, rhs: FutureEntry) -> bool {
        lhs.price <= rhs.price
    }
    fn ge(lhs: FutureEntry, rhs: FutureEntry) -> bool {
        lhs.price >= rhs.price
    }
    fn lt(lhs: FutureEntry, rhs: FutureEntry) -> bool {
        lhs.price < rhs.price
    }
    fn gt(lhs: FutureEntry, rhs: FutureEntry) -> bool {
        lhs.price > rhs.price
    }
}
