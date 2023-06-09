use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint, simpleDataType
};
use array::ArrayTrait;
use starknet::ContractAddress;


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
        data_type: DataType, aggregation_mode: felt252, sources: @Array<felt252>
    ) -> PragmaPricesResponse;
    fn get_data_entry<T>(source: felt252, data_type: DataType) -> T;
    fn get_data_for_sources(
        data_type: DataType, aggregation_mode: felt252
    ) -> Array<PragmaPricesResponse>;
    fn get_data_entries(
        data_type: DataType, sources: @Array<felt252>
    ) -> Array<PragmaPricesResponse>;
    fn get_last_checkpoint_before(timestamp: u256, data_type: DataType) -> (Checkpoint, u256);
    fn get_data_with_USD_hop(
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: felt252,
        typeof: simpleDataType,
        expiration_timestamp: Option::<u256>
    ) -> PragmaPricesResponse;
    fn get_publisher_registry_address() -> ContractAddress;
    fn get_latest_checkpoint_index(key: felt252) -> u256;
    fn get_checkpoints(data_type: DataType, index: felt252) -> Checkpoint;
    fn get_sources_threshold() -> u32;

    //
    // Setters
    //

    fn publish_data_entry<T>(data: T);
    fn publish_data_entries<T>(data: @Array<T>);
    fn set_admin_address(new_admin_address: ContractAddress);
    fn update_publisher_registry_address(new_publisher_registry_address: ContractAddress);
    fn add_currency(currency: Currency);
    fn update_currency(currency: Currency, typeof: felt252);
    fn add_pair(pair: Pair);
    fn set_checkpoint(data_type: DataType, aggregation_mode: felt252);
    fn set_sources_threshold(threshold: u32);
}
