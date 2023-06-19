use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    simpleDataType, AggregationMode, PossibleEntries
};
use array::ArrayTrait;
use starknet::ContractAddress;

#[interface]
trait IOracle {
    fn initializer(
        proxy_admin: felt252,
        publisher_registry_address: ContractAddress,
        currencies: @Array<Currency>,
        pairs: @Array<Pair>
    );
    //
    // Getters
    //
    fn get_decimals(data_type: DataType) -> u32;
    fn get_data_median(data_type: DataType) -> u256;
    fn get_data_median_for_sources(data_type: DataType, sources: @Array<felt252>) -> felt252;
    fn get_data(
        data_type: DataType, aggregation_mode: AggregationMode, sources: @Array<felt252>
    ) -> PragmaPricesResponse;
    fn get_data_entry(data_type: DataType, source: felt252) -> PossibleEntries;
    fn get_data_for_sources(
        data_type: DataType, aggregation_mode: AggregationMode
    ) -> Array<PragmaPricesResponse>;
    fn get_data_entries(
        data_type: DataType, sources: @Array<felt252>
    ) -> (Array<PossibleEntries>, u32, u256);
    fn get_last_checkpoint_before(timestamp: u256, data_type: DataType) -> (Checkpoint, u256);
    fn get_data_with_USD_hop(
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: AggregationMode,
        typeof: simpleDataType,
        expiration_timestamp: Option::<u256>
    ) -> PragmaPricesResponse;
    fn get_publisher_registry_address() -> ContractAddress;
    fn get_latest_checkpoint_index(data_type: DataType, aggregation_mode: AggregationMode) -> u256;
    fn get_latest_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) -> Checkpoint;
    fn get_checkpoint(data_type: DataType, index: felt252) -> Checkpoint;
    fn get_sources_threshold() -> u32;
    fn get_admin_address() -> ContractAddress;

    //
    // Setters
    //

    fn publish_data(new_entry: PossibleEntries);
    fn publish_data_entries<T>(data: @Array<T>);
    fn set_admin_address(new_admin_address: ContractAddress);
    fn update_publisher_registry_address(new_publisher_registry_address: ContractAddress);
    fn add_currency(currency: Currency);
    fn update_currency(currency: Currency, typeof: felt252);
    fn add_pair(pair: Pair);
    fn set_checkpoint(data_type: DataType, aggregation_mode: AggregationMode);
    fn set_checkpoints(data_types: Array<DataType>, aggregation_mode: AggregationMode);
    fn set_sources_threshold(threshold: u32);
}
