use starknet::{ContractAddress, StorePacking};
use array::ArrayTrait;

use traits::{TryInto, Into};

const SPOT: felt252 = 'SPOT';
const FUTURE: felt252 = 'FUTURE';
const GENERIC: felt252 = 'GENERIC';
const OPTION: felt252 = 'OPTION';
const USD_CURRENCY_ID: felt252 = 'USD';
// For the entry storage
const MAX_FELT: u256 =
    3618502788666131213697322783095070105623107215331596699973092056135872020480; //max felt value
const TIMESTAMP_SHIFT_U32: u256 = 0x100000000;
const TIMESTAMP_SHIFT_MASK_U32: u256 = 0xffffffff;
const VOLUME_SHIFT_U132: u256 = 0x1000000000000000000000000000000000;
const VOLUME_SHIFT_MASK_U100: u256 = 0xfffffffffffffffffffffffff;
const PRICE_SHIFT_MASK_U120: u256 = 0xffffffffffffffffffffffffffffff;


//For the checkpoint storage

const CHECKPOINT_TIMESTAMP_SHIFT_U32: felt252 = 0x100000000;
const CHECKPOINT_VALUE_SHIFT_U160: felt252 = 0x10000000000000000000000000000000000000000;
const CHECKPOINT_AGGREGATION_MODE_SHIFT_U172: felt252 =
    0x10000000000000000000000000000000000000000000;


#[derive(Copy, Drop, Serde)]
struct BaseEntry {
    timestamp: u64,
    source: felt252,
    publisher: felt252,
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

#[derive(Serde, Drop, Copy)]
struct PragmaPricesResponse {
    price: u128,
    decimals: u32,
    last_updated_timestamp: u64,
    num_sources_aggregated: u32,
    expiration_timestamp: Option<u64>,
}

#[derive(Serde, Drop, Copy, starknet::Store)]
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

impl AggregationModeIntoU8 of TryInto<AggregationMode, u8> {
    fn try_into(self: AggregationMode) -> Option<u8> {
        match self {
            AggregationMode::Median(()) => Option::Some(0_u8),
            AggregationMode::Mean(()) => Option::Some(1_u8),
            AggregationMode::Error(()) => Option::None(()),
        }
    }
}
impl u8IntoAggregationMode of Into<u8, AggregationMode> {
    fn into(self: u8) -> AggregationMode {
        if self == 0_u8 {
            AggregationMode::Median(())
        } else if self == 1_u8 {
            AggregationMode::Mean(())
        } else {
            AggregationMode::Error(())
        }
    }
}


impl EntryStorePacking of StorePacking<EntryStorage, felt252> {
    fn pack(value: EntryStorage) -> felt252 {
        // entries verifications (no overflow)
        assert(
            (value.timestamp.into() == value.timestamp.into() & TIMESTAMP_SHIFT_MASK_U32),
            'EntryStorePack:tmp too big'
        );
        assert(
            value.volume.into() == value.volume.into() & VOLUME_SHIFT_MASK_U100,
            'EntryStorePack:volume too big'
        );
        assert(
            value.price.into() == value.price.into() & PRICE_SHIFT_MASK_U120,
            'EntryStorePack:price too big'
        );
        let pack_value = value.timestamp.into()
            + value.volume.into() * TIMESTAMP_SHIFT_U32
            + value.price.into() * VOLUME_SHIFT_U132;
        assert(pack_value <= MAX_FELT, 'EntryStorePack:pack_val too big');
        pack_value.try_into().unwrap()
    }
    fn unpack(value: felt252) -> EntryStorage {
        let value: u256 = value.into();
        let volume_shift: NonZero<u256> = integer::u256_try_as_non_zero(VOLUME_SHIFT_U132.into())
            .unwrap();
        let (price, rest) = integer::u256_safe_div_rem(value, volume_shift);
        let timestamp_shift: NonZero<u256> = integer::u256_try_as_non_zero(
            TIMESTAMP_SHIFT_U32.into()
        )
            .unwrap();

        let (vol, time) = integer::u256_safe_div_rem(rest, timestamp_shift);
        EntryStorage {
            timestamp: time.try_into().unwrap(),
            volume: vol.try_into().unwrap(),
            price: price.try_into().unwrap()
        }
    }
}

impl CheckpointStorePacking of StorePacking<Checkpoint, felt252> {
    fn pack(value: Checkpoint) -> felt252 {
        let converted_agg_mode: u8 = value.aggregation_mode.try_into().unwrap();
        value.timestamp.into()
            + value.value.into() * CHECKPOINT_TIMESTAMP_SHIFT_U32
            + converted_agg_mode.into() * CHECKPOINT_VALUE_SHIFT_U160
            + value.num_sources_aggregated.into() * CHECKPOINT_AGGREGATION_MODE_SHIFT_U172
    }
    fn unpack(value: felt252) -> Checkpoint {
        let value: u256 = value.into();
        let agg_shift: NonZero<u256> = integer::u256_try_as_non_zero(
            CHECKPOINT_AGGREGATION_MODE_SHIFT_U172.into()
        )
            .unwrap();
        let (num_sources, rest) = integer::u256_safe_div_rem(value, agg_shift);
        let val_shift: NonZero<u256> = integer::u256_try_as_non_zero(
            CHECKPOINT_VALUE_SHIFT_U160.into()
        )
            .unwrap();

        let (agg_mode, rest_2) = integer::u256_safe_div_rem(rest, val_shift);
        let u8_agg_mode: u8 = agg_mode.try_into().unwrap();
        let aggregation_mode: AggregationMode = u8_agg_mode.into();
        let time_shift: NonZero<u256> = integer::u256_try_as_non_zero(
            CHECKPOINT_TIMESTAMP_SHIFT_U32.into()
        )
            .unwrap();

        let (val, time) = integer::u256_safe_div_rem(rest_2, time_shift);
        Checkpoint {
            timestamp: time.try_into().unwrap(),
            value: val.try_into().unwrap(),
            aggregation_mode: aggregation_mode,
            num_sources_aggregated: num_sources.try_into().unwrap()
        }
    }
}


#[test]
#[available_gas(20000000000)]
fn test_packing_entry_storage() {}
