#[contract]
use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntryStorage, FutureEntry, OptionEntry,
    simpleDataType, SpotEntryStorage, FutureEntryStorage, AggregationMode, PossibleEntries,
    ArrayEntry
};

use oracle::contracts::library::Library;
use oracle::business_logic::oracleInterface::IOracle;
use starknet::{ContractAddress, get_caller_address};
use array::{ArrayTrait, SpanTrait};
use admin::contracts::Admin::Admin;
use starknet::class_hash::ClassHash;
use zeroable::Zeroable;
use upgradeable::contracts::Upgradeable;
use serde::deserialize_array_helper;
use serde::serialize_array_helper;
use serde::Serde;
use serde::ArraySerde;


#[abi]
trait IOracleABI {
    #[view]
    fn get_decimals(data_type: DataType) -> u32;
    #[view]
    fn get_data_median(data_type: DataType) -> u256;
    #[view]
    fn get_data_median_for_sources(data_type: DataType, sources: Span<felt252>) -> felt252;
    #[view]
    fn get_data(
        data_type: DataType, aggregation_mode: AggregationMode, sources: Span<felt252>
    ) -> PragmaPricesResponse;
    #[view]
    fn get_data_entry(data_type: DataType, source: felt252) -> PossibleEntries;
    #[view]
    fn get_data_for_sources(
        data_type: DataType, aggregation_mode: AggregationMode, sources: Span<felt252>
    ) -> Array<PragmaPricesResponse>;
    #[view]
    fn get_data_entries(data_type: DataType) -> (Array<PossibleEntries>, u32, u256);
    #[view]
    fn get_last_checkpoint_before(timestamp: u256, data_type: DataType) -> (Checkpoint, u256);
    #[view]
    fn get_data_with_USD_hop(
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: AggregationMode,
        typeof: simpleDataType,
        expiration_timestamp: Option::<u256>
    ) -> PragmaPricesResponse;
    #[view]
    fn get_publisher_registry_address() -> ContractAddress;
    #[view]
    fn get_latest_checkpoint_index(data_type: DataType, aggregation_mode: AggregationMode) -> u256;
    #[view]
    fn get_latest_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) -> Checkpoint;
    #[view]
    fn get_checkpoint(data_type: DataType, index: felt252) -> Checkpoint;
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
    fn update_currency(currency: Currency, typeof: felt252);
    #[external]
    fn add_pair(pair: Pair);
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
    fn get_data(data_type: DataType, aggregation_mode: felt252) -> PragmaPricesResponse;
    #[view]
    fn get_data_entry(data_type: DataType, source: felt252) -> PossibleEntries;
    #[view]
    fn get_data_median(data_type: DataType, ) -> PragmaPricesResponse;
    #[view]
    fn get_data_for_sources(
        data_type: DataType, aggregation_mode: AggregationMode, sources: Span<felt252>
    ) -> Array<PragmaPricesResponse>;
    #[view]
    fn get_data_entries(data_type: DataType) -> (Array<PossibleEntries>, u32, u256);
    #[view]
    fn get_data_decimals(data_type: DataType) -> felt252;
    #[view]
    fn get_last_data_checkpoint_before(
        timestamp: felt252, data_type: DataType
    ) -> (Checkpoint, felt252);
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

mod Oracle {
    use entry::contracts::structs::{
        BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
        USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntryStorage, FutureEntry, OptionEntry,
        simpleDataType, SpotEntryStorage, FutureEntryStorage, AggregationMode, PossibleEntries,
        ArrayEntry
    };

    use oracle::contracts::library::Library;
    use oracle::business_logic::oracleInterface::IOracle;
    use starknet::{ContractAddress, get_caller_address};
    use array::{ArrayTrait, SpanTrait};
    use admin::contracts::Admin::Admin;
    use starknet::class_hash::ClassHash;
    use zeroable::Zeroable;
    use pragma::upgradeable::contracts::Upgradeable;
    use serde::Serde;
    use serde::ArraySerde;

    #[external]
    fn initializer(
        proxy_admin: felt252,
        publisher_registry_address: ContractAddress,
        currencies: @Array<Currency>,
        pairs: @Array<Pair>
    ) {
        Library::initializer(publisher_registry_address, currencies, pairs);
        return ();
    }

    //
    // Getters
    //

    #[view]
    fn get_data_entries_for_sources(
        data_type: DataType, sources: Span<felt252>
    ) -> Array<PossibleEntries> {
        let (entries, _, _) = Library::get_data_entries(data_type, sources);
        entries
    }


    #[view]
    fn get_data_entries(data_type: DataType) -> Array<PossibleEntries> {
        let mut sources = ArrayTrait::<felt252>::new();
        let sources = Library::get_all_sources(data_type).span();
        let (entries, _, _) = Library::get_data_entries(data_type, sources);
        entries
    }


    #[view]
    fn get_data_median(data_type: DataType) -> PragmaPricesResponse {
        let sources = Library::get_all_sources(data_type).span();
        let prices_response: PragmaPricesResponse = Library::get_data(
            data_type, AggregationMode::Median(()), sources
        );
        prices_response
    }

    #[view]
    fn get_data_median_for_sources(
        data_type: DataType, sources: Span<felt252>
    ) -> PragmaPricesResponse {
        let prices_response: PragmaPricesResponse = Library::get_data(
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
            let cur_prices_response: PragmaPricesResponse = Library::get_data(
                data_type, AggregationMode::Median(()), sources
            );
            prices_response.append(cur_prices_response);
            cur_idx += 1;
        };
        prices_response
    }

    #[view]
    fn get_data(data_type: DataType, aggregation_mode: AggregationMode) -> PragmaPricesResponse {
        let sources = Library::get_all_sources(data_type).span();
        Library::get_data(data_type, aggregation_mode, sources)
    }

    #[view]
    fn get_data_for_sources(
        data_type: DataType, aggregationMode: AggregationMode, sources: Span<felt252>
    ) -> PragmaPricesResponse {
        Library::get_data(data_type, aggregationMode, sources)
    }


    #[view]
    fn get_publisher_registry_address() -> ContractAddress {
        Library::get_publisher_registry_address()
    }

    #[view]
    fn get_decimals(data_type: DataType) -> u32 {
        Library::get_decimals(data_type)
    }

    #[view]
    fn get_data_with_USD_hop(
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: AggregationMode,
        typeof: simpleDataType,
        expiration_timestamp: Option<u256>
    ) -> PragmaPricesResponse {
        Library::get_data_with_USD_hop(
            base_currency_id, quote_currency_id, aggregation_mode, typeof, expiration_timestamp
        )
    }

    #[view]
    fn get_latest_checkpoint_index(data_type: DataType, aggregation_mode: AggregationMode) -> u256 {
        Library::get_latest_checkpoint_index(data_type, aggregation_mode)
    }

    #[view]
    fn get_checkpoint(data_type: DataType, checkpoint_index: u256) -> Checkpoint {
        Library::get_checkpoint_by_index(data_type, checkpoint_index)
    }

    #[view]
    fn get_sources_threshold() -> u32 {
        Library::get_sources_threshold()
    }

    #[view]
    fn get_admin_address() -> ContractAddress {
        Library::get_admin_address()
    }

    #[view]
    fn get_implementation_hash() -> ContractAddress {
        Upgradeable::get_implementation_hash()
    }

    #[view]
    fn get_last_checkpoint_before(
        data_type: DataType, aggregation_mode: AggregationMode, timestamp: u256
    ) -> Checkpoint {
        let idx = Library::find_startpoint(data_type, aggregation_mode, timestamp);
        let checkpoint = Library::get_checkpoint_by_index(data_type, idx);
        checkpoint
    }


    //
    // Setters
    //

    #[external]
    fn publish_data(new_entry: PossibleEntries) {
        Library::publish_data(new_entry);
    }

    #[external]
    fn publish_data_entries(new_entries: Span<PossibleEntries>) {
        let mut cur_idx = 0;
        loop {
            if (cur_idx >= new_entries.len()) {
                break ();
            }
            let new_entry = *new_entries.at(cur_idx);
            Library::publish_data(new_entry);
            cur_idx = cur_idx + 1;
        }
    }


    #[external]
    fn update_publisher_registry_address(new_publisher_registry_addrress: ContractAddress) {
        assert_only_admin();
        Library::update_publisher_registry_address(new_publisher_registry_addrress);
    }

    #[external]
    fn add_currency(new_currency: Currency) {
        assert_only_admin();
        Library::add_currency(new_currency);
    }

    #[external]
    fn update_currency(new_currency: Currency, typeof: felt252) {
        assert_only_admin();
        Library::update_currency(new_currency, typeof);
    }

    #[external]
    fn add_pair(new_pair: Pair) {
        assert_only_admin();
        Library::add_pair(new_pair);
    }

    #[external]
    fn set_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) {
        Library::set_checkpoint(data_type, aggregation_mode);
    }

    #[external]
    fn set_checkpoints(data_types: Span<DataType>, aggregation_mode: AggregationMode) {
        Library::set_checkpoints(data_types, aggregation_mode);
    }

    //
    // Upgrades
    //

    #[external]
    fn upgrade(impl_hash: ClassHash) {
        assert_only_admin();
        Upgradeable::upgrade(impl_hash);
    }

    #[external]
    fn set_admin_address(admin_address: ContractAddress) {
        assert_only_admin();
        Admin::set_admin_address(admin_address);
    }

    #[external]
    fn set_sources_threshold(threshold: u32) {
        assert_only_admin();
        Library::set_sources_threshold(threshold);
    }


    #[internal]
    fn assert_only_admin() {
        let admin = Admin::get_admin_address();
        let caller = get_caller_address();
        assert(caller == admin, 'Admin: unauthorized');
    }
}
