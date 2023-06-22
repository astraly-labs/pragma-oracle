use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    simpleDataType, AggregationMode, PossibleEntries
};
use array::{ArrayTrait, SpanTrait};
use starknet::{ContractAddress, ClassHash};

#[derive(Serde, Drop)]
struct Call {
    to: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>
}

trait IOracle {
    fn initializer(
        proxy_admin: felt252,
        publisher_registry_address: ContractAddress,
        currencies: Span<Currency>,
        pairs: Span<Pair>
    );
    fn get_decimals(data_type: DataType) -> u32;
    fn get_data_median(data_type: DataType) -> PragmaPricesResponse;
    fn get_data_median_for_sources(
        data_type: DataType, sources: Span<felt252>
    ) -> PragmaPricesResponse;
    fn get_data(data_type: DataType, aggregation_mode: AggregationMode) -> PragmaPricesResponse;
    fn get_data_median_multi(
        data_types: Span<DataType>, sources: Span<felt252>
    ) -> Array<PragmaPricesResponse>;
    fn get_data_entry(data_type: DataType, source: felt252) -> PossibleEntries;
    fn get_data_for_sources(
        data_type: DataType, aggregation_mode: AggregationMode, sources: Span<felt252>
    ) -> PragmaPricesResponse;
    fn get_data_entries(data_type: DataType) -> Array<PossibleEntries>;
    fn get_data_entries_for_sources(
        data_type: DataType, sources: Span<felt252>
    ) -> Array<PossibleEntries>;
    fn get_last_checkpoint_before(
        data_type: DataType, aggregation_mode: AggregationMode, timestamp: u64
    ) -> (Checkpoint, u64);
    fn get_data_with_USD_hop(
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: AggregationMode,
        typeof: simpleDataType,
        expiration_timestamp: Option::<u64>
    ) -> PragmaPricesResponse;
    fn get_publisher_registry_address() -> ContractAddress;
    fn get_latest_checkpoint_index(data_type: DataType, aggregation_mode: AggregationMode) -> u64;
    fn get_latest_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) -> Checkpoint;
    fn get_checkpoint(data_type: DataType, checkpoint_index: u64) -> Checkpoint;
    fn get_sources_threshold() -> u32;
    fn get_admin_address() -> ContractAddress;
    fn get_implementation_hash() -> ClassHash;
    fn publish_data(new_entry: PossibleEntries);
    fn publish_data_entries(new_entries: Span<PossibleEntries>, );
    fn set_admin_address(new_admin_address: ContractAddress);
    fn update_publisher_registry_address(new_publisher_registry_address: ContractAddress);
    fn add_currency(new_currency: Currency);
    fn update_currency(currency: Currency, typeof: felt252);
    fn add_pair(new_pair: Pair);
    fn set_checkpoint(data_type: DataType, aggregation_mode: AggregationMode);
    fn set_checkpoints(data_types: Span<DataType>, aggregation_mode: AggregationMode);
    fn set_sources_threshold(threshold: u32);
}

