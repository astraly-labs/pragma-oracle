use pragma::entry::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, GENERIC, PossibleEntryStorage, FutureEntry, OptionEntry,
    GenericEntry, SimpleDataType, AggregationMode, GenericEntryStorage, PossibleEntries, ArrayEntry,
    EntryStorage
};

use pragma::admin::admin::Admin;
use pragma::upgradeable::upgradeable::Upgradeable;
use serde::Serde;

use starknet::{
    storage_read_syscall, storage_write_syscall, storage_address_from_base_and_offset,
    storage_access::storage_base_address_from_felt252, Store, StorageBaseAddress, SyscallResult,
    ContractAddress, get_caller_address
};
use starknet::class_hash::ClassHash;
use traits::{Into, TryInto};
use result::{ResultTrait, ResultTraitImpl};
use box::BoxTrait;
use array::{SpanTrait, ArrayTrait};
use zeroable::Zeroable;

#[starknet::interface]
trait IOracleABI<TContractState> {
    fn get_decimals(self: @TContractState, data_type: DataType) -> u32;
    fn get_data_median(self: @TContractState, data_type: DataType) -> PragmaPricesResponse;
    fn get_data_median_for_sources(
        self: @TContractState, data_type: DataType, sources: Span<felt252>
    ) -> PragmaPricesResponse;
    fn get_data(
        self: @TContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> PragmaPricesResponse;
    fn get_data_median_multi(
        self: @TContractState, data_types: Span<DataType>, sources: Span<felt252>
    ) -> Span<PragmaPricesResponse>;
    fn get_data_entry(
        self: @TContractState, data_type: DataType, source: felt252
    ) -> PossibleEntries;
    fn get_data_for_sources(
        self: @TContractState,
        data_type: DataType,
        aggregation_mode: AggregationMode,
        sources: Span<felt252>
    ) -> PragmaPricesResponse;
    fn get_data_entries(self: @TContractState, data_type: DataType) -> Span<PossibleEntries>;
    fn get_data_entries_for_sources(
        self: @TContractState, data_type: DataType, sources: Span<felt252>
    ) -> (Span<PossibleEntries>, u64);
    fn get_last_checkpoint_before(
        self: @TContractState,
        data_type: DataType,
        timestamp: u64,
        aggregation_mode: AggregationMode,
    ) -> (Checkpoint, u64);
    fn get_data_with_USD_hop(
        self: @TContractState,
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: AggregationMode,
        typeof: SimpleDataType,
        expiration_timestamp: Option::<u64>
    ) -> PragmaPricesResponse;
    fn get_publisher_registry_address(self: @TContractState) -> ContractAddress;
    fn get_latest_checkpoint_index(
        self: @TContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> (u64, bool);
    fn get_latest_checkpoint(
        self: @TContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> Checkpoint;
    fn get_checkpoint(
        self: @TContractState,
        data_type: DataType,
        checkpoint_index: u64,
        aggregation_mode: AggregationMode
    ) -> Checkpoint;
    fn get_sources_threshold(self: @TContractState,) -> u32;
    fn get_admin_address(self: @TContractState,) -> ContractAddress;
    fn get_implementation_hash(self: @TContractState) -> ClassHash;
    fn publish_data(ref self: TContractState, new_entry: PossibleEntries);
    fn publish_data_entries(ref self: TContractState, new_entries: Span<PossibleEntries>);
    fn set_admin_address(ref self: TContractState, new_admin_address: ContractAddress);
    fn update_publisher_registry_address(
        ref self: TContractState, new_publisher_registry_address: ContractAddress
    );
    fn add_currency(ref self: TContractState, new_currency: Currency);
    fn update_currency(ref self: TContractState, currency_id: felt252, currency: Currency);
    fn add_pair(ref self: TContractState, new_pair: Pair);
    fn set_checkpoint(
        ref self: TContractState, data_type: DataType, aggregation_mode: AggregationMode
    );
    fn set_checkpoints(
        ref self: TContractState, data_types: Span<DataType>, aggregation_mode: AggregationMode
    );
    fn set_sources_threshold(ref self: TContractState, threshold: u32);
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
}


#[starknet::interface]
trait IPragmaABI<TContractState> {
    fn get_decimals(self: @TContractState, data_type: DataType) -> u32;

    fn get_data_median(self: @TContractState, data_type: DataType) -> PragmaPricesResponse;

    fn get_data_median_for_sources(
        self: @TContractState, data_type: DataType, sources: Span<felt252>
    ) -> PragmaPricesResponse;

    fn get_data(
        self: @TContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> PragmaPricesResponse;

    fn get_data_entry(
        self: @TContractState, data_type: DataType, source: felt252
    ) -> PossibleEntries;

    fn get_data_for_sources(
        self: @TContractState,
        data_type: DataType,
        aggregation_mode: AggregationMode,
        sources: Span<felt252>
    ) -> PragmaPricesResponse;

    fn get_data_entries_for_sources(
        self: @TContractState, data_type: DataType, sources: Span<felt252>
    ) -> (Span<PossibleEntries>, u64);

    fn get_data_median_multi(
        self: @TContractState, data_types: Span<DataType>, sources: Span<felt252>
    ) -> Span<PragmaPricesResponse>;


    fn get_data_entries(self: @TContractState, data_type: DataType) -> Span<PossibleEntries>;

    fn get_last_checkpoint_before(
        self: @TContractState,
        data_type: DataType,
        timestamp: u64,
        aggregation_mode: AggregationMode,
    ) -> (Checkpoint, u64);

    fn get_data_with_USD_hop(
        self: @TContractState,
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: AggregationMode,
        typeof: SimpleDataType,
        expiration_timestamp: Option::<u64>
    ) -> PragmaPricesResponse;

    fn get_latest_checkpoint(
        self: @TContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> Checkpoint;

    fn get_latest_checkpoint_index(
        self: @TContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> (u64, bool);
}


#[starknet::contract]
mod Oracle {
    use super::{
        BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
        USD_CURRENCY_ID, SPOT, FUTURE, OPTION, GENERIC, PossibleEntryStorage, FutureEntry,
        OptionEntry, GenericEntry, SimpleDataType, AggregationMode, PossibleEntries, ArrayEntry,
        Admin, Upgradeable, Serde, storage_read_syscall, storage_write_syscall,
        storage_address_from_base_and_offset, storage_base_address_from_felt252, Store,
        StorageBaseAddress, SyscallResult, ContractAddress, get_caller_address, ClassHash, Into,
        TryInto, ResultTrait, ResultTraitImpl, BoxTrait, ArrayTrait, SpanTrait, Zeroable,
        IOracleABI, GenericEntryStorage, EntryStorage
    };
    use hash::LegacyHash;
    use pragma::entry::entry::Entry;
    use pragma::operations::time_series::convert::convert_via_usd;
    use pragma::publisher_registry::publisher_registry::{
        IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
    };

    use starknet::{get_block_timestamp, Felt252TryIntoContractAddress, StorePacking};

    use cmp::{max, min};
    use option::OptionTrait;
    use debug::PrintTrait;
    const BACKWARD_TIMESTAMP_BUFFER: u64 = 7800; // 2 hours and 10 minutes

    // Store Packing constants

    // For the entry storage
    const MAX_FELT: u256 =
        3618502788666131213697322783095070105623107215331596699973092056135872020480; //max felt value
    const TIMESTAMP_SHIFT_U32: felt252 = 0x100000000;
    const VOLUME_SHIFT_U132: felt252 = 0x1000000000000000000000000000000000;


    //For the checkpoint storage

    const CHECKPOINT_TIMESTAMP_SHIFT_U32: felt252 = 0x100000000;
    const CHECKPOINT_VALUE_SHIFT_U160: felt252 = 0x10000000000000000000000000000000000000000;
    const CHECKPOINT_AGGREGATION_MODE_SHIFT_U172: felt252 =
        0x10000000000000000000000000000000000000000000;


    #[storage]
    struct Storage {
        //oracle controller address storage, contractAddress
        oracle_controller_address_storage: ContractAddress,
        // oracle publisher registry address, ContractAddres
        oracle_publisher_registry_address_storage: ContractAddress,
        //oracle pair storage, legacy map between the pair_id and the pair in question (no need to specify the data type here).
        oracle_pairs_storage: LegacyMap::<felt252, Pair>,
        //oracle_pair_id_storage, legacy Map between (quote_currency_id, base_currency_id) and the pair_id
        oracle_pair_id_storage: LegacyMap::<(felt252, felt252), felt252>,
        //oracle_currencies_storage, legacy Map between (currency_id) and the currency
        oracle_currencies_storage: LegacyMap::<felt252, Currency>,
        //oralce_sources_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS/GENERIC), index, expiration_timestamp ) and the source
        oracle_sources_storage: LegacyMap::<(felt252, felt252, u64, u64), felt252>,
        //oracle_sources_len_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS/GENERIC), expiration_timestamp) and the len of the sources array
        oracle_sources_len_storage: LegacyMap::<(felt252, felt252, u64), u64>,
        //oracle_data_entry_storage, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS/GENERIC), source, expiration_timestamp (0 for SPOT))
        oracle_data_entry_storage: LegacyMap::<(felt252, felt252, felt252, u64), EntryStorage>,
        //oracle_data_entry_storage len , legacyMap between pair_id, (SPOT/FUTURES/OPTIONS/GENERIC), expiration_timestamp and the length
        oracle_data_len_all_sources: LegacyMap::<(felt252, felt252, u64), u64>,
        //oracle_checkpoints, legacyMap between, (pair_id, (SPOT/FUTURES/OPTIONS), index, expiration_timestamp (0 for SPOT), aggregation_mode) associated to a checkpoint
        oracle_checkpoints: LegacyMap::<(felt252, felt252, u64, u64, u8), Checkpoint>,
        //oracle_checkpoint_index, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), expiration_timestamp (0 for SPOT)) and the index of the last checkpoint
        oracle_checkpoint_index: LegacyMap::<(felt252, felt252, u64, u8), u64>,
        oracle_sources_threshold_storage: u32,
    }

    /// DataType should implement this trait
    /// If it has a `base_entry` field defined by `BaseEntry` struct
    trait hasBaseEntry<T> {
        fn get_base_entry(self: @T) -> BaseEntry;
        fn get_base_timestamp(self: @T) -> u64;
    }

    impl SpothasBaseEntry of hasBaseEntry<SpotEntry> {
        fn get_base_entry(self: @SpotEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @SpotEntry) -> u64 {
            (*self).base.timestamp
        }
    }

    impl FuturehasBaseEntry of hasBaseEntry<FutureEntry> {
        fn get_base_entry(self: @FutureEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @FutureEntry) -> u64 {
            (*self).base.timestamp
        }
    }

    impl GenericBaseEntry of hasBaseEntry<GenericEntry> {
        fn get_base_entry(self: @GenericEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @GenericEntry) -> u64 {
            (*self).base.timestamp
        }
    }


    impl OptionhasBaseEntry of hasBaseEntry<OptionEntry> {
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

    impl AggregationModeIntoU8 of Into<AggregationMode, u8> {
        fn into(self: AggregationMode) -> u8 {
            match self {
                AggregationMode::Median(()) => 0_u8,
                AggregationMode::Mean(()) => 1_u8,
                AggregationMode::Error(()) => 150_u8,
            }
        }
    }
    impl TupleSize4LegacyHash<
        E0,
        E1,
        E2,
        E3,
        E4,
        impl E0LegacyHash: LegacyHash<E0>,
        impl E1LegacyHash: LegacyHash<E1>,
        impl E2LegacyHash: LegacyHash<E2>,
        impl E3LegacyHash: LegacyHash<E3>,
        impl E4LegacyHash: LegacyHash<E4>,
        impl E0Drop: Drop<E0>,
        impl E1Drop: Drop<E1>,
        impl E2Drop: Drop<E2>,
        impl E3Drop: Drop<E3>,
        impl E4Drop: Drop<E4>,
    > of LegacyHash<(E0, E1, E2, E3, E4)> {
        fn hash(state: felt252, value: (E0, E1, E2, E3, E4)) -> felt252 {
            let (e0, e1, e2, e3, e4) = value;
            let state = E0LegacyHash::hash(state, e0);
            let state = E1LegacyHash::hash(state, e1);
            let state = E2LegacyHash::hash(state, e2);
            let state = E3LegacyHash::hash(state, e3);
            E4LegacyHash::hash(state, e4)
        }
    }

    fn u8_into_AggregationMode(value: u8) -> AggregationMode {
        if value == 0_u8 {
            AggregationMode::Median(())
        } else if value == 1_u8 {
            AggregationMode::Mean(())
        } else {
            AggregationMode::Error(())
        }
    }

    impl EntryStorePacking of StorePacking<EntryStorage, felt252> {
        fn pack(value: EntryStorage) -> felt252 {
            let pack_value: felt252 = value.timestamp.into()
                + value.volume.into() * TIMESTAMP_SHIFT_U32
                + value.price.into() * VOLUME_SHIFT_U132;
            assert(pack_value.into() <= MAX_FELT, 'EntryStorePacking:value too big');
            pack_value
        }
        fn unpack(value: felt252) -> EntryStorage {
            let value: u256 = value.into();
            let volume_shift: NonZero<u256> = integer::u256_try_as_non_zero(
                VOLUME_SHIFT_U132.into()
            )
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
            let converted_agg_mode: u8 = value.aggregation_mode.into();
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
            let u8_agg_mode = agg_mode.try_into().unwrap();
            let aggregation_mode: AggregationMode = u8_into_AggregationMode(u8_agg_mode);
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


    #[derive(Drop, starknet::Event)]
    struct UpdatedPublisherRegistryAddress {
        old_publisher_registry_address: ContractAddress,
        new_publisher_registry_address: ContractAddress
    }


    #[derive(Drop, starknet::Event)]
    struct SubmittedSpotEntry {
        spot_entry: SpotEntry
    }


    #[derive(Drop, starknet::Event)]
    struct SubmittedFutureEntry {
        future_entry: FutureEntry
    }

    #[derive(Drop, starknet::Event)]
    struct SubmittedOptionEntry {
        option_entry: OptionEntry
    }

    #[derive(Drop, starknet::Event)]
    struct SubmittedGenericEntry {
        generic_entry: GenericEntry
    }


    #[derive(Drop, starknet::Event)]
    struct SubmittedCurrency {
        currency: Currency
    }


    #[derive(Drop, starknet::Event)]
    struct UpdatedCurrency {
        currency: Currency
    }

    #[derive(Drop, starknet::Event)]
    struct SubmittedPair {
        pair: Pair
    }
    #[derive(Drop, starknet::Event)]
    struct ChangedAdmin {
        new_admin: ContractAddress
    }


    #[derive(Drop, starknet::Event)]
    struct CheckpointSpotEntry {
        pair_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct CheckpointFutureEntry {
        pair_id: felt252,
        expiration_timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        UpdatedPublisherRegistryAddress: UpdatedPublisherRegistryAddress,
        SubmittedSpotEntry: SubmittedSpotEntry,
        SubmittedFutureEntry: SubmittedFutureEntry,
        SubmittedOptionEntry: SubmittedOptionEntry,
        SubmittedGenericEntry: SubmittedGenericEntry,
        SubmittedCurrency: SubmittedCurrency,
        UpdatedCurrency: UpdatedCurrency,
        SubmittedPair: SubmittedPair,
        CheckpointSpotEntry: CheckpointSpotEntry,
        CheckpointFutureEntry: CheckpointFutureEntry,
        ChangedAdmin: ChangedAdmin
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin_address: ContractAddress,
        publisher_registry_address: ContractAddress,
        currencies: Span<Currency>,
        pairs: Span<Pair>
    ) {
        let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
        Admin::initialize_admin_address(ref state, admin_address);

        self.oracle_publisher_registry_address_storage.write(publisher_registry_address);
        self._set_keys_currencies(currencies);
        self._set_keys_pairs(pairs);
        return ();
    }

    #[generate_trait]
    impl IOracleInternal of IOracleInternalTrait {
        fn _set_keys_currencies(ref self: ContractState, key_currencies: Span<Currency>) {
            let mut idx: u32 = 0;
            loop {
                if (idx == key_currencies.len()) {
                    break ();
                }

                let key_currency = *key_currencies.get(idx).unwrap().unbox();
                self.oracle_currencies_storage.write(key_currency.id, key_currency);
                idx = idx + 1;
            };
            return ();
        }

        // @notice Check if the caller is the admin, use the contract Admin
        //@dev internal function, fails if not called by the admin
        fn assert_only_admin(self: @ContractState) {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            let admin = Admin::get_admin_address(@state);
            let caller = get_caller_address();
            assert(caller == admin, 'Admin: unauthorized');
        }

        // @notice set the keys pairs, called by the constructor of the contract
        // @dev internal function
        fn _set_keys_pairs(ref self: ContractState, key_pairs: Span<Pair>) {
            let mut idx: u32 = 0;
            loop {
                if (idx >= key_pairs.len()) {
                    break ();
                }
                let key_pair = *key_pairs.get(idx).unwrap().unbox();
                self.oracle_pairs_storage.write(key_pair.id, key_pair);
                self
                    .oracle_pair_id_storage
                    .write((key_pair.quote_currency_id, key_pair.base_currency_id), key_pair.id);
                idx = idx + 1;
            };
            return ();
        }
    }

    #[external(v0)]
    impl IOracleImpl of IOracleABI<ContractState> {
        //
        // Getters
        //

        // @notice get all the data entries for given sources 
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param sources : a span of sources, if no sources are provided, all the sources will be considered. 
        // @returns a span of PossibleEntries, which can be spot entries, future entries, generic entries ...
        // @returns the last updated timestamp
        fn get_data_entries_for_sources(
            self: @ContractState, data_type: DataType, sources: Span<felt252>
        ) -> (Span<PossibleEntries>, u64) {
            if (sources.len() == 0) {
                let all_sources = get_all_sources(self, data_type);
                let last_updated_timestamp = get_latest_entry_timestamp(
                    self, data_type, all_sources.span()
                );
                let current_timestamp: u64 = get_block_timestamp();
                let conservative_current_timestamp = min(last_updated_timestamp, current_timestamp);
                let (entries, entries_len) = get_all_entries(
                    self, data_type, all_sources.span(), conservative_current_timestamp
                );
                return (entries.span(), conservative_current_timestamp);
            } else {
                let last_updated_timestamp = get_latest_entry_timestamp(self, data_type, sources);
                let current_timestamp: u64 = get_block_timestamp();
                let conservative_current_timestamp = min(last_updated_timestamp, current_timestamp);
                let (entries, entries_len) = get_all_entries(
                    self, data_type, sources, conservative_current_timestamp
                );
                return (entries.span(), conservative_current_timestamp);
            }
        }

        // @notice retrieve all the data enries for a given data type ( a data type is an asset id and a type)
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @returns a span of PossibleEntries, which can be spot entries, future entries, generic entries...
        fn get_data_entries(self: @ContractState, data_type: DataType) -> Span<PossibleEntries> {
            let mut sources = ArrayTrait::<felt252>::new();
            let sources = get_all_sources(self, data_type).span();
            let (entries, _) = IOracleABI::get_data_entries_for_sources(self, data_type, sources);
            entries
        }

        // @notice aggregate all the entries for a given data type, using MEDIAN as aggregation mode
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @returns a PragmaPricesResponse, a structure providing the main information for an asset (see entry/structs for details)
        fn get_data_median(self: @ContractState, data_type: DataType) -> PragmaPricesResponse {
            let sources = get_all_sources(self, data_type).span();
            let prices_response: PragmaPricesResponse = IOracleABI::get_data_for_sources(
                self, data_type, AggregationMode::Median(()), sources
            );
            prices_response
        }

        // @notice aggregate the entries for specific sources,  for a given data type, using MEDIAN as aggregation mode
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @params sources : a span of sources used for the aggregation
        // @returns a PragmaPricesResponse, a structure providing the main information for an asset (see entry/structs for details)
        fn get_data_median_for_sources(
            self: @ContractState, data_type: DataType, sources: Span<felt252>
        ) -> PragmaPricesResponse {
            let prices_response: PragmaPricesResponse = IOracleABI::get_data_for_sources(
                self, data_type, AggregationMode::Median(()), sources
            );
            prices_response
        }

        // @notice aggregate the entries for specific sources, for multiple  data type, using MEDIAN as aggregation mode
        // @param data_type: an span of DataType
        // @params sources : a span of sources used for the aggregation
        // @returns a span of PragmaPricesResponse, a structure providing the main information for each asset (see entry/structs for details)
        fn get_data_median_multi(
            self: @ContractState, data_types: Span<DataType>, sources: Span<felt252>
        ) -> Span<PragmaPricesResponse> {
            let mut prices_response = ArrayTrait::<PragmaPricesResponse>::new();
            let mut cur_idx = 0;
            loop {
                if (cur_idx >= data_types.len()) {
                    break ();
                }
                let data_type = *data_types.at(cur_idx);
                let cur_prices_response: PragmaPricesResponse = IOracleABI::get_data_for_sources(
                    self, data_type, AggregationMode::Median(()), sources
                );
                prices_response.append(cur_prices_response);
                cur_idx += 1;
            };
            prices_response.span()
        }

        // @notice aggregate all the entries for a given data type, with a given aggregation mode
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param aggregation_mode: the aggregation method to be used (e.g. AggregationMode::Median(()))
        // @returns a PragmaPricesResponse, a structure providing the main information for an asset (see entry/structs for details)
        fn get_data(
            self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode
        ) -> PragmaPricesResponse {
            let sources = get_all_sources(self, data_type).span();
            let prices_response: PragmaPricesResponse = IOracleABI::get_data_for_sources(
                self, data_type, aggregation_mode, sources
            );

            prices_response
        }

        // @notice aggregate all the entries for a given data type and given sources, with a given aggregation mode
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param aggregation_mode: the aggregation method to be used (e.g. AggregationMode::Median(()))
        // @params sources : a span of sources used for the aggregation
        // @returns a PragmaPricesResponse, a structure providing the main information for an asset (see entry/structs for details)
        fn get_data_for_sources(
            self: @ContractState,
            data_type: DataType,
            aggregation_mode: AggregationMode,
            sources: Span<felt252>
        ) -> PragmaPricesResponse {
            let mut entries = ArrayTrait::<PossibleEntries>::new();

            let (entries, last_updated_timestamp) = IOracleABI::get_data_entries_for_sources(
                self, data_type, sources
            );

            if (entries.len() == 0) {
                return PragmaPricesResponse {
                    price: 0,
                    decimals: 0,
                    last_updated_timestamp: 0,
                    num_sources_aggregated: 0,
                    expiration_timestamp: Option::Some(0),
                };
            }

            // TODO: Return only array instead of `ArrayEntry`
            let filtered_entries: ArrayEntry = filter_data_array(data_type, entries);

            match data_type {
                DataType::SpotEntry(pair_id) => {
                    match filtered_entries {
                        ArrayEntry::SpotEntry(array_spot) => {
                            let price = Entry::aggregate_entries::<SpotEntry>(
                                array_spot.span(), aggregation_mode
                            );
                            let decimals = IOracleABI::get_decimals(self, data_type);
                            let last_updated_timestamp =
                                Entry::aggregate_timestamps_max::<SpotEntry>(
                                array_spot.span()
                            );

                            return PragmaPricesResponse {
                                price: price,
                                decimals: decimals,
                                last_updated_timestamp: last_updated_timestamp,
                                num_sources_aggregated: entries.len(),
                                expiration_timestamp: Option::Some(0),
                            // Should be None
                            };
                        },
                        //SHOULD BE SIMPLIFIED ONCE WE CAN WORK WITH ONE MATCH CASE
                        ArrayEntry::FutureEntry(_) => {
                            assert(false, 'Wrong data type');
                            return PragmaPricesResponse {
                                price: 0,
                                decimals: 0,
                                last_updated_timestamp: 0,
                                num_sources_aggregated: 0,
                                expiration_timestamp: Option::Some(0),
                            };
                        },
                        ArrayEntry::GenericEntry(_) => {
                            assert(false, 'Wrong data type');
                            return PragmaPricesResponse {
                                price: 0,
                                decimals: 0,
                                last_updated_timestamp: 0,
                                num_sources_aggregated: 0,
                                expiration_timestamp: Option::Some(0),
                            };
                        },
                    }
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    match filtered_entries {
                        ArrayEntry::SpotEntry(_) => {
                            assert(false, 'Wrong data type');
                            return PragmaPricesResponse {
                                price: 0,
                                decimals: 0,
                                last_updated_timestamp: 0,
                                num_sources_aggregated: 0,
                                expiration_timestamp: Option::Some(0),
                            };
                        },
                        ArrayEntry::FutureEntry(array_future) => {
                            let price = Entry::aggregate_entries::<FutureEntry>(
                                array_future.span(), aggregation_mode
                            );
                            let decimals = IOracleABI::get_decimals(self, data_type);
                            let last_updated_timestamp =
                                Entry::aggregate_timestamps_max::<FutureEntry>(
                                array_future.span()
                            );
                            return PragmaPricesResponse {
                                price: price,
                                decimals: decimals,
                                last_updated_timestamp: last_updated_timestamp,
                                num_sources_aggregated: entries.len(),
                                expiration_timestamp: Option::Some(expiration_timestamp)
                            };
                        },
                        ArrayEntry::GenericEntry(_) => {
                            assert(false, 'Wrong data type');
                            return PragmaPricesResponse {
                                price: 0,
                                decimals: 0,
                                last_updated_timestamp: 0,
                                num_sources_aggregated: 0,
                                expiration_timestamp: Option::Some(0),
                            };
                        }
                    }
                },
                DataType::GenericEntry(key) => {
                    match filtered_entries {
                        ArrayEntry::SpotEntry(_) => {
                            assert(false, 'Wrong data type');
                            return PragmaPricesResponse {
                                price: 0,
                                decimals: 0,
                                last_updated_timestamp: 0,
                                num_sources_aggregated: 0,
                                expiration_timestamp: Option::Some(0),
                            };
                        },
                        ArrayEntry::FutureEntry(_) => {
                            assert(false, 'Wrong data type');
                            return PragmaPricesResponse {
                                price: 0,
                                decimals: 0,
                                last_updated_timestamp: 0,
                                num_sources_aggregated: 0,
                                expiration_timestamp: Option::Some(0),
                            };
                        },
                        ArrayEntry::GenericEntry(array_generic) => {
                            let price = Entry::aggregate_entries::<GenericEntry>(
                                array_generic.span(), aggregation_mode
                            );
                            let decimals = IOracleABI::get_decimals(self, data_type);
                            let last_updated_timestamp =
                                Entry::aggregate_timestamps_max::<GenericEntry>(
                                array_generic.span()
                            );
                            return PragmaPricesResponse {
                                price: price,
                                decimals: decimals,
                                last_updated_timestamp: last_updated_timestamp,
                                num_sources_aggregated: entries.len(),
                                expiration_timestamp: Option::Some(0)
                            };
                        },
                    }
                },
            }
        }

        // @notice get the publisher registry address associated with the oracle
        // @returns the linked publisher registry address
        fn get_publisher_registry_address(self: @ContractState) -> ContractAddress {
            self.oracle_publisher_registry_address_storage.read()
        }

        // @notice retrieve the precision (number of decimals) for a pair
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @returns the precision for the given data type
        fn get_decimals(self: @ContractState, data_type: DataType) -> u32 {
            let base_currency = match data_type {
                DataType::SpotEntry(pair_id) => {
                    let pair = self.oracle_pairs_storage.read(pair_id);
                    assert(!pair.id.is_zero(), 'No pair found');
                    let base_cur = self.oracle_currencies_storage.read(pair.base_currency_id);
                    base_cur
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    let pair = self.oracle_pairs_storage.read(pair_id);
                    assert(!pair.id.is_zero(), 'No pair found');
                    let base_cur = self.oracle_currencies_storage.read(pair.base_currency_id);
                    base_cur
                },
                DataType::GenericEntry(key) => {
                    let pair = self.oracle_pairs_storage.read(key);
                    assert(!pair.id.is_zero(), 'No pair found');
                    let base_cur = self.oracle_currencies_storage.read(pair.base_currency_id);
                    base_cur
                }
            // DataType::OptionEntry((pair_id, expiration_timestamp)) => {}
            };
            base_currency.decimals
        }

        // @notice aggregate entries information using an USD hop (BTC/ETH => BTC/USD + ETH/USD)
        // @param base_currency_id: the pragma key for the base currency
        // @param quote_currency_id : the pragma key for the quote currency id 
        // @param aggregation_mode :the aggregation method to be used (e.g. AggregationMode::Median(()))
        // @param typeof : the type of data to work with ( Spot, Future, ...)
        // @param expiration_timestamp : optional, for futures
        // @returns a PragmaPricesResponse, a structure providing the main information for an asset (see entry/structs for details)
        fn get_data_with_USD_hop(
            self: @ContractState,
            base_currency_id: felt252,
            quote_currency_id: felt252,
            aggregation_mode: AggregationMode,
            typeof: SimpleDataType,
            expiration_timestamp: Option<u64>
        ) -> PragmaPricesResponse {
            let mut sources = ArrayTrait::<felt252>::new().span();
            let base_pair_id = self
                .oracle_pair_id_storage
                .read((base_currency_id, USD_CURRENCY_ID));

            let quote_pair_id = self
                .oracle_pair_id_storage
                .read((quote_currency_id, USD_CURRENCY_ID));

            let (base_data_type, quote_data_type, currency) = match typeof {
                SimpleDataType::SpotEntry(()) => {
                    (
                        DataType::SpotEntry(base_pair_id),
                        DataType::SpotEntry(quote_pair_id),
                        self.oracle_currencies_storage.read(quote_currency_id)
                    )
                },
                SimpleDataType::FutureEntry(()) => {
                    match expiration_timestamp {
                        Option::Some(expiration) => {
                            let base_dt = DataType::FutureEntry((base_pair_id, expiration));
                            let quote_dt = DataType::FutureEntry((quote_pair_id, expiration));
                            (
                                base_dt,
                                quote_dt,
                                self.oracle_currencies_storage.read(quote_currency_id)
                            )
                        },
                        Option::None(_) => {
                            // Handle case where Future data type was provided without an expiration timestamp
                            assert(false, 'Requires expiration timestamp');
                            (
                                DataType::FutureEntry((base_pair_id, 0)),
                                DataType::FutureEntry((quote_pair_id, 0)),
                                self.oracle_currencies_storage.read(quote_currency_id)
                            )
                        }
                    }
                },
            };
            let basePPR: PragmaPricesResponse = IOracleABI::get_data_for_sources(
                self, base_data_type, aggregation_mode, sources
            );

            let quotePPR: PragmaPricesResponse = IOracleABI::get_data_for_sources(
                self, quote_data_type, aggregation_mode, sources
            );

            let decimals = min(
                IOracleABI::get_decimals(self, base_data_type),
                IOracleABI::get_decimals(self, quote_data_type)
            );
            let rebased_value = convert_via_usd(basePPR.price, quotePPR.price, decimals);
            let last_updated_timestamp = max(
                quotePPR.last_updated_timestamp, basePPR.last_updated_timestamp
            );
            let num_sources_aggregated = max(
                quotePPR.num_sources_aggregated, basePPR.num_sources_aggregated
            );
            PragmaPricesResponse {
                price: rebased_value,
                decimals: decimals,
                last_updated_timestamp: last_updated_timestamp,
                num_sources_aggregated: num_sources_aggregated,
                expiration_timestamp: expiration_timestamp,
            }
        }

        // @notice get the last checkpoint index (a checkpoint is a 'save' of the oracle information used for summary stats computations -realised volatility, twap, mean...)
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param aggregation_mode: the aggregation method to be used 
        // @returns last checkpoint index
        // @returns a boolean to verify if a checkpoint is actually set (case 0)
        fn get_latest_checkpoint_index(
            self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode
        ) -> (u64, bool) {
            get_latest_checkpoint_index(self, data_type, aggregation_mode)
        }

        // @notice get the latest checkpoint recorded 
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param aggregation_mode: the aggregation method to be used         
        // @returns the latest checkpoint (see entry/structs for the structure details)
        fn get_latest_checkpoint(
            self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode
        ) -> Checkpoint {
            let (checkpoint_index, is_valid) = get_latest_checkpoint_index(
                self, data_type, aggregation_mode
            );
            if (!is_valid) {
                Checkpoint {
                    timestamp: 0,
                    value: 0,
                    aggregation_mode: aggregation_mode,
                    num_sources_aggregated: 0,
                }
            } else {
                get_checkpoint_by_index(self, data_type, checkpoint_index, aggregation_mode)
            }
        }

        // @notice retrieve a specific checkpoint by its index
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param checkpoint_index: the index of the checkpoint to be considered
        // @param aggregation_mode: the aggregation method to be used 
        // @returns the checkpoint related
        fn get_checkpoint(
            self: @ContractState,
            data_type: DataType,
            checkpoint_index: u64,
            aggregation_mode: AggregationMode
        ) -> Checkpoint {
            get_checkpoint_by_index(self, data_type, checkpoint_index, aggregation_mode)
        }


        fn get_sources_threshold(self: @ContractState) -> u32 {
            self.oracle_sources_threshold_storage.read()
        }

        // @notice get the oracle admin address
        // @returns the ContractAddress of the admin
        fn get_admin_address(self: @ContractState) -> ContractAddress {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::get_admin_address(@state)
        }

        // @notice get the implementation hash of the oracle 
        // @returns the related class hash 
        fn get_implementation_hash(self: @ContractState) -> ClassHash {
            let state: Upgradeable::ContractState = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::get_implementation_hash(@state)
        }

        // @notice retrieve the last checkpoint before a given timestamp
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param timestamp : the timestamp to consider
        // @param aggregation_mode: the aggregation method to be used 
        // @returns the checkpoint 
        // @returns the index related to the checkpoint
        fn get_last_checkpoint_before(
            self: @ContractState,
            data_type: DataType,
            timestamp: u64,
            aggregation_mode: AggregationMode,
        ) -> (Checkpoint, u64) {
            let idx = find_startpoint(self, data_type, aggregation_mode, timestamp);

            let checkpoint = get_checkpoint_by_index(self, data_type, idx, aggregation_mode);

            (checkpoint, idx)
        }

        // @notice get the data entry for a given data type and a source
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param source: the source to retrieve the entry from
        // @returns a PossibleEntries, linked to the type of data needed (Spot, futures, generic, ...)
        fn get_data_entry(
            self: @ContractState, data_type: DataType, source: felt252
        ) -> PossibleEntries {
            let _entry = match data_type {
                DataType::SpotEntry(pair_id) => {
                    get_entry_storage(self, pair_id, SPOT, source, 0)
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    get_entry_storage(self, pair_id, FUTURE, source, expiration_timestamp)
                },
                DataType::GenericEntry(key) => {
                    get_entry_storage(self, key, GENERIC, source, 0)
                }
            };
            assert(!_entry.timestamp.is_zero(), 'No data entry found');
            match data_type {
                DataType::SpotEntry(pair_id) => {
                    PossibleEntries::Spot(
                        SpotEntry {
                            base: BaseEntry {
                                timestamp: _entry.timestamp, source: source, publisher: 0
                            },
                            pair_id: pair_id,
                            price: _entry.price,
                            volume: _entry.volume
                        }
                    )
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    PossibleEntries::Future(
                        FutureEntry {
                            base: BaseEntry {
                                timestamp: _entry.timestamp, source: source, publisher: 0
                            },
                            pair_id: pair_id,
                            price: _entry.price,
                            volume: _entry.volume,
                            expiration_timestamp: expiration_timestamp
                        }
                    )
                },
                DataType::GenericEntry(key) => {
                    PossibleEntries::Generic(
                        GenericEntry {
                            base: BaseEntry {
                                timestamp: _entry.timestamp, source: source, publisher: 0
                            },
                            key: key,
                            value: _entry.price
                        }
                    )
                }
            }
        }

        //
        // Setters
        //

        // @notice publish oracle data on chain
        // @notice in order to publish, the publisher must be registered for the specific source/asset. 
        // @param new_entry, the new entry that needs to be published
        fn publish_data(ref self: ContractState, new_entry: PossibleEntries) {
            match new_entry {
                PossibleEntries::Spot(spot_entry) => {
                    validate_sender_for_source(@self, spot_entry);
                    let res = get_entry_storage(
                        @self, spot_entry.pair_id, SPOT, spot_entry.base.source, 0
                    );

                    if (res.timestamp != 0) {
                        let entry: PossibleEntries = IOracleABI::get_data_entry(
                            @self, DataType::SpotEntry(spot_entry.pair_id), spot_entry.base.source
                        );
                        match entry {
                            PossibleEntries::Spot(spot) => {
                                validate_data_timestamp(ref self, new_entry, spot);
                            },
                            PossibleEntries::Future(_) => {},
                            PossibleEntries::Generic(_) => {},
                        }
                    } else {
                        let sources_len = self
                            .oracle_sources_len_storage
                            .read((spot_entry.pair_id, SPOT, 0));
                        self
                            .oracle_sources_storage
                            .write(
                                (spot_entry.pair_id, SPOT, sources_len, 0),
                                spot_entry.get_base_entry().source
                            );
                        self
                            .oracle_sources_len_storage
                            .write((spot_entry.pair_id, SPOT, 0), sources_len + 1);
                    }
                    self.emit(Event::SubmittedSpotEntry(SubmittedSpotEntry { spot_entry }));
                    let element = EntryStorage {
                        timestamp: spot_entry.base.timestamp.into(),
                        volume: spot_entry.volume.into(),
                        price: spot_entry.price.into()
                    };
                    set_entry_storage(
                        ref self, spot_entry.pair_id, SPOT, spot_entry.base.source, 0, element
                    );

                    let storage_len = self
                        .oracle_data_len_all_sources
                        .read((spot_entry.pair_id, SPOT, 0));
                    self
                        .oracle_data_len_all_sources
                        .write((spot_entry.pair_id, SPOT, 0), storage_len + 1);
                },
                PossibleEntries::Future(future_entry) => {
                    validate_sender_for_source(@self, future_entry);
                    let res = get_entry_storage(
                        @self,
                        future_entry.pair_id,
                        FUTURE,
                        future_entry.base.source,
                        future_entry.expiration_timestamp
                    );
                    if (res.timestamp != 0) {
                        let entry: PossibleEntries = IOracleABI::get_data_entry(
                            @self,
                            DataType::FutureEntry(
                                (future_entry.pair_id, future_entry.expiration_timestamp)
                            ),
                            future_entry.base.source
                        );
                        match entry {
                            PossibleEntries::Spot(_) => {},
                            PossibleEntries::Future(future) => {
                                validate_data_timestamp(ref self, new_entry, future)
                            },
                            PossibleEntries::Generic(_) => {}
                        }
                    } else {
                        let sources_len = self
                            .oracle_sources_len_storage
                            .read(
                                (future_entry.pair_id, FUTURE, future_entry.expiration_timestamp)
                            );
                        self
                            .oracle_sources_storage
                            .write(
                                (
                                    future_entry.pair_id,
                                    FUTURE,
                                    sources_len,
                                    future_entry.expiration_timestamp
                                ),
                                future_entry.get_base_entry().source
                            );
                        self
                            .oracle_sources_len_storage
                            .write(
                                (future_entry.pair_id, FUTURE, future_entry.expiration_timestamp),
                                sources_len + 1
                            );
                    }

                    self.emit(Event::SubmittedFutureEntry(SubmittedFutureEntry { future_entry }));

                    let element: EntryStorage = EntryStorage {
                        timestamp: future_entry.base.timestamp.into(),
                        volume: future_entry.volume.into(),
                        price: future_entry.price.into()
                    };
                    set_entry_storage(
                        ref self,
                        future_entry.pair_id,
                        FUTURE,
                        future_entry.base.source,
                        future_entry.expiration_timestamp,
                        element
                    );
                    let storage_len = self
                        .oracle_data_len_all_sources
                        .read((future_entry.pair_id, FUTURE, future_entry.expiration_timestamp));
                    self
                        .oracle_data_len_all_sources
                        .write(
                            (future_entry.pair_id, FUTURE, future_entry.expiration_timestamp),
                            storage_len + 1
                        );
                },
                PossibleEntries::Generic(generic_entry) => {
                    validate_sender_for_source(@self, generic_entry);
                    let res = get_entry_storage(
                        @self, generic_entry.key, GENERIC, generic_entry.base.source, 0
                    );

                    if (res.timestamp != 0) {
                        let entry: PossibleEntries = IOracleABI::get_data_entry(
                            @self,
                            DataType::GenericEntry(generic_entry.key),
                            generic_entry.base.source
                        );

                        match entry {
                            PossibleEntries::Spot(_) => {},
                            PossibleEntries::Future(_) => {},
                            PossibleEntries::Generic(generic) => {
                                validate_data_timestamp(ref self, new_entry, generic)
                            }
                        }
                    } else {
                        let sources_len = self
                            .oracle_sources_len_storage
                            .read((generic_entry.key, GENERIC, 0));
                        self
                            .oracle_sources_storage
                            .write(
                                (generic_entry.key, GENERIC, sources_len, 0),
                                generic_entry.get_base_entry().source
                            );
                        self
                            .oracle_sources_len_storage
                            .write((generic_entry.key, GENERIC, 0), sources_len + 1);
                    }
                    self
                        .emit(
                            Event::SubmittedGenericEntry(SubmittedGenericEntry { generic_entry })
                        );
                    let test = self
                        .oracle_sources_len_storage
                        .read((generic_entry.key, GENERIC, 0));

                    let element = EntryStorage {
                        timestamp: generic_entry.base.timestamp.into(),
                        volume: 0,
                        price: generic_entry.value.into(),
                    };
                    set_entry_storage(
                        ref self, generic_entry.key, GENERIC, generic_entry.base.source, 0, element
                    );
                    let storage_len = self
                        .oracle_data_len_all_sources
                        .read((generic_entry.key, GENERIC, 0));
                    self
                        .oracle_data_len_all_sources
                        .write((generic_entry.key, GENERIC, 0), storage_len + 1);
                }
            }

            return ();
        }

        // @notice publish oracle data on chain (multiple entries)
        // @notice in order to publish, the publisher must be registered for the specific source/asset. 
        // @param new_entries, span of  new entries that needs to be published
        fn publish_data_entries(ref self: ContractState, new_entries: Span<PossibleEntries>) {
            let mut cur_idx = 0;
            loop {
                if (cur_idx >= new_entries.len()) {
                    break ();
                }
                let new_entry = *new_entries.at(cur_idx);
                IOracleABI::publish_data(ref self, new_entry);
                cur_idx = cur_idx + 1;
            }
        }

        // @notice update the publisher registry associated with the oracle 
        // @param new_publisher_registry_address: the address of the new publisher registry 
        fn update_publisher_registry_address(
            ref self: ContractState, new_publisher_registry_address: ContractAddress
        ) {
            self.assert_only_admin();
            let old_publisher_registry_address = self
                .oracle_publisher_registry_address_storage
                .read();
            self.oracle_publisher_registry_address_storage.write(new_publisher_registry_address);
            self
                .emit(
                    Event::UpdatedPublisherRegistryAddress(
                        UpdatedPublisherRegistryAddress {
                            old_publisher_registry_address, new_publisher_registry_address
                        }
                    )
                );
            return ();
        }

        // @notice add a new currency to the oracle (e.g ETH)
        // @dev can be called only by the admin
        // @param new_currency: the new currency to be added 
        fn add_currency(ref self: ContractState, new_currency: Currency) {
            self.assert_only_admin();
            let existing_currency = self.oracle_currencies_storage.read(new_currency.id);
            assert(existing_currency.id == 0, 'Currency already exists for key');
            self.emit(Event::SubmittedCurrency(SubmittedCurrency { currency: new_currency }));
            self.oracle_currencies_storage.write(new_currency.id, new_currency);
            return ();
        }

        // @notice update an existing currency
        // @dev can be called only by the admin
        // @param currency_id: the currency id to be updated
        // @param currency: the currency to be updated
        fn update_currency(ref self: ContractState, currency_id: felt252, currency: Currency) {
            self.assert_only_admin();
            assert(currency_id == currency.id, 'Currency id not corresponding');
            let existing_currency = self.oracle_currencies_storage.read(currency_id);
            assert(existing_currency.id != 0, 'No currency recorded');
            self.oracle_currencies_storage.write(currency_id, currency);
            self.emit(Event::UpdatedCurrency(UpdatedCurrency { currency: currency }));

            return ();
        }

        // @notice add a new pair to the oracle (e.g ETH)
        // @dev can be called only by the admin
        // @param new_pair: the new pair to be added 
        fn add_pair(ref self: ContractState, new_pair: Pair) {
            self.assert_only_admin();
            let check_pair = self.oracle_pairs_storage.read(new_pair.id);
            assert(check_pair.id == 0, 'Pair with this key registered');
            self.emit(Event::SubmittedPair(SubmittedPair { pair: new_pair }));
            self.oracle_pairs_storage.write(new_pair.id, new_pair);
            self
                .oracle_pair_id_storage
                .write((new_pair.quote_currency_id, new_pair.base_currency_id), new_pair.id);
            return ();
        }

        // @notice set a new checkpoint for a given data type and and aggregation mode
        // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param aggregation_mode: the aggregation method to be used 
        fn set_checkpoint(
            ref self: ContractState, data_type: DataType, aggregation_mode: AggregationMode
        ) {
            let mut sources = ArrayTrait::<felt252>::new().span();
            let priceResponse = IOracleABI::get_data_for_sources(
                @self, data_type, aggregation_mode, sources
            );

            assert(!priceResponse.last_updated_timestamp.is_zero(), 'No checkpoint available');

            let sources_threshold = self.oracle_sources_threshold_storage.read();
            let cur_checkpoint = IOracleABI::get_latest_checkpoint(
                @self, data_type, aggregation_mode
            );
            let timestamp: u64 = get_block_timestamp();
            let next_checkpoint_timestamp = cur_checkpoint.timestamp + 1;
            if (sources_threshold < priceResponse.num_sources_aggregated
                && (next_checkpoint_timestamp < timestamp)) {
                let new_checkpoint = Checkpoint {
                    timestamp: timestamp,
                    value: priceResponse.price,
                    aggregation_mode: aggregation_mode,
                    num_sources_aggregated: priceResponse.num_sources_aggregated
                };

                match data_type {
                    DataType::SpotEntry(pair_id) => {
                        let cur_idx = self
                            .oracle_checkpoint_index
                            .read((pair_id, SPOT, 0, aggregation_mode.into()));

                        set_checkpoint_storage(
                            ref self,
                            pair_id,
                            SPOT,
                            cur_idx,
                            0,
                            aggregation_mode.into(),
                            new_checkpoint
                        );
                        self
                            .oracle_checkpoint_index
                            .write((pair_id, SPOT, 0, aggregation_mode.into()), cur_idx + 1);
                        self.emit(Event::CheckpointSpotEntry(CheckpointSpotEntry { pair_id }));
                    },
                    DataType::FutureEntry((
                        pair_id, expiration_timestamp
                    )) => {
                        let cur_idx = self
                            .oracle_checkpoint_index
                            .read((pair_id, FUTURE, expiration_timestamp, aggregation_mode.into()));

                        set_checkpoint_storage(
                            ref self,
                            pair_id,
                            FUTURE,
                            cur_idx,
                            expiration_timestamp,
                            aggregation_mode.into(),
                            new_checkpoint
                        );
                        self
                            .oracle_checkpoint_index
                            .write(
                                (pair_id, FUTURE, expiration_timestamp, aggregation_mode.into()),
                                cur_idx + 1
                            );
                        self
                            .emit(
                                Event::CheckpointFutureEntry(
                                    CheckpointFutureEntry { pair_id, expiration_timestamp }
                                )
                            );
                    },
                    DataType::GenericEntry(key) => { // TODO: Issue #28
                    },
                }
            }
            return ();
        }

        // @notice set checkpoints for a span of data_type, given an aggregation mode
        // @param data_type: a span DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
        // @param aggregation_mode: the aggregation method to be used 
        fn set_checkpoints(
            ref self: ContractState, data_types: Span<DataType>, aggregation_mode: AggregationMode
        ) {
            let mut cur_idx: u32 = 0;
            loop {
                if (cur_idx == data_types.len()) {
                    break ();
                }
                let data_type: DataType = *data_types.get(cur_idx).unwrap().unbox();
                IOracleABI::set_checkpoint(ref self, data_type, aggregation_mode);
                cur_idx += 1;
            }
        }

        // @notice set the oracle admin address
        // @param  new_admin_address: the new admin address to be set 
        // @improvement recommendation to update to a 2 step admin update process - the newly appointed admin also has to accept the role before they are assigned; in the mean time, the old admin can revoke the appointment
        fn set_admin_address(ref self: ContractState, new_admin_address: ContractAddress) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let old_admin = Admin::get_admin_address(@state);
            assert(new_admin_address != old_admin, 'Same admin address');
            assert(!new_admin_address.is_zero(), 'Admin address cannot be zero');
            Admin::set_admin_address(ref state, new_admin_address);
            self.emit(Event::ChangedAdmin(ChangedAdmin { new_admin: new_admin_address }));
        }

        // @notice set the source threshold 
        // @param threshold: the new source threshold to be set 
        fn set_sources_threshold(ref self: ContractState, threshold: u32) {
            self.assert_only_admin();
            self.oracle_sources_threshold_storage.write(threshold);
        }

        // @notice upgrade the contract implementation, call to the contract Upgradeable
        // @dev callable only by the admin
        // @param impl_hash: the current implementation hash
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            self.assert_only_admin();
            let mut upstate: Upgradeable::ContractState = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::upgrade(ref upstate, impl_hash);
        }
    }


    fn aggregation_into_u8(self: AggregationMode) -> u8 {
        match self {
            AggregationMode::Median(()) => 0_u8,
            AggregationMode::Mean(()) => 1_u8,
            AggregationMode::Error(()) => 150_u8,
        }
    }

    // 
    // HELPERS
    //

    // @notice retrieve all the available sources for a given data type
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @returns a span of sources 
    fn get_all_sources(self: @ContractState, data_type: DataType) -> Array<felt252> {
        let mut sources = ArrayTrait::<felt252>::new();
        match data_type {
            DataType::SpotEntry(pair_id) => {
                let source_len = self.oracle_sources_len_storage.read((pair_id, SPOT, 0));
                build_sources_array(self, data_type, ref sources, source_len);
                return sources;
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                let source_len = self
                    .oracle_sources_len_storage
                    .read((pair_id, FUTURE, expiration_timestamp));
                build_sources_array(self, data_type, ref sources, source_len);

                return sources;
            },
            DataType::GenericEntry(key) => {
                let source_len = self.oracle_sources_len_storage.read((key, GENERIC, 0));
                build_sources_array(self, data_type, ref sources, source_len);
                return sources;
            }
        }
    }

    // @notice retrieve a checkpoint based on its index
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param checkpoint_index : the index of the checkpoint to consider
    // @param aggregation_mode: the aggregation method used when saving the checkpoint 
    // @returns the associated checkpoint
    fn get_checkpoint_by_index(
        self: @ContractState,
        data_type: DataType,
        checkpoint_index: u64,
        aggregation_mode: AggregationMode
    ) -> Checkpoint {
        let checkpoint = match data_type {
            DataType::SpotEntry(pair_id) => {
                get_checkpoint_storage(
                    self, pair_id, SPOT, checkpoint_index, 0, aggregation_mode.into()
                )
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                get_checkpoint_storage(
                    self,
                    pair_id,
                    FUTURE,
                    checkpoint_index,
                    expiration_timestamp,
                    aggregation_mode.into()
                )
            },
            DataType::GenericEntry(key) => {
                get_checkpoint_storage(
                    self, key, GENERIC, checkpoint_index, 0, aggregation_mode.into()
                )
            }
        };
        assert(!checkpoint.timestamp.is_zero(), 'Checkpoint does not exist');
        return checkpoint;
    }

    // @notice get the latest checkpoint index
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param aggregation_mode: the aggregation method to be used 
    // @returns the index
    // @returns a boolean verifying if a checkpoint is actually set (case 0)
    fn get_latest_checkpoint_index(
        self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> (u64, bool) {
        let checkpoint_index = match data_type {
            DataType::SpotEntry(pair_id) => {
                self.oracle_checkpoint_index.read((pair_id, SPOT, 0, aggregation_mode.into()))
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                self
                    .oracle_checkpoint_index
                    .read((pair_id, FUTURE, expiration_timestamp, aggregation_mode.into()))
            },
            DataType::GenericEntry(key) => {
                self.oracle_checkpoint_index.read((key, GENERIC, 0, aggregation_mode.into()))
            }
        };

        if (checkpoint_index == 0) {
            return (0, false);
        } else {
            return (checkpoint_index - 1, true);
        }
    }

    // @notice check if the publisher is registered, and allowed to publish the entry, calling the publisher registry contract
    // @param entry: the entry to be published 
    fn validate_sender_for_source<T, impl THasBaseEntry: hasBaseEntry<T>, impl TDrop: Drop<T>>(
        self: @ContractState, _entry: T
    ) {
        let publisher_registry_address = IOracleABI::get_publisher_registry_address(self);
        let publisher_registry_dispatcher = IPublisherRegistryABIDispatcher {
            contract_address: publisher_registry_address
        };
        let publisher_address = publisher_registry_dispatcher
            .get_publisher_address(_entry.get_base_entry().publisher);
        let _can_publish_source = publisher_registry_dispatcher
            .can_publish_source(_entry.get_base_entry().publisher, _entry.get_base_entry().source);
        let caller_address = get_caller_address();

        assert(!publisher_address.is_zero(), 'Publisher is not registered');
        assert(!caller_address.is_zero(), 'Caller must not be zero address');
        assert(caller_address == publisher_address, 'Transaction not from publisher');
        assert(_can_publish_source == true, 'Not allowed for source');
        return ();
    }

    // @notice retrieve the latest entry timestamp for a given data type and and sources 
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param a span of sources
    // @returns the latest timestamp
    fn get_latest_entry_timestamp(
        self: @ContractState, data_type: DataType, sources: Span<felt252>
    ) -> u64 {
        let mut cur_idx = 0;
        let mut latest_timestamp = 0;
        let storage_len = match data_type {
            DataType::SpotEntry(pair_id) => {
                self.oracle_data_len_all_sources.read((pair_id, SPOT, 0))
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                self.oracle_data_len_all_sources.read((pair_id, FUTURE, expiration_timestamp))
            },
            DataType::GenericEntry(key) => {
                self.oracle_data_len_all_sources.read((key, GENERIC, 0))
            }
        };

        if (storage_len == 0) {
            return 0;
        } else {
            loop {
                if (cur_idx == sources.len()) {
                    break ();
                }
                let source: felt252 = *sources.get(cur_idx).unwrap().unbox();
                let entry: PossibleEntries = IOracleABI::get_data_entry(self, data_type, source);

                match entry {
                    PossibleEntries::Spot(spot_entry) => {
                        if spot_entry.base.timestamp > latest_timestamp {
                            latest_timestamp = spot_entry.base.timestamp;
                        }
                    },
                    PossibleEntries::Future(future_entry) => {
                        if future_entry.base.timestamp > latest_timestamp {
                            latest_timestamp = future_entry.base.timestamp;
                        }
                    },
                    PossibleEntries::Generic(generic_entry) => {
                        if generic_entry.base.timestamp > latest_timestamp {
                            latest_timestamp = generic_entry.base.timestamp;
                        }
                    }
                }
                cur_idx += 1;
            };
            return latest_timestamp;
        }
    }

    // @notice build an array of PossibleEntries (spot entries, future entries, ...)
    // @dev recursive function
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param sources: a span of sources to consider 
    // @aram entries: a reference to an array of PossibleEntries , to be filled
    // @param latest_timestamp : max wanted timestamp
    fn build_entries_array(
        self: @ContractState,
        data_type: DataType,
        sources: Span<felt252>,
        ref entries: Array<PossibleEntries>,
        latest_timestamp: u64
    ) {
        let mut cur_idx = 0;
        loop {
            if (cur_idx >= sources.len()) {
                break ();
            }
            let source: felt252 = *sources.get(cur_idx).unwrap().unbox();
            let g_entry: PossibleEntries = IOracleABI::get_data_entry(self, data_type, source);
            match g_entry {
                PossibleEntries::Spot(spot_entry) => {
                    let is_entry_not_initialized: bool = spot_entry.get_base_timestamp() == 0;
                    let condition: bool = is_entry_not_initialized
                        && (spot_entry
                            .get_base_timestamp() < (latest_timestamp - BACKWARD_TIMESTAMP_BUFFER));
                    if !condition {
                        entries.append(PossibleEntries::Spot(spot_entry));
                    }
                },
                PossibleEntries::Future(future_entry) => {
                    let is_entry_not_initialized: bool = future_entry.get_base_timestamp() == 0;
                    let condition: bool = is_entry_not_initialized
                        & (future_entry
                            .get_base_timestamp() < (latest_timestamp - BACKWARD_TIMESTAMP_BUFFER));
                    if !condition {
                        entries.append(PossibleEntries::Future(future_entry));
                    }
                },
                PossibleEntries::Generic(generic_entry) => {
                    let is_entry_not_initialized: bool = generic_entry.get_base_timestamp() == 0;
                    let condition: bool = is_entry_not_initialized
                        & (generic_entry
                            .get_base_timestamp() < (latest_timestamp - BACKWARD_TIMESTAMP_BUFFER));
                    if !condition {
                        entries.append(PossibleEntries::Generic(generic_entry));
                    }
                }
            };

            cur_idx += 1;
        };
        return ();
    }


    // @notice retrieve all the entries for a given data type 
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param sources: a span of sources to consider
    // @param max_timestamp: max timestamp wanted
    fn get_all_entries(
        self: @ContractState, data_type: DataType, sources: Span<felt252>, max_timestamp: u64
    ) -> (Array<PossibleEntries>, u32) {
        let mut entries = ArrayTrait::<PossibleEntries>::new();

        build_entries_array(self, data_type, sources, ref entries, max_timestamp);
        (entries, entries.len())
    }

    // @notice generate an ArrayEntry out of a span of possibleEntries 
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param data : the span of possibleEntries 
    // @returns an ArrayEntry (see entry/structs)
    fn filter_data_array(data_type: DataType, data: Span<PossibleEntries>) -> ArrayEntry {
        match data_type {
            DataType::SpotEntry(pair_id) => {
                let mut cur_idx = 0;
                let mut spot_entries = ArrayTrait::<SpotEntry>::new();
                loop {
                    if (cur_idx == data.len()) {
                        break ();
                    }
                    let entry = *data.at(cur_idx);
                    match entry {
                        PossibleEntries::Spot(spot_entry) => {
                            spot_entries.append(spot_entry);
                        },
                        PossibleEntries::Future(_) => {},
                        PossibleEntries::Generic(_) => {}
                    }
                    cur_idx = cur_idx + 1;
                };
                ArrayEntry::SpotEntry(spot_entries)
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                let mut cur_idx = 0;
                let mut future_entries = ArrayTrait::<FutureEntry>::new();
                loop {
                    if (cur_idx == data.len()) {
                        break ();
                    }
                    let entry = *data.at(cur_idx);
                    match entry {
                        PossibleEntries::Spot(_) => {},
                        PossibleEntries::Future(future_entry) => {
                            future_entries.append(future_entry);
                        },
                        PossibleEntries::Generic(_) => {}
                    }
                    cur_idx = cur_idx + 1;
                };
                ArrayEntry::FutureEntry(future_entries)
            },
            DataType::GenericEntry(key) => {
                let mut cur_idx = 0;
                let mut generic_entries = ArrayTrait::<GenericEntry>::new();
                loop {
                    if (cur_idx == data.len()) {
                        break ();
                    }
                    let entry = *data.at(cur_idx);
                    match entry {
                        PossibleEntries::Spot(_) => {},
                        PossibleEntries::Future(_) => {},
                        PossibleEntries::Generic(generic_entry) => {
                            generic_entries.append(generic_entry);
                        }
                    }
                    cur_idx = cur_idx + 1;
                };
                ArrayEntry::GenericEntry(generic_entries)
            }
        }
    }

    // @notice check if the timestamp of the new entry is bigger than the timestamp of the old entry, and update the source storage 
    // @dev should fail if the old_timestamp > new_timestamp
    // @param new_entry : an entry (spot entry, future entry, ... )
    // @param last_entry : an entry (with the same nature as new_entry)
    fn validate_data_timestamp<T, impl THasBaseEntry: hasBaseEntry<T>, impl TDrop: Drop<T>>(
        ref self: ContractState, new_entry: PossibleEntries, last_entry: T,
    ) {
        match new_entry {
            PossibleEntries::Spot(spot_entry) => {
                assert(
                    spot_entry.get_base_timestamp() >= last_entry.get_base_timestamp(),
                    'Existing entry is more recent'
                );
                if (last_entry.get_base_timestamp() == 0) {
                    let sources_len = self
                        .oracle_sources_len_storage
                        .read((spot_entry.pair_id, SPOT, 0));
                    self
                        .oracle_sources_storage
                        .write(
                            (spot_entry.pair_id, SPOT, sources_len, 0),
                            spot_entry.get_base_entry().source
                        );
                    self
                        .oracle_sources_len_storage
                        .write((spot_entry.pair_id, SPOT, 0), sources_len + 1);
                }
            },
            PossibleEntries::Future(future_entry) => {
                assert(
                    future_entry.get_base_timestamp() >= last_entry.get_base_timestamp(),
                    'Existing entry is more recent'
                );
                if (last_entry.get_base_timestamp() == 0) {
                    let sources_len = self
                        .oracle_sources_len_storage
                        .read((future_entry.pair_id, FUTURE, future_entry.expiration_timestamp));
                    self
                        .oracle_sources_storage
                        .write(
                            (
                                future_entry.pair_id,
                                FUTURE,
                                sources_len,
                                future_entry.expiration_timestamp
                            ),
                            future_entry.get_base_entry().source
                        );
                    self
                        .oracle_sources_len_storage
                        .write(
                            (future_entry.pair_id, FUTURE, future_entry.expiration_timestamp),
                            sources_len + 1
                        );
                }
            },
            PossibleEntries::Generic(generic_entry) => {
                assert(
                    generic_entry.get_base_timestamp() >= last_entry.get_base_timestamp(),
                    'Existing entry is more recent'
                );
                if (last_entry.get_base_timestamp() == 0) {
                    let sources_len = self
                        .oracle_sources_len_storage
                        .read((generic_entry.key, GENERIC, 0));
                    self
                        .oracle_sources_storage
                        .write(
                            (generic_entry.key, GENERIC, sources_len, 0),
                            generic_entry.get_base_entry().source
                        );
                    self
                        .oracle_sources_len_storage
                        .write((generic_entry.key, GENERIC, 0), sources_len + 1);
                }
            }
        // PossibleEntries::OptionEntry(option_entry) => {}
        }
        return ();
    }

    // @notice add pair to the oracle, admin checkup done in the implementation
    // @param pair: new pair to be added
    fn add_pair(ref self: ContractState, pair: Pair) {
        let check_pair = self.oracle_pairs_storage.read(pair.id);
        assert(check_pair.id == 0, 'Pair with this key registered');
        self.emit(Event::SubmittedPair(SubmittedPair { pair }));
        self.oracle_pairs_storage.write(pair.id, pair);
        self.oracle_pair_id_storage.write((pair.quote_currency_id, pair.base_currency_id), pair.id);
        return ();
    }

    // @notice set source threshold
    // @param the threshold to be set 
    fn set_sources_threshold(ref self: ContractState, threshold: u32) {
        self.oracle_sources_threshold_storage.write(threshold);
        return ();
    }

    // @notice find the checkpoint whose timestamp is immediately before the given timestamp
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param aggregation_mode: the aggregation method to be used 
    // @param the timestamp to be considered
    // @returns the index of the checkpoint before the given timestamp
    fn find_startpoint(
        self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode, timestamp: u64
    ) -> u64 {
        let (latest_checkpoint_index, _) = get_latest_checkpoint_index(
            self, data_type, aggregation_mode
        );

        let cp = get_checkpoint_by_index(
            self, data_type, latest_checkpoint_index, aggregation_mode
        );

        if (cp.timestamp <= timestamp) {
            return latest_checkpoint_index;
        }
        let first_cp = get_checkpoint_by_index(self, data_type, 0, aggregation_mode);
        if (timestamp < first_cp.timestamp) {
            assert(false, 'Timestamp is too old');
            return 0;
        }
        if (timestamp == first_cp.timestamp) {
            return 0;
        }

        let startpoint = _binary_search(
            self, data_type, 0, latest_checkpoint_index, timestamp, aggregation_mode
        );
        return startpoint;
    }


    fn get_entry_storage(
        self: @ContractState,
        key: felt252,
        type_of: felt252,
        source: felt252,
        expiration_timestamp: u64
    ) -> EntryStorage {
        self.oracle_data_entry_storage.read((key, type_of, source, expiration_timestamp))
    }

    fn set_entry_storage(
        ref self: ContractState,
        key: felt252,
        type_of: felt252,
        source: felt252,
        expiration_timestamp: u64,
        entry: EntryStorage
    ) {
        self.oracle_data_entry_storage.write((key, type_of, source, expiration_timestamp), entry);
    }

    fn set_checkpoint_storage(
        ref self: ContractState,
        key: felt252,
        type_of: felt252,
        index: u64,
        expiration_timestamp: u64,
        aggregation_mode: u8,
        checkpoint: Checkpoint
    ) {
        self
            .oracle_checkpoints
            .write((key, type_of, index, expiration_timestamp, aggregation_mode), checkpoint);
    }

    fn get_checkpoint_storage(
        self: @ContractState,
        key: felt252,
        type_of: felt252,
        index: u64,
        expiration_timestamp: u64,
        aggregation_mode: u8
    ) -> Checkpoint {
        self.oracle_checkpoints.read((key, type_of, index, expiration_timestamp, aggregation_mode))
    }


    fn _binary_search(
        self: @ContractState,
        data_type: DataType,
        low: u64,
        high: u64,
        target: u64,
        aggregation_mode: AggregationMode
    ) -> u64 {
        let high_cp = get_checkpoint_by_index(self, data_type, high, aggregation_mode);
        if (high_cp.timestamp <= target) {
            return high;
        }

        // Find the middle point
        let midpoint = (low + high) / 2;

        if midpoint == 0 {
            return 0;
        }
        // If middle point is target.
        let past_midpoint_cp = get_checkpoint_by_index(
            self, data_type, midpoint - 1, aggregation_mode
        );
        let midpoint_cp = get_checkpoint_by_index(self, data_type, midpoint, aggregation_mode);

        if (midpoint_cp.timestamp == target) {
            return midpoint;
        }

        // If x lies between mid-1 and mid
        if (past_midpoint_cp.timestamp <= target && target <= midpoint_cp.timestamp) {
            return midpoint - 1;
        }

        // If x is smaller than mid, floor
        // must be in left half.
        if (target <= midpoint_cp.timestamp) {
            return _binary_search(self, data_type, low, midpoint - 1, target, aggregation_mode);
        }

        // If mid-1 is not floor and x is
        // greater than arr[mid],
        return _binary_search(self, data_type, midpoint + 1, high, target, aggregation_mode);
    }


    // @notice retrieve all the sources from the storage and set it in an array 
    // @dev recursive function
    // @param data_type: an enum of DataType (e.g : DataType::SpotEntry(ASSET_ID) or DataType::FutureEntry((ASSSET_ID, expiration_timestamp)))
    // @param sources: reference to a sources array, to be filled 
    // @param sources_len, the max number of sources for the given data_type/aggregation_mode
    fn build_sources_array(
        self: @ContractState, data_type: DataType, ref sources: Array<felt252>, sources_len: u64
    ) {
        let mut idx: u64 = 0;
        loop {
            if (idx == sources_len) {
                break ();
            }
            match data_type {
                DataType::SpotEntry(pair_id) => {
                    let new_source = self
                        .oracle_sources_storage
                        .read((pair_id, SPOT, idx.into(), 0));

                    sources.append(new_source);
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    let new_source = self
                        .oracle_sources_storage
                        .read((pair_id, FUTURE, idx.into(), expiration_timestamp));
                    sources.append(new_source);
                },
                DataType::GenericEntry(key) => {
                    let new_source = self
                        .oracle_sources_storage
                        .read((key, GENERIC, idx.into(), 0));
                    sources.append(new_source);
                }
            }
            idx = idx + 1;
        };
        return ();
    }
}

