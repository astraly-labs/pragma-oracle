use pragma::entry::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntryStorage, FutureEntry, OptionEntry,
    SimpleDataType, SpotEntryStorage, FutureEntryStorage, AggregationMode, PossibleEntries,
    ArrayEntry
};
use pragma::oracle::oracleInterface::IOracle;
use pragma::admin::admin::Admin;
use pragma::upgradeable::upgradeable::Upgradeable;
use serde::Serde;
use starknet::{
    storage_read_syscall, storage_write_syscall, storage_address_from_base_and_offset,
    storage_access::storage_base_address_from_felt252, StorageAccess, StorageBaseAddress,
    SyscallResult, ContractAddress, get_caller_address
};
use starknet::class_hash::ClassHash;
use traits::{Into, TryInto};
use result::{ResultTrait, ResultTraitImpl};
use box::BoxTrait;
use array::ArrayTrait;
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
    ) -> (Array<PossibleEntries>, u32, u64);

    fn get_data_median_multi(
        self: @TContractState, data_types: Span<DataType>, sources: Span<felt252>
    ) -> Array<PragmaPricesResponse>;


    fn get_data_entries(self: @TContractState, data_type: DataType) -> Array<PossibleEntries>;

    fn get_last_checkpoint_before(
        self: @TContractState,
        data_type: DataType,
        aggregation_mode: AggregationMode,
        timestamp: u64
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
        self: @TContractState, data_type: DataType, checkpoint_index: u64
    ) -> Checkpoint;

    fn get_sources_threshold(self: @TContractState, ) -> u32;

    fn get_admin_address(self: @TContractState) -> ContractAddress;
    fn publish_data(ref self: TContractState, new_entry: PossibleEntries);
    fn publish_data_entries(ref self: TContractState, new_entries: Array<PossibleEntries>);
    fn set_admin_address(ref self: TContractState, new_admin_address: ContractAddress);
    fn update_publisher_registry_address(
        ref self: TContractState, new_publisher_registry_address: ContractAddress
    );
    fn add_currency(ref self: TContractState, currency: Currency);
    fn update_currency(ref self: TContractState, new_currency: Currency);
    fn add_pair(ref self: TContractState, new_pair: Pair);
    fn set_checkpoint(
        ref self: TContractState, data_type: DataType, aggregation_mode: AggregationMode
    );
    fn set_checkpoints(
        ref self: TContractState, data_types: Span<DataType>, aggregation_mode: AggregationMode
    );
    fn set_sources_threshold(ref self: TContractState, threshold: u32);
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
    ) -> (Array<PossibleEntries>, u32, u64);

    fn get_data_median_multi(
        self: @TContractState, data_types: Span<DataType>, sources: Span<felt252>
    ) -> Array<PragmaPricesResponse>;


    fn get_data_entries(self: @TContractState, data_type: DataType) -> Array<PossibleEntries>;

    fn get_last_checkpoint_before(
        self: @TContractState,
        data_type: DataType,
        aggregation_mode: AggregationMode,
        timestamp: u64,
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
}


#[starknet::contract]
mod Oracle {
    use super::{
        BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
        USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntryStorage, FutureEntry, OptionEntry,
        SimpleDataType, SpotEntryStorage, FutureEntryStorage, AggregationMode, PossibleEntries,
        ArrayEntry, IOracle, Admin, Upgradeable, Serde, storage_read_syscall, storage_write_syscall,
        storage_address_from_base_and_offset, storage_base_address_from_felt252, StorageAccess,
        StorageBaseAddress, SyscallResult, ContractAddress, get_caller_address, ClassHash, Into,
        TryInto, ResultTrait, ResultTraitImpl, BoxTrait, ArrayTrait, Zeroable,
    };

    use pragma::entry::entry::Entry;
    use pragma::operations::bits_manipulation::bits_manipulation::{
        actual_set_element_at, actual_get_element_at
    };
    use pragma::operations::time_series::convert::convert_via_usd;
    use pragma::publisher_registry::publisher_registry::{
        IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
    };

    use starknet::{get_block_timestamp, Felt252TryIntoContractAddress};

    use cmp::{max, min};
    use option::OptionTrait;
    use array::SpanTrait;
    use debug::PrintTrait;
    const BACKWARD_TIMESTAMP_BUFFER: u64 = 7800; // 2 hours and 10 minutes

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
        //oralce_sources_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS), index, expiration_timestamp ) and the source
        oracle_sources_storage: LegacyMap::<(felt252, felt252, u64, u64), felt252>,
        //oracle_sources_len_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS), expiration_timestamp) and the len of the sources array
        oracle_sources_len_storage: LegacyMap::<(felt252, felt252, u64), u64>,
        //oracle_data_entry_storage, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), source, expiration_timestamp (0 for SPOT))
        oracle_data_entry_storage: LegacyMap::<(felt252, felt252, felt252, u64), u256>,
        //oracle_data_entry_storage len , legacyMap between pair_id, (SPOT/FUTURES/OPTIONS), expiration_timestamp and the length
        oracle_data_len_all_sources: LegacyMap::<(felt252, felt252, u64), u64>,
        //oracle_checkpoints, legacyMap between, (pair_id, (SPOT/FUTURES/OPTIONS), index, expiration_timestamp (0 for SPOT)) associated to a checkpoint
        oracle_checkpoints: LegacyMap::<(felt252, felt252, u64, u64), Checkpoint>,
        //oracle_checkpoint_index, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), expiration_timestamp (0 for SPOT)) and the index of the last checkpoint
        oracle_checkpoint_index: LegacyMap::<(felt252, felt252, u64), u64>,
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
        fn get_price(self: @T) -> u256;
    }

    impl SHasPriceImpl of HasPrice<SpotEntry> {
        fn get_price(self: @SpotEntry) -> u256 {
            (*self).price
        }
    }
    impl FHasPriceImpl of HasPrice<FutureEntry> {
        fn get_price(self: @FutureEntry) -> u256 {
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

    fn u8_into_AggregationMode(value: u8) -> AggregationMode {
        if value == 0_u8 {
            AggregationMode::Median(())
        } else if value == 1_u8 {
            AggregationMode::Mean(())
        } else {
            AggregationMode::Error(())
        }
    }

    impl CheckpointStorageAccess of StorageAccess<Checkpoint> {
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Checkpoint> {
            let timestamp_base = storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            );
            let timestamp: u64 = StorageAccess::<u128>::read(address_domain, timestamp_base)?
                .try_into()
                .unwrap();

            let value_base = storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 1_u8).into()
            );
            let value = u256 {
                low: StorageAccess::<u128>::read(address_domain, value_base)?,
                high: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(value_base, 1_u8)
                )?
                    .try_into()
                    .expect('StorageAccessU256 - non u256')
            };
            let u8_aggregation_mode: u8 = StorageAccess::<felt252>::read(
                address_domain,
                storage_base_address_from_felt252(
                    storage_address_from_base_and_offset(base, 4_u8).into()
                )
            )?
                .try_into()
                .unwrap();

            let aggregation_mode: AggregationMode = u8_into_AggregationMode(u8_aggregation_mode);
            Result::Ok(
                Checkpoint {
                    timestamp: timestamp,
                    value: value,
                    aggregation_mode: aggregation_mode,
                    num_sources_aggregated: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 5_u8)
                    )?
                        .try_into()
                        .unwrap(),
                }
            )
        }
        #[inline(always)]
        fn write(
            address_domain: u32, base: StorageBaseAddress, value: Checkpoint
        ) -> SyscallResult<()> {
            let timestamp_base = storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            );
            StorageAccess::write(address_domain, timestamp_base, value.timestamp)?;
            let value_base = storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 1_u8).into()
            );
            StorageAccess::write(address_domain, value_base, value.value.low)?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(value_base, 1_u8),
                value.value.high.into()
            )?;

            let aggregation_mode_u8: u8 = value.aggregation_mode.into();
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 4_u8),
                aggregation_mode_u8.into(),
            )?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 5_u8),
                value.num_sources_aggregated.into(),
            )
        }
        fn read_at_offset_internal(
            address_domain: u32, base: starknet::StorageBaseAddress, offset: u8
        ) -> starknet::SyscallResult<Checkpoint> {
            CheckpointStorageAccess::read_at_offset_internal(address_domain, base, offset)
        }
        fn write_at_offset_internal(
            address_domain: u32, base: starknet::StorageBaseAddress, offset: u8, value: Checkpoint
        ) -> starknet::SyscallResult<()> {
            CheckpointStorageAccess::write_at_offset_internal(address_domain, base, offset, value)
        }
        fn size_internal(value: Checkpoint) -> u8 {
            4_u8
        }
    }

    // TODO: Update events to latest synthax

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
        SubmittedCurrency: SubmittedCurrency,
        UpdatedCurrency: UpdatedCurrency,
        SubmittedPair: SubmittedPair,
        CheckpointSpotEntry: CheckpointSpotEntry,
        CheckpointFutureEntry: CheckpointFutureEntry
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        publisher_registry_address: ContractAddress,
        currencies: Span<Currency>,
        pairs: Span<Pair>
    ) {
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

        fn assert_only_admin(self: @ContractState) {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            let admin = Admin::get_admin_address(@state);
            let caller = get_caller_address();
            assert(caller == admin, 'Admin: unauthorized');
        }

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

        fn upgrade(self: @ContractState, impl_hash: ClassHash) {
            self.assert_only_admin();
            let mut upstate: Upgradeable::ContractState = Upgradeable::unsafe_new_contract_state();
            Upgradeable::upgrade(ref upstate, impl_hash);
        }
    }

    #[external(v0)]
    impl IOracleImpl of IOracle<ContractState> {
        //
        // Getters
        //

        fn get_data_entries_for_sources(
            self: @ContractState, data_type: DataType, sources: Span<felt252>
        ) -> (Array<PossibleEntries>, u32, u64) {
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
                return (entries, entries_len, conservative_current_timestamp);
            } else {
                let last_updated_timestamp = get_latest_entry_timestamp(self, data_type, sources);
                let current_timestamp: u64 = get_block_timestamp();
                let conservative_current_timestamp = min(last_updated_timestamp, current_timestamp);
                let (entries, entries_len) = get_all_entries(
                    self, data_type, sources, conservative_current_timestamp
                );
                return (entries, entries_len, conservative_current_timestamp);
            }
        //TO BE CHECKED, FOR LAST_UPDATED_TIMESTAMP
        }


        fn get_data_entries(self: @ContractState, data_type: DataType) -> Array<PossibleEntries> {
            let mut sources = ArrayTrait::<felt252>::new();
            let sources = get_all_sources(self, data_type).span();
            let (entries, _, _) = IOracle::get_data_entries_for_sources(self, data_type, sources);
            entries
        }


        fn get_data_median(self: @ContractState, data_type: DataType) -> PragmaPricesResponse {
            let sources = get_all_sources(self, data_type).span();
            let prices_response: PragmaPricesResponse = IOracle::get_data_for_sources(
                self, data_type, AggregationMode::Median(()), sources
            );
            prices_response
        }


        fn get_data_median_for_sources(
            self: @ContractState, data_type: DataType, sources: Span<felt252>
        ) -> PragmaPricesResponse {
            let prices_response: PragmaPricesResponse = IOracle::get_data_for_sources(
                self, data_type, AggregationMode::Median(()), sources
            );
            prices_response
        }


        fn get_data_median_multi(
            self: @ContractState, data_types: Span<DataType>, sources: Span<felt252>
        ) -> Array<PragmaPricesResponse> {
            let mut prices_response = ArrayTrait::<PragmaPricesResponse>::new();
            let mut cur_idx = 0;
            loop {
                if (cur_idx >= data_types.len()) {
                    break ();
                }
                let data_type = *data_types.at(cur_idx);
                let cur_prices_response: PragmaPricesResponse = IOracle::get_data_for_sources(
                    self, data_type, AggregationMode::Median(()), sources
                );
                prices_response.append(cur_prices_response);
                cur_idx += 1;
            };
            prices_response
        }


        fn get_data(
            self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode
        ) -> PragmaPricesResponse {
            let sources = get_all_sources(self, data_type).span();

            let prices_response: PragmaPricesResponse = IOracle::get_data_for_sources(
                self, data_type, aggregation_mode, sources
            );

            prices_response
        }


        fn get_data_for_sources(
            self: @ContractState,
            data_type: DataType,
            aggregation_mode: AggregationMode,
            sources: Span<felt252>
        ) -> PragmaPricesResponse {
            let mut entries = ArrayTrait::<PossibleEntries>::new();

            let (entries, entries_len, last_updated_timestamp) =
                IOracle::get_data_entries_for_sources(
                self, data_type, sources
            );

            if (entries_len == 0) {
                return PragmaPricesResponse {
                    price: 0,
                    decimals: 0,
                    last_updated_timestamp: 0,
                    num_sources_aggregated: 0,
                    expiration_timestamp: Option::Some(0),
                };
            }

            // TODO: Return only array instead of `ArrayEntry`
            let filtered_entries: ArrayEntry = filter_data_array(data_type, @entries);

            match data_type {
                DataType::SpotEntry(pair_id) => {
                    match filtered_entries {
                        ArrayEntry::SpotEntry(array_spot) => {
                            let price = Entry::aggregate_entries::<SpotEntry>(
                                @array_spot, aggregation_mode
                            );
                            let decimals = IOracle::get_decimals(self, data_type);
                            let last_updated_timestamp =
                                Entry::aggregate_timestamps_max::<SpotEntry>(
                                @array_spot
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
                                @array_future, aggregation_mode
                            );
                            let decimals = IOracle::get_decimals(self, data_type);
                            let last_updated_timestamp =
                                Entry::aggregate_timestamps_max::<FutureEntry>(
                                @array_future
                            );
                            return PragmaPricesResponse {
                                price: price,
                                decimals: decimals,
                                last_updated_timestamp: last_updated_timestamp,
                                num_sources_aggregated: entries.len(),
                                expiration_timestamp: Option::Some(expiration_timestamp)
                            };
                        },
                    }
                }
            }
        }


        fn get_publisher_registry_address(self: @ContractState) -> ContractAddress {
            self.oracle_publisher_registry_address_storage.read()
        }


        //Can be simplified using just the pair_id instead of the data_type
        fn get_decimals(self: @ContractState, data_type: DataType) -> u32 {
            let (base_currency, quote_currency) = match data_type {
                DataType::SpotEntry(pair_id) => {
                    let pair = self.oracle_pairs_storage.read(pair_id);
                    assert(!pair.id.is_zero(), 'No pair found');
                    let base_cur = self.oracle_currencies_storage.read(pair.base_currency_id);
                    let quote_cur = self.oracle_currencies_storage.read(pair.quote_currency_id);
                    (base_cur, quote_cur)
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    let pair = self.oracle_pairs_storage.read(pair_id);
                    assert(!pair.id.is_zero(), 'No pair found');
                    let base_cur = self.oracle_currencies_storage.read(pair.base_currency_id);
                    let quote_cur = self.oracle_currencies_storage.read(pair.quote_currency_id);
                    (base_cur, quote_cur)
                },
            // DataType::OptionEntry((pair_id, expiration_timestamp)) => {}
            };
            min(base_currency.decimals, quote_currency.decimals)
        }


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
            let basePPR: PragmaPricesResponse = IOracle::get_data_for_sources(
                self, base_data_type, aggregation_mode, sources
            );

            let quotePPR: PragmaPricesResponse = IOracle::get_data_for_sources(
                self, quote_data_type, aggregation_mode, sources
            );

            let decimals = min(
                IOracle::get_decimals(self, base_data_type),
                IOracle::get_decimals(self, quote_data_type)
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


        fn get_latest_checkpoint_index(
            self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode
        ) -> (u64, bool) {
            get_latest_checkpoint_index(self, data_type, aggregation_mode)
        }


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
                get_checkpoint_by_index(self, data_type, checkpoint_index)
            }
        }


        fn get_checkpoint(
            self: @ContractState, data_type: DataType, checkpoint_index: u64
        ) -> Checkpoint {
            get_checkpoint_by_index(self, data_type, checkpoint_index)
        }


        fn get_sources_threshold(self: @ContractState) -> u32 {
            self.oracle_sources_threshold_storage.read()
        }


        fn get_admin_address(self: @ContractState) -> ContractAddress {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::get_admin_address(@state)
        }


        fn get_implementation_hash(self: @ContractState) -> ClassHash {
            let state: Upgradeable::ContractState = Upgradeable::unsafe_new_contract_state();
            Upgradeable::get_implementation_hash(@state)
        }


        fn get_last_checkpoint_before(
            self: @ContractState,
            data_type: DataType,
            aggregation_mode: AggregationMode,
            timestamp: u64
        ) -> (Checkpoint, u64) {
            let idx = find_startpoint(self, data_type, aggregation_mode, timestamp);

            let checkpoint = get_checkpoint_by_index(self, data_type, idx);

            (checkpoint, idx)
        }


        fn get_data_entry(
            self: @ContractState, data_type: DataType, source: felt252
        ) -> PossibleEntries {
            let _entry = match data_type {
                DataType::SpotEntry(pair_id) => {
                    self.oracle_data_entry_storage.read((pair_id, SPOT, source, 0))
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    self
                        .oracle_data_entry_storage
                        .read((pair_id, FUTURE, source, expiration_timestamp))
                },
            };

            assert(!_entry.is_zero(), 'No data entry found');
            let u256_timestamp: u256 = actual_get_element_at(_entry, 0, 31);
            let timestamp: u64 = u256_timestamp.try_into().unwrap();
            let volume = actual_get_element_at(_entry, 32, 30);
            let price = actual_get_element_at(_entry, 63, 65);
            match data_type {
                DataType::SpotEntry(pair_id) => {
                    PossibleEntries::Spot(
                        SpotEntry {
                            base: BaseEntry {
                                timestamp: timestamp, source: source, publisher: 0
                            }, pair_id: pair_id, price: price, volume: volume
                        }
                    )
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    PossibleEntries::Future(
                        FutureEntry {
                            base: BaseEntry {
                                timestamp: timestamp, source: source, publisher: 0
                            },
                            pair_id: pair_id,
                            price: price,
                            volume: volume,
                            expiration_timestamp: expiration_timestamp
                        }
                    )
                },
            }
        }

        //
        // Setters
        //

        fn publish_data(ref self: ContractState, new_entry: PossibleEntries) {
            match new_entry {
                PossibleEntries::Spot(spot_entry) => {
                    validate_sender_for_source(@self, spot_entry);
                    let res = self
                        .oracle_data_entry_storage
                        .read((spot_entry.pair_id, SPOT, spot_entry.base.source, 0));

                    if (res != 0) {
                        let entry: PossibleEntries = IOracle::get_data_entry(
                            @self, DataType::SpotEntry(spot_entry.pair_id), spot_entry.base.source
                        );
                        match entry {
                            PossibleEntries::Spot(spot) => {
                                validate_data_timestamp(ref self, new_entry, spot);
                            },
                            PossibleEntries::Future(_) => {}
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
                    let conv_timestamp: u256 = u256 {
                        low: spot_entry.base.timestamp.into(), high: 0
                    };

                    let element = actual_set_element_at(0, 0, 31, conv_timestamp);
                    let element = actual_set_element_at(element, 32, 30, spot_entry.volume);
                    let element = actual_set_element_at(element, 63, 65, spot_entry.price);

                    let spot_entry_storage = SpotEntryStorage { timestamp__volume__price: element };
                    self
                        .oracle_data_entry_storage
                        .write((spot_entry.pair_id, SPOT, spot_entry.base.source, 0), element);

                    let storage_len = self
                        .oracle_data_len_all_sources
                        .read((spot_entry.pair_id, SPOT, 0));
                    self
                        .oracle_data_len_all_sources
                        .write((spot_entry.pair_id, SPOT, 0), storage_len + 1);
                },
                PossibleEntries::Future(future_entry) => {
                    validate_sender_for_source(@self, future_entry);
                    let res = self
                        .oracle_data_entry_storage
                        .read(
                            (
                                future_entry.pair_id,
                                FUTURE,
                                future_entry.base.source,
                                future_entry.expiration_timestamp
                            )
                        );

                    if (res != 0) {
                        let entry: PossibleEntries = IOracle::get_data_entry(
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
                            }
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
                    let conv_timestamp: u256 = u256 {
                        low: future_entry.base.timestamp.into(), high: 0
                    };
                    let element = actual_set_element_at(0, 0, 31, conv_timestamp);
                    let element = actual_set_element_at(element, 32, 30, future_entry.volume);
                    let element = actual_set_element_at(element, 63, 65, future_entry.price);
                    let future_entry_storage = FutureEntryStorage {
                        timestamp__volume__price: element
                    };
                    self
                        .oracle_data_entry_storage
                        .write(
                            (
                                future_entry.pair_id,
                                FUTURE,
                                future_entry.base.source,
                                future_entry.expiration_timestamp
                            ),
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
            }

            return ();
        }


        fn publish_data_entries(ref self: ContractState, new_entries: Span<PossibleEntries>) {
            let mut cur_idx = 0;
            loop {
                if (cur_idx >= new_entries.len()) {
                    break ();
                }
                let new_entry = *new_entries.at(cur_idx);
                IOracle::publish_data(ref self, new_entry);
                cur_idx = cur_idx + 1;
            }
        }


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


        fn add_currency(ref self: ContractState, new_currency: Currency) {
            self.assert_only_admin();
            let existing_currency = self.oracle_currencies_storage.read(new_currency.id);
            assert(existing_currency.id == 0, 'Currency already exists for key');
            self.emit(Event::SubmittedCurrency(SubmittedCurrency { currency: new_currency }));
            self.oracle_currencies_storage.write(new_currency.id, new_currency);
            return ();
        }


        fn update_currency(ref self: ContractState, currency: Currency) {
            self.assert_only_admin();
            self.oracle_currencies_storage.write(currency.id, currency);
            self.emit(Event::UpdatedCurrency(UpdatedCurrency { currency: currency }));

            return ();
        }


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


        fn set_checkpoint(
            ref self: ContractState, data_type: DataType, aggregation_mode: AggregationMode
        ) {
            let mut sources = ArrayTrait::<felt252>::new().span();
            let priceResponse = IOracle::get_data_for_sources(
                @self, data_type, aggregation_mode, sources
            );
            assert(!priceResponse.last_updated_timestamp.is_zero(), 'No checkpoint available');

            let sources_threshold = self.oracle_sources_threshold_storage.read();
            let cur_checkpoint = IOracle::get_latest_checkpoint(@self, data_type, aggregation_mode);
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
                        let cur_idx = self.oracle_checkpoint_index.read((pair_id, SPOT, 0));
                        self.oracle_checkpoints.write((pair_id, SPOT, cur_idx, 0), new_checkpoint);
                        self.oracle_checkpoint_index.write((pair_id, SPOT, 0), cur_idx + 1);
                        self.emit(Event::CheckpointSpotEntry(CheckpointSpotEntry { pair_id }));
                    },
                    DataType::FutureEntry((
                        pair_id, expiration_timestamp
                    )) => {
                        let cur_idx = self
                            .oracle_checkpoint_index
                            .read((pair_id, FUTURE, expiration_timestamp));
                        self
                            .oracle_checkpoints
                            .write(
                                (pair_id, FUTURE, cur_idx, expiration_timestamp), new_checkpoint
                            );
                        self
                            .oracle_checkpoint_index
                            .write((pair_id, FUTURE, expiration_timestamp), cur_idx + 1);
                        self
                            .emit(
                                Event::CheckpointFutureEntry(
                                    CheckpointFutureEntry { pair_id, expiration_timestamp }
                                )
                            );
                    },
                }
            }
            return ();
        }


        fn set_checkpoints(
            ref self: ContractState, data_types: Span<DataType>, aggregation_mode: AggregationMode
        ) {
            let mut cur_idx: u32 = 0;
            loop {
                if (cur_idx == data_types.len()) {
                    break ();
                }
                let data_type: DataType = *data_types.get(cur_idx).unwrap().unbox();
                IOracle::set_checkpoint(ref self, data_type, aggregation_mode);
                cur_idx += 1;
            }
        }


        fn set_admin_address(ref self: ContractState, new_admin_address: ContractAddress) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let old_admin = Admin::get_admin_address(@state);
            assert(new_admin_address != old_admin, 'Same admin address');
            assert(!new_admin_address.is_zero(), 'Admin address cannot be zero');
            Admin::set_admin_address(ref state, new_admin_address);
        }


        fn set_sources_threshold(ref self: ContractState, threshold: u32) {
            self.assert_only_admin();
            self.oracle_sources_threshold_storage.write(threshold);
        }
    }


    //ISSUE HERE, DO NOT RETURN ARRAY
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
        }
    }

    fn get_checkpoint_by_index(
        self: @ContractState, data_type: DataType, checkpoint_index: u64
    ) -> Checkpoint {
        let checkpoint = match data_type {
            DataType::SpotEntry(pair_id) => {
                self.oracle_checkpoints.read((pair_id, SPOT, checkpoint_index, 0))
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                self
                    .oracle_checkpoints
                    .read((pair_id, FUTURE, checkpoint_index, expiration_timestamp))
            },
        };
        assert(!checkpoint.timestamp.is_zero(), 'Checkpoint does not exist');
        checkpoint.timestamp.print();
        return checkpoint;
    }


    fn get_latest_checkpoint_index(
        self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode
    ) -> (u64, bool) {
        let checkpoint_index = match data_type {
            DataType::SpotEntry(pair_id) => {
                self.oracle_checkpoint_index.read((pair_id, SPOT, 0))
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                self.oracle_checkpoint_index.read((pair_id, FUTURE, expiration_timestamp))
            },
        };

        if (checkpoint_index == 0) {
            return (0, false);
        } else {
            return (checkpoint_index - 1, true);
        }
    }


    fn validate_sender_for_source<T, impl THasBaseEntry: hasBaseEntry<T>, impl TDrop: Drop<T>>(
        self: @ContractState, _entry: T
    ) {
        let publisher_registry_address = IOracle::get_publisher_registry_address(self);
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
        };

        if (storage_len == 0) {
            return 0;
        } else {
            loop {
                if (cur_idx == sources.len()) {
                    break ();
                }
                let source: felt252 = *sources.get(cur_idx).unwrap().unbox();
                let entry: PossibleEntries = IOracle::get_data_entry(self, data_type, source);

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
                    }
                }
                cur_idx += 1;
            };
            return latest_timestamp;
        }
    }

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
            let g_entry: PossibleEntries = IOracle::get_data_entry(self, data_type, source);
            match g_entry {
                PossibleEntries::Spot(spot_entry) => {
                    let is_entry_not_initialized: bool = spot_entry.get_base_timestamp() == 0;
                    let condition: bool = is_entry_not_initialized
                        & (spot_entry
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
                }
            };

            cur_idx += 1;
        };
        return ();
    }


    fn get_all_entries(
        self: @ContractState, data_type: DataType, sources: Span<felt252>, max_timestamp: u64
    ) -> (Array<PossibleEntries>, u32) {
        let mut entries = ArrayTrait::<PossibleEntries>::new();

        build_entries_array(self, data_type, sources, ref entries, max_timestamp);
        (entries, entries.len())
    }
    fn filter_data_array(data_type: DataType, data: @Array<PossibleEntries>) -> ArrayEntry {
        match data_type {
            DataType::SpotEntry(pair_id) => {
                let mut cur_idx = 0;
                let mut spot_entries = ArrayTrait::<SpotEntry>::new();
                loop {
                    if (cur_idx >= data.len()) {
                        break ();
                    }
                    let entry = *data.at(cur_idx);
                    match entry {
                        PossibleEntries::Spot(spot_entry) => {
                            spot_entries.append(spot_entry);
                        },
                        PossibleEntries::Future(_) => {}
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
                    if (cur_idx >= data.len()) {
                        break ();
                    }
                    let entry = *data.at(cur_idx);
                    match entry {
                        PossibleEntries::Spot(_) => {},
                        PossibleEntries::Future(future_entry) => {
                            future_entries.append(future_entry);
                        }
                    }
                    cur_idx = cur_idx + 1;
                };
                ArrayEntry::FutureEntry(future_entries)
            }
        }
    }

    fn validate_data_timestamp<T, impl THasBaseEntry: hasBaseEntry<T>, impl TDrop: Drop<T>>(
        ref self: ContractState, new_entry: PossibleEntries, last_entry: T, 
    ) {
        match new_entry {
            PossibleEntries::Spot(spot_entry) => {
                assert(
                    spot_entry.get_base_timestamp() > last_entry.get_base_timestamp(),
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
                    future_entry.get_base_timestamp() > last_entry.get_base_timestamp(),
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
        // PossibleEntries::OptionEntry(option_entry) => {}
        }
        return ();
    }

    fn add_pair(ref self: ContractState, pair: Pair) {
        let check_pair = self.oracle_pairs_storage.read(pair.id);
        assert(check_pair.id == 0, 'Pair with this key registered');
        self.emit(Event::SubmittedPair(SubmittedPair { pair }));
        self.oracle_pairs_storage.write(pair.id, pair);
        self.oracle_pair_id_storage.write((pair.quote_currency_id, pair.base_currency_id), pair.id);
        return ();
    }


    fn set_sources_threshold(ref self: ContractState, threshold: u32) {
        self.oracle_sources_threshold_storage.write(threshold);
        return ();
    }
    fn find_startpoint(
        self: @ContractState, data_type: DataType, aggregation_mode: AggregationMode, timestamp: u64
    ) -> u64 {
        let (latest_checkpoint_index, _) = get_latest_checkpoint_index(
            self, data_type, aggregation_mode
        );

        let cp = get_checkpoint_by_index(self, data_type, latest_checkpoint_index);

        if (cp.timestamp <= timestamp) {
            return latest_checkpoint_index;
        }
        let first_cp = get_checkpoint_by_index(self, data_type, 0);
        if (timestamp <= first_cp.timestamp) {
            assert(false, 'Timestamp is too old');
            return 0;
        }
        let startpoint = _binary_search(self, data_type, 0, latest_checkpoint_index, timestamp);
        return startpoint;
    }
    fn _binary_search(
        self: @ContractState, data_type: DataType, low: u64, high: u64, target: u64
    ) -> u64 {
        let high_cp = get_checkpoint_by_index(self, data_type, high);
        if (high_cp.timestamp <= target) {
            return high;
        }

        // Find the middle point
        let midpoint = low + high / 2;

        // If middle point is target.
        let past_midpoint_cp = get_checkpoint_by_index(self, data_type, midpoint - 1);
        let midpoint_cp = get_checkpoint_by_index(self, data_type, midpoint);

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
            return _binary_search(self, data_type, low, midpoint - 1, target);
        }

        // If mid-1 is not floor and x is
        // greater than arr[mid],
        return _binary_search(self, data_type, midpoint + 1, high, target);
    }

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
            }
            idx = idx + 1;
        };
        return ();
    }
}

