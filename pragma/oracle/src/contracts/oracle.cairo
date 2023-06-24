use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntryStorage, FutureEntry, OptionEntry,
    simpleDataType, SpotEntryStorage, FutureEntryStorage, AggregationMode, PossibleEntries,
    ArrayEntry
};
use serde::{Serde};
use serde::deserialize_array_helper;
use serde::serialize_array_helper;
use starknet::{StorageAccess, StorageBaseAddress, SyscallResult};
use starknet::{
    storage_read_syscall, storage_write_syscall, storage_address_from_base_and_offset,
    storage_access::storage_base_address_from_felt252
};
use traits::Into;
use traits::TryInto;
use box::BoxTrait;
use result::{ResultTrait, ResultTraitImpl};
use oracle::business_logic::oracleInterface::IOracle;
use starknet::{ContractAddress, get_caller_address};
use array::{ArrayTrait};
use admin::contracts::Admin::Admin;
use starknet::class_hash::ClassHash;
use zeroable::Zeroable;
use upgradeable::contracts::upgradeable::Upgradeable;

#[abi]
trait IOracleABI {
    #[internal]
    fn initializer(
        proxy_admin: felt252,
        publisher_registry_address: ContractAddress,
        currencies: Span<Currency>,
        pairs: Span<Pair>
    );
    #[view]
    fn get_decimals(data_type: DataType) -> u32;
    #[view]
    fn get_data_median(data_type: DataType) -> PragmaPricesResponse;
    #[view]
    fn get_data_median_for_sources(
        data_type: DataType, sources: Span<felt252>
    ) -> PragmaPricesResponse;
    #[view]
    fn get_data(data_type: DataType, aggregation_mode: AggregationMode) -> PragmaPricesResponse;
    #[view]
    fn get_data_entry(data_type: DataType, source: felt252) -> PossibleEntries;
    #[view]
    fn get_data_for_sources(
        data_type: DataType, aggregation_mode: AggregationMode, sources: Span<felt252>
    ) -> PragmaPricesResponse;
    #[view]
    fn get_data_entries_for_sources(
        data_type: DataType, sources: Span<felt252>
    ) -> (Array<PossibleEntries>, u32, u64);
    #[view]
    fn get_data_median_multi(
        data_types: Span<DataType>, sources: Span<felt252>
    ) -> Array<PragmaPricesResponse>;

    #[view]
    fn get_data_entries(data_type: DataType) -> Array<PossibleEntries>;
    #[view]
    fn get_last_checkpoint_before(timestamp: u64, data_type: DataType) -> (Checkpoint, u64);
    #[view]
    fn get_data_with_USD_hop(
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: AggregationMode,
        typeof: simpleDataType,
        expiration_timestamp: Option::<u64>
    ) -> PragmaPricesResponse;
    #[view]
    fn get_publisher_registry_address() -> ContractAddress;
    #[view]
    fn get_latest_checkpoint_index(data_type: DataType, aggregation_mode: AggregationMode) -> u64;
    #[view]
    fn get_latest_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) -> Checkpoint;
    #[view]
    fn get_checkpoint(data_type: DataType, checkpoint_index: u64) -> Checkpoint;
    #[view]
    fn get_sources_threshold() -> u32;
    #[view]
    fn get_admin_address() -> ContractAddress;
    #[external]
    fn publish_data(new_entry: PossibleEntries);
    #[external]
    fn publish_data_entries(new_entries: Array<PossibleEntries>, );
    #[external]
    fn set_admin_address(new_admin_address: ContractAddress);
    #[external]
    fn update_publisher_registry_address(new_publisher_registry_address: ContractAddress);
    #[external]
    fn add_currency(currency: Currency);
    #[external]
    fn update_currency(new_currency: Currency);
    #[external]
    fn add_pair(new_pair: Pair);
    #[external]
    fn set_checkpoint(data_type: DataType, aggregation_mode: AggregationMode);
    #[external]
    fn set_checkpoints(data_types: Span<DataType>, aggregation_mode: AggregationMode);
    #[external]
    fn set_sources_threshold(threshold: u32);
}


#[abi]
trait IPragmaABI {
    #[view]
    fn get_decimals(data_type: DataType) -> u32;
    #[view]
    fn get_data_median(data_type: DataType) -> PragmaPricesResponse;
    #[view]
    fn get_data_median_for_sources(
        data_type: DataType, sources: Span<felt252>
    ) -> PragmaPricesResponse;
    #[view]
    fn get_data(data_type: DataType, aggregation_mode: AggregationMode) -> PragmaPricesResponse;
    #[view]
    fn get_data_entry(data_type: DataType, source: felt252) -> PossibleEntries;
    #[view]
    fn get_data_for_sources(
        data_type: DataType, aggregation_mode: AggregationMode, sources: Span<felt252>
    ) -> PragmaPricesResponse;
    #[view]
    fn get_data_entries_for_sources(
        data_type: DataType, sources: Span<felt252>
    ) -> (Array<PossibleEntries>, u32, u64);
    #[view]
    fn get_data_median_multi(
        data_types: Span<DataType>, sources: Span<felt252>
    ) -> Array<PragmaPricesResponse>;

    #[view]
    fn get_data_entries(data_type: DataType) -> Array<PossibleEntries>;
    #[view]
    fn get_last_checkpoint_before(timestamp: u64, data_type: DataType) -> (Checkpoint, u256);
    #[view]
    fn get_data_with_USD_hop(
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: AggregationMode,
        typeof: simpleDataType,
        expiration_timestamp: Option::<u64>
    ) -> PragmaPricesResponse;
    #[view]
    fn get_latest_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) -> Checkpoint;
}


#[contract]
mod Oracle {
    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use cmp::{max, min};
    use entry::contracts::entry::Entry;
    use option::OptionTrait;
    use array::{ArrayTrait, SpanTrait};
    use traits::Into;
    use traits::TryInto;
    use box::BoxTrait;
    use result::{ResultTrait, ResultTraitImpl};
    use entry::contracts::structs::{
        BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
        USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntryStorage, FutureEntry, OptionEntry,
        simpleDataType, SpotEntryStorage, FutureEntryStorage, AggregationMode, PossibleEntries,
        ArrayEntry
    };

    use oracle::business_logic::oracleInterface::IOracle;
    use pragma::bits_manipulation::bits_manipulation::{
        actual_set_element_at, actual_get_element_at
    };
    use upgradeable::contracts::upgradeable::Upgradeable;
    use pragma::time_series::convert::convert_via_usd;
    use admin::contracts::Admin::Admin;
    use serde::{Serde};
    use serde::deserialize_array_helper;
    use serde::serialize_array_helper;
    use starknet::{StorageAccess, StorageBaseAddress, SyscallResult};
    use starknet::{
        storage_read_syscall, storage_write_syscall, storage_address_from_base_and_offset,
        storage_access::storage_base_address_from_felt252
    };
    use starknet::{ContractAddress, Felt252TryIntoContractAddress};
    use starknet::{get_block_timestamp};
    use publisher_registry::contracts::publisher_registry::{
        IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
    };
    use starknet::ClassHash;
    const BACKWARD_TIMESTAMP_BUFFER: u64 = 7800; // 2 hours and 10 minutes
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
        //oracle_checkpoints, legacyMap between, (pair_id, (SPOT/FUTURES/OPTIONS), index, expiration_timestamp (0 for SPOT)) asociated to a checkpoint
        oracle_checkpoints: LegacyMap::<(felt252, felt252, u64, u64), Checkpoint>,
        //oracle_checkpoint_index, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), expiration_timestamp (0 for SPOT)) and the index of the last checkpoint
        oracle_checkpoint_index: LegacyMap::<(felt252, felt252, u64), u64>,
        oracle_sources_threshold_storage: u32,
    }

    impl SpanSerde<
        T, impl TSerde: Serde<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>
    > of Serde<Span<T>> {
        fn serialize(self: @Span<T>, ref output: Array<felt252>) {
            (*self).len().serialize(ref output);
            serialize_array_helper(*self, ref output);
        }
        fn deserialize(ref serialized: Span<felt252>) -> Option<Span<T>> {
            let length = *serialized.pop_front()?;
            let mut arr = ArrayTrait::new();
            Option::Some(deserialize_array_helper(ref serialized, arr, length)?.span())
        }
    }

    //ORACLE DATA ENTRY STORAGE -> CHECK 
    trait workingEntry<T> {
        fn process(self: @T) -> felt252;
    }
    impl SworkingEntryImpl of workingEntry<SpotEntry> {
        fn process(self: @SpotEntry) -> felt252 {
            return (SPOT);
        }
    }
    impl FworkingEntryImpl of workingEntry<FutureEntry> {
        fn process(self: @FutureEntry) -> felt252 {
            return (FUTURE);
        }
    }
    impl OworkingEntryImpl of workingEntry<OptionEntry> {
        fn process(self: @OptionEntry) -> felt252 {
            return (OPTION);
        }
    }

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

    impl PairStorageAccess of StorageAccess<Pair> {
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Pair> {
            Result::Ok(
                Pair {
                    id: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 0_u8)
                    )?,
                    quote_currency_id: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 1_u8)
                    )?,
                    base_currency_id: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 2_u8)
                    )?
                }
            )
        }
        #[inline(always)]
        fn write(address_domain: u32, base: StorageBaseAddress, value: Pair) -> SyscallResult<()> {
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 0_u8), value.id, 
            )?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 1_u8),
                value.quote_currency_id,
            )?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 2_u8),
                value.base_currency_id,
            )
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
                AggregationMode::Error(()) => 150_u8,
            }
        }
    }

    fn u8_into_AggregationMode(value: u8) -> AggregationMode {
        if value == 0_u8 {
            return AggregationMode::Median(());
        } else {
            return AggregationMode::Error(());
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
                storage_address_from_base_and_offset(base, 3_u8),
                aggregation_mode_u8.into(),
            )?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 4_u8),
                value.num_sources_aggregated.into(),
            )
        }
    }

    impl CurrencyStorageAccess of StorageAccess<Currency> {
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Currency> {
            let mut starknet_address_value = storage_read_syscall(
                address_domain, storage_address_from_base_and_offset(base, 3_u8)
            );
            let mut ethereum_address_value = storage_read_syscall(
                address_domain, storage_address_from_base_and_offset(base, 4_u8)
            );
            Result::Ok(
                Currency {
                    id: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 0_u8)
                    )?,
                    decimals: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 1_u8)
                    )?
                        .try_into()
                        .unwrap(),
                    is_abstract_currency: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 2_u8)
                    )?,
                    starknet_address: starknet_address_value
                        .unwrap()
                        .try_into()
                        .expect('Invalid starknet address'),
                    ethereum_address: ethereum_address_value
                        .unwrap()
                        .try_into()
                        .expect('Invalid ethereum address'),
                }
            )
        }
        #[inline(always)]
        fn write(
            address_domain: u32, base: StorageBaseAddress, value: Currency
        ) -> SyscallResult<()> {
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 0_u8), value.id, 
            )?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 1_u8),
                value.decimals.into(),
            )?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 2_u8),
                value.is_abstract_currency.into(),
            )?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 3_u8),
                value.starknet_address.into(),
            )?;
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, 4_u8),
                value.ethereum_address.into(),
            )
        }
    }
    #[event]
    fn UpdatedPublisherRegistryAddress(
        old_publisher_registry_address: ContractAddress,
        new_publisher_registry_address: ContractAddress
    ) {}

    #[event]
    fn SubmittedSpotEntry(spot_entry: SpotEntry) {}

    #[event]
    fn SubmittedFutureEntry(future_entry: FutureEntry) {}

    #[event]
    fn SubmittedOptionEntry(option_entry: OptionEntry) {}

    #[event]
    fn SubmittedCurrency(currency: Currency) {}

    #[event]
    fn UpdatedCurrency(currency: Currency) {}

    #[event]
    fn SubmittedPair(pair: Pair) {}

    #[event]
    fn CheckpointSpotEntry(pair_id: felt252) {}

    #[event]
    fn CheckpointFutureEntry(pair_id: felt252, expiration_timestamp: u64) {}

    impl IOracleImpl of IOracle {
        #[external]
        fn initializer(
            proxy_admin: felt252,
            publisher_registry_address: ContractAddress,
            currencies: Span<Currency>,
            pairs: Span<Pair>
        ) {
            oracle_publisher_registry_address_storage::write(publisher_registry_address);
            _set_keys_currencies(currencies, 0);
            _set_keys_pairs(pairs);
            return ();
        }

        //
        // Getters
        //

        #[view]
        fn get_data_entries_for_sources(
            data_type: DataType, sources: Span<felt252>
        ) -> (Array<PossibleEntries>, u32, u64) {
            let last_updated_timestamp = get_latest_entry_timestamp(data_type, sources);
            let current_timestamp: u64 = get_block_timestamp();
            let conservative_current_timestamp = min(last_updated_timestamp, current_timestamp);
            let (entries, entries_len) = get_all_entries(
                data_type, sources, conservative_current_timestamp
            );
            (entries, entries_len, last_updated_timestamp)
        }


        #[view]
        fn get_data_entries(data_type: DataType) -> Array<PossibleEntries> {
            let mut sources = ArrayTrait::<felt252>::new();
            let sources = get_all_sources(data_type).span();
            let (entries, _, _) = IOracle::get_data_entries_for_sources(data_type, sources);
            entries
        }


        #[view]
        fn get_data_median(data_type: DataType) -> PragmaPricesResponse {
            let sources = get_all_sources(data_type).span();
            let prices_response: PragmaPricesResponse = IOracle::get_data_for_sources(
                data_type, AggregationMode::Median(()), sources
            );
            prices_response
        }

        #[view]
        fn get_data_median_for_sources(
            data_type: DataType, sources: Span<felt252>
        ) -> PragmaPricesResponse {
            let prices_response: PragmaPricesResponse = IOracle::get_data_for_sources(
                data_type, AggregationMode::Median(()), sources
            );
            prices_response
        }

        #[view]
        fn get_data_median_multi(
            data_types: Span<DataType>, sources: Span<felt252>
        ) -> Array<PragmaPricesResponse> {
            let mut prices_response = ArrayTrait::<PragmaPricesResponse>::new();
            let mut cur_idx = 0;
            loop {
                if (cur_idx >= data_types.len()) {
                    break ();
                }

                let data_type = *data_types.at(cur_idx);
                let cur_prices_response: PragmaPricesResponse = IOracle::get_data_for_sources(
                    data_type, AggregationMode::Median(()), sources
                );
                prices_response.append(cur_prices_response);
                cur_idx += 1;
            };
            prices_response
        }

        #[view]
        fn get_data(
            data_type: DataType, aggregation_mode: AggregationMode
        ) -> PragmaPricesResponse {
            let sources = get_all_sources(data_type).span();
            let prices_response: PragmaPricesResponse = IOracle::get_data_for_sources(
                data_type, aggregation_mode, sources
            );
            prices_response
        }

        #[view]
        fn get_data_for_sources(
            data_type: DataType, aggregation_mode: AggregationMode, sources: Span<felt252>
        ) -> PragmaPricesResponse {
            let mut entries = ArrayTrait::<PossibleEntries>::new();
            let (entries, entries_len, last_updated_timestamp) =
                IOracle::get_data_entries_for_sources(
                data_type, sources
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
            let filtered_entries: ArrayEntry = filter_data_array(data_type, @entries);

            match data_type {
                DataType::SpotEntry(pair_id) => {
                    match filtered_entries {
                        ArrayEntry::SpotEntry(array_spot) => {
                            let price = Entry::aggregate_entries::<SpotEntry>(
                                @array_spot, aggregation_mode
                            );
                            let decimals = IOracle::get_decimals(data_type);
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
                            assert(1 == 1, 'Wrong data type');
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
                            assert(1 == 1, 'Wrong data type');
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
                            let decimals = IOracle::get_decimals(data_type);
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


        #[view]
        fn get_publisher_registry_address() -> ContractAddress {
            get_publisher_registry_address()
        }

        #[view]
        fn get_decimals(data_type: DataType) -> u32 {
            let currency = match data_type {
                DataType::SpotEntry(pair_id) => {
                    let pair = oracle_pairs_storage::read(pair_id);
                    oracle_currencies_storage::read(pair.base_currency_id)
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    let pair = oracle_pairs_storage::read(pair_id);
                    oracle_currencies_storage::read(pair.base_currency_id)
                },
            // DataType::OptionEntry((pair_id, expiration_timestamp)) => {}
            };
            currency.decimals
        }

        #[view]
        fn get_data_with_USD_hop(
            base_currency_id: felt252,
            quote_currency_id: felt252,
            aggregation_mode: AggregationMode,
            typeof: simpleDataType,
            expiration_timestamp: Option<u64>
        ) -> PragmaPricesResponse {
            let mut sources = ArrayTrait::<felt252>::new().span();
            let base_pair_id = oracle_pair_id_storage::read((base_currency_id, USD_CURRENCY_ID));
            let quote_pair_id = oracle_pair_id_storage::read((quote_currency_id, USD_CURRENCY_ID));
            let (base_data_type, quote_data_type, currency) = match typeof {
                simpleDataType::SpotEntry(()) => {
                    (
                        DataType::SpotEntry(base_pair_id),
                        DataType::SpotEntry(quote_pair_id),
                        oracle_currencies_storage::read(quote_currency_id)
                    )
                },
                simpleDataType::FutureEntry(()) => {
                    match expiration_timestamp {
                        Option::Some(expiration) => {
                            let base_dt = DataType::FutureEntry((base_pair_id, expiration));
                            let quote_dt = DataType::FutureEntry((quote_pair_id, expiration));
                            (base_dt, quote_dt, oracle_currencies_storage::read(quote_currency_id))
                        },
                        Option::None(_) => {
                            // Handle case where Future data type was provided without an expiration timestamp
                            assert(1 == 1, 'Requires expiration timestamp');
                            (
                                DataType::FutureEntry((base_pair_id, 0)),
                                DataType::FutureEntry((quote_pair_id, 0)),
                                oracle_currencies_storage::read(quote_currency_id)
                            )
                        }
                    }
                },
            };
            let basePPR: PragmaPricesResponse = IOracle::get_data_for_sources(
                base_data_type, aggregation_mode, sources
            );
            let quotePPR: PragmaPricesResponse = IOracle::get_data_for_sources(
                quote_data_type, aggregation_mode, sources
            );
            let decimals = min(
                IOracle::get_decimals(base_data_type), IOracle::get_decimals(quote_data_type)
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


        #[view]
        fn get_latest_checkpoint_index(
            data_type: DataType, aggregation_mode: AggregationMode
        ) -> u64 {
            get_latest_checkpoint_index(data_type, aggregation_mode)
        }

        #[view]
        fn get_latest_checkpoint(
            data_type: DataType, aggregation_mode: AggregationMode
        ) -> Checkpoint {
            let checkpoint_index = get_latest_checkpoint_index(data_type, aggregation_mode);
            get_checkpoint_by_index(data_type, checkpoint_index)
        }


        #[view]
        fn get_checkpoint(data_type: DataType, checkpoint_index: u64) -> Checkpoint {
            get_checkpoint_by_index(data_type, checkpoint_index)
        }

        #[view]
        fn get_sources_threshold() -> u32 {
            get_sources_threshold()
        }

        #[view]
        fn get_admin_address() -> ContractAddress {
            Admin::get_admin_address()
        }

        #[view]
        fn get_implementation_hash() -> ClassHash {
            Upgradeable::get_implementation_hash()
        }

        #[view]
        fn get_last_checkpoint_before(
            data_type: DataType, aggregation_mode: AggregationMode, timestamp: u64
        ) -> (Checkpoint, u64) {
            let idx = find_startpoint(data_type, aggregation_mode, timestamp);
            let checkpoint = get_checkpoint_by_index(data_type, idx);
            (checkpoint, idx)
        }

        #[view]
        fn get_data_entry(data_type: DataType, source: felt252) -> PossibleEntries {
            let _entry = match data_type {
                DataType::SpotEntry(pair_id) => {
                    oracle_data_entry_storage::read((pair_id, source, SPOT, 0))
                },
                DataType::FutureEntry((
                    pair_id, expiration_timestamp
                )) => {
                    oracle_data_entry_storage::read((pair_id, source, FUTURE, expiration_timestamp))
                },
            };
            let u256_timestamp = actual_get_element_at(_entry, 0, 31);
            let timestamp: u64 = u256_timestamp.try_into().unwrap().try_into().unwrap();
            let volume = actual_get_element_at(_entry, 32, 42);
            let price = actual_get_element_at(_entry, 75, 128);
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

        #[external]
        fn publish_data(new_entry: PossibleEntries) {
            match new_entry {
                PossibleEntries::Spot(spot_entry) => {
                    validate_sender_for_source(spot_entry);
                    let entry: PossibleEntries = IOracle::get_data_entry(
                        DataType::SpotEntry(spot_entry.pair_id), spot_entry.base.source
                    );
                    match entry {
                        PossibleEntries::Spot(spot) => {
                            validate_data_timestamp(new_entry, spot);
                            SubmittedSpotEntry(spot_entry);
                            let conv_timestamp: u256 = u256 {
                                low: spot_entry.base.timestamp.into(), high: 0
                            };
                            let element = actual_set_element_at(0, 0, 31, conv_timestamp);
                            let element = actual_set_element_at(element, 32, 42, spot_entry.volume);
                            let element = actual_set_element_at(element, 75, 128, spot_entry.price);
                            let spot_entry_storage = SpotEntryStorage {
                                timestamp__volume__price: element
                            };
                            oracle_data_entry_storage::write(
                                (spot_entry.pair_id, SPOT, spot_entry.base.source, 0), element
                            );
                        },
                        PossibleEntries::Future(_) => {
                            assert(1 == 1, 'Failed fetching spot entry');
                        },
                    }
                },
                PossibleEntries::Future(future_entry) => {
                    validate_sender_for_source(future_entry);
                    let entry: PossibleEntries = IOracle::get_data_entry(
                        DataType::FutureEntry(
                            (future_entry.pair_id, future_entry.expiration_timestamp)
                        ),
                        future_entry.base.source
                    );
                    match entry {
                        PossibleEntries::Spot(_) => {
                            assert(1 == 1, 'Failed fetching future entry');
                        },
                        PossibleEntries::Future(future) => {
                            validate_data_timestamp::<FutureEntry>(new_entry, future);
                            SubmittedFutureEntry(future_entry);
                            let conv_timestamp: u256 = u256 {
                                low: future_entry.base.timestamp.into(), high: 0
                            };
                            let element = actual_set_element_at(0, 0, 31, conv_timestamp);
                            let element = actual_set_element_at(
                                element, 32, 42, future_entry.volume
                            );
                            let element = actual_set_element_at(
                                element, 75, 128, future_entry.price
                            );
                            let future_entry_storage = FutureEntryStorage {
                                timestamp__volume__price: element
                            };
                            oracle_data_entry_storage::write(
                                (
                                    future_entry.pair_id,
                                    FUTURE,
                                    future_entry.base.source,
                                    future_entry.expiration_timestamp
                                ),
                                element
                            );
                        },
                    }
                },
            }
            return ();
        }


        #[external]
        fn publish_data_entries(new_entries: Span<PossibleEntries>) {
            let mut cur_idx = 0;
            loop {
                if (cur_idx >= new_entries.len()) {
                    break ();
                }
                let new_entry = *new_entries.at(cur_idx);
                IOracle::publish_data(new_entry);
                cur_idx = cur_idx + 1;
            }
        }


        #[external]
        fn update_publisher_registry_address(new_publisher_registry_address: ContractAddress) {
            assert_only_admin();
            let old_publisher_registry_address = oracle_publisher_registry_address_storage::read();
            oracle_publisher_registry_address_storage::write(new_publisher_registry_address);
            UpdatedPublisherRegistryAddress(
                old_publisher_registry_address, new_publisher_registry_address
            );
            return ();
        }

        #[external]
        fn add_currency(new_currency: Currency) {
            assert_only_admin();
            let existing_currency = oracle_currencies_storage::read(new_currency.id);
            assert(existing_currency.id == 0, 'Currency already exists for key');
            SubmittedCurrency(new_currency);
            oracle_currencies_storage::write(new_currency.id, new_currency);
            return ();
        }

        #[external]
        fn update_currency(currency: Currency) {
            assert_only_admin();
            oracle_currencies_storage::write(currency.id, currency);
            UpdatedCurrency(currency);
            return ();
        }

        #[external]
        fn add_pair(new_pair: Pair) {
            assert_only_admin();
            let check_pair = oracle_pairs_storage::read(new_pair.id);
            assert(check_pair.id == 0, 'Pair with this key registered');
            SubmittedPair(new_pair);
            oracle_pairs_storage::write(new_pair.id, new_pair);
            oracle_pair_id_storage::write(
                (new_pair.quote_currency_id, new_pair.base_currency_id), new_pair.id
            );
            return ();
        }

        #[external]
        fn set_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) {
            let mut sources = ArrayTrait::<felt252>::new().span();
            let priceResponse = IOracle::get_data_for_sources(data_type, aggregation_mode, sources);
            let sources_threshold = oracle_sources_threshold_storage::read();
            let cur_checkpoint = IOracle::get_latest_checkpoint(data_type, aggregation_mode);
            let timestamp: u64 = get_block_timestamp();
            if (sources_threshold < priceResponse.num_sources_aggregated
                & (cur_checkpoint.timestamp + 1) < timestamp) {
                let new_checkpoint = Checkpoint {
                    timestamp: timestamp,
                    value: priceResponse.price,
                    aggregation_mode: aggregation_mode,
                    num_sources_aggregated: priceResponse.num_sources_aggregated
                };
                match data_type {
                    DataType::SpotEntry(pair_id) => {
                        let cur_idx = oracle_checkpoint_index::read((pair_id, SPOT, 0));
                        oracle_checkpoints::write((pair_id, SPOT, cur_idx, 0), new_checkpoint);
                        oracle_checkpoint_index::write((pair_id, SPOT, 0), cur_idx + 1);
                        CheckpointSpotEntry(pair_id);
                    },
                    DataType::FutureEntry((
                        pair_id, expiration_timestamp
                    )) => {
                        let cur_idx = oracle_checkpoint_index::read(
                            (pair_id, FUTURE, expiration_timestamp)
                        );
                        oracle_checkpoints::write(
                            (pair_id, FUTURE, cur_idx, expiration_timestamp), new_checkpoint
                        );
                        oracle_checkpoint_index::write(
                            (pair_id, FUTURE, expiration_timestamp), cur_idx + 1
                        );
                        CheckpointFutureEntry(pair_id, expiration_timestamp);
                    },
                }
            }
            return ();
        }

        #[external]
        fn set_checkpoints(data_types: Span<DataType>, aggregation_mode: AggregationMode) {
            let mut cur_idx: u32 = 0;
            loop {
                if (cur_idx == data_types.len()) {
                    break ();
                }
                let data_type: DataType = *data_types.get(cur_idx).unwrap().unbox();
                IOracle::set_checkpoint(data_type, aggregation_mode);
                cur_idx += 1;
            }
        }


        #[external]
        fn set_admin_address(new_admin_address: ContractAddress) {
            assert_only_admin();
            Admin::set_admin_address(new_admin_address);
        }

        #[external]
        fn set_sources_threshold(threshold: u32) {
            assert_only_admin();
            set_sources_threshold(threshold);
        }
    }
    #[internal]
    fn get_all_sources(data_type: DataType) -> Array<felt252> {
        let mut sources = ArrayTrait::<felt252>::new();
        match data_type {
            DataType::SpotEntry(pair_id) => {
                let source_len = oracle_sources_len_storage::read((pair_id, SPOT, 0));
                build_sources_array(data_type, ref sources, source_len);
                return sources;
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                let source_len = oracle_sources_len_storage::read(
                    (pair_id, FUTURE, expiration_timestamp)
                );
                build_sources_array(data_type, ref sources, source_len);
                return sources;
            },
        }
    }
    #[internal]
    fn get_checkpoint_by_index(data_type: DataType, checkpoint_index: u64) -> Checkpoint {
        let checkpoint = match data_type {
            DataType::SpotEntry(pair_id) => {
                oracle_checkpoints::read((pair_id, SPOT, checkpoint_index, 0))
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                oracle_checkpoints::read((pair_id, FUTURE, checkpoint_index, expiration_timestamp))
            },
        };
        return checkpoint;
    }

    #[internal]
    fn get_sources_threshold() -> u32 {
        oracle_sources_threshold_storage::read()
    }

    #[internal]
    fn get_latest_checkpoint_index(data_type: DataType, aggregation_mode: AggregationMode) -> u64 {
        let checkpoint_index = match data_type {
            DataType::SpotEntry(pair_id) => {
                oracle_checkpoint_index::read((pair_id, SPOT, 0))
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                oracle_checkpoint_index::read((pair_id, FUTURE, expiration_timestamp))
            },
        };
        return checkpoint_index;
    }
    #[internal]
    fn validate_sender_for_source<T, impl THasBaseEntry: hasBaseEntry<T>, impl TDrop: Drop<T>>(
        _entry: T
    ) {
        let publisher_registry_address = IOracle::get_publisher_registry_address();
        let publisher_registry_dispatcher = IPublisherRegistryABIDispatcher {
            contract_address: publisher_registry_address
        };
        let publisher_address = publisher_registry_dispatcher
            .get_publisher_address(_entry.get_base_entry().publisher);

        let _can_publish_source = publisher_registry_dispatcher
            .can_publish_source(_entry.get_base_entry().publisher, _entry.get_base_entry().source);
        //CHECK IF THIS VERIFICATION WORKS 
        let caller_address = get_caller_address();
        assert(publisher_address.is_zero(), 'Publisher is not registered');
        assert(!caller_address.is_zero(), 'Caller must not be zero address');
        assert(caller_address == publisher_address, 'Transaction not from publisher');
        assert(_can_publish_source == true, 'Not allowed for source');
        return ();
    }

    #[internal]
    fn get_latest_entry_timestamp(data_type: DataType, sources: Span<felt252>) -> u64 {
        let mut cur_idx = 0;
        let mut latest_timestamp = 0;
        loop {
            if (cur_idx >= sources.len()) {
                break ();
            }
            let source: felt252 = *sources.get(cur_idx).unwrap().unbox();
            let entry: PossibleEntries = IOracle::get_data_entry(data_type, source);
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

    #[internal]
    fn build_entries_array(
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
            let g_entry: PossibleEntries = IOracle::get_data_entry(data_type, source);
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


    #[internal]
    fn upgrade(impl_hash: ClassHash) {
        assert_only_admin();
        Upgradeable::upgrade(impl_hash);
    }


    #[internal]
    fn assert_only_admin() {
        let admin = Admin::get_admin_address();
        let caller = get_caller_address();
        assert(caller == admin, 'Admin: unauthorized');
    }

    #[internal]
    fn get_publisher_registry_address() -> ContractAddress {
        let publisher_registry_address = oracle_publisher_registry_address_storage::read();
        return publisher_registry_address;
    }

    #[internal]
    fn get_all_entries(
        data_type: DataType, sources: Span<felt252>, max_timestamp: u64
    ) -> (Array<PossibleEntries>, u32) {
        let mut entries = ArrayTrait::<PossibleEntries>::new();
        if (sources.len() == 0) {
            let all_sources = get_all_sources(data_type).span();
            build_entries_array(data_type, all_sources, ref entries, max_timestamp);
            (entries, entries.len())
        } else {
            build_entries_array(data_type, sources, ref entries, max_timestamp);
            (entries, entries.len())
        }
    }
    #[internal]
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
                        PossibleEntries::Future(_) => {
                            assert(false, 'Invalid entry type');
                        }
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
                        PossibleEntries::Spot(_) => {
                            assert(false, 'Invalid entry type');
                        },
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
    #[internal]
    fn validate_data_timestamp<T, impl THasBaseEntry: hasBaseEntry<T>, impl TDrop: Drop<T>>(
        new_entry: PossibleEntries, last_entry: T
    ) {
        match new_entry {
            PossibleEntries::Spot(spot_entry) => {
                assert(
                    spot_entry.get_base_timestamp() > last_entry.get_base_timestamp(),
                    'Existing entry is more recent'
                );
                if (last_entry.get_base_timestamp() == 0) {
                    let sources_len = oracle_sources_len_storage::read(
                        (spot_entry.pair_id, SPOT, 0)
                    );
                    oracle_sources_storage::write(
                        (spot_entry.pair_id, SPOT, sources_len, 0),
                        spot_entry.get_base_entry().source
                    );
                    oracle_sources_len_storage::write(
                        (spot_entry.pair_id, SPOT, 0), sources_len + 1
                    );
                }
            },
            PossibleEntries::Future(future_entry) => {
                assert(
                    future_entry.get_base_timestamp() > last_entry.get_base_timestamp(),
                    'Existing entry is more recent'
                );
                if (last_entry.get_base_timestamp() == 0) {
                    let sources_len = oracle_sources_len_storage::read(
                        (future_entry.pair_id, FUTURE, future_entry.expiration_timestamp)
                    );
                    oracle_sources_storage::write(
                        (
                            future_entry.pair_id,
                            FUTURE,
                            sources_len,
                            future_entry.expiration_timestamp
                        ),
                        future_entry.get_base_entry().source
                    );
                    oracle_sources_len_storage::write(
                        (future_entry.pair_id, FUTURE, future_entry.expiration_timestamp),
                        sources_len + 1
                    );
                }
            },
        // PossibleEntries::OptionEntry(option_entry) => {}
        }
        return ();
    }

    #[internal]
    fn add_pair(pair: Pair) {
        let check_pair = oracle_pairs_storage::read(pair.id);
        assert(check_pair.id == 0, 'Pair with this key registered');
        SubmittedPair(pair);
        oracle_pairs_storage::write(pair.id, pair);
        oracle_pair_id_storage::write((pair.quote_currency_id, pair.base_currency_id), pair.id);
        return ();
    }
    #[internal]
    fn _set_keys_currencies(key_currencies: Span<Currency>, idx: usize) {
        let mut idx: u32 = 0;
        loop {
            if (idx == key_currencies.len()) {
                break ();
            }

            let key_currency = *key_currencies.get(idx).unwrap().unbox();
            oracle_currencies_storage::write(key_currency.id, key_currency);
            idx = idx + 1;
        };
        return ();
    }

    fn set_sources_threshold(threshold: u32) {
        oracle_sources_threshold_storage::write(threshold);
        return ();
    }
    #[internal]
    fn find_startpoint(
        data_type: DataType, aggregation_mode: AggregationMode, timestamp: u64
    ) -> u64 {
        let last_checkpoint_index = get_latest_checkpoint_index(data_type, aggregation_mode);
        let latest_checkpoint_index = get_latest_checkpoint_index(data_type, aggregation_mode);
        let cp = get_checkpoint_by_index(data_type, latest_checkpoint_index - 1);
        let first_cp = get_checkpoint_by_index(data_type, 0);
        if (cp.timestamp < timestamp) {
            return latest_checkpoint_index - 1;
        }

        if (timestamp < first_cp.timestamp) {
            return 0;
        }
        let startpoint = _binary_search(data_type, 0, latest_checkpoint_index, timestamp);
        return startpoint;
    }
    #[internal]
    fn _binary_search(data_type: DataType, low: u64, high: u64, target: u64) -> u64 {
        let midpoint = (low + high) / 2;

        if (high == low) {
            return midpoint;
        }

        if ((high + 1) <= low) {
            return low - 1;
        }

        let cp = get_checkpoint_by_index(data_type, midpoint);
        let timestamp = cp.timestamp;

        if (timestamp == target) {
            return midpoint;
        }

        if (target <= timestamp) {
            return _binary_search(data_type, low, midpoint - 1, target);
        } else {
            return _binary_search(data_type, midpoint + 1, high, target);
        }
    }
    #[internal]
    fn _set_keys_pairs(key_pairs: Span<Pair>) {
        let mut idx: u32 = 0;
        loop {
            if (idx >= key_pairs.len()) {
                break ();
            }
            let key_pair = *key_pairs.get(idx).unwrap().unbox();
            oracle_pairs_storage::write(key_pair.id, key_pair);
            oracle_pair_id_storage::write(
                (key_pair.quote_currency_id, key_pair.base_currency_id), key_pair.id
            );
            idx = idx + 1;
        };
        return ();
    }
    #[internal]
    fn build_sources_array(data_type: DataType, ref sources: Array<felt252>, idx: u64) {
        match data_type {
            DataType::SpotEntry(pair_id) => {
                let new_source = oracle_sources_storage::read((pair_id, SPOT, idx, 0));
                sources.append(new_source);
            },
            DataType::FutureEntry((
                pair_id, expiration_timestamp
            )) => {
                let new_source = oracle_sources_storage::read(
                    (pair_id, FUTURE, idx, expiration_timestamp)
                );
                sources.append(new_source);
            }
        }
    }
}
