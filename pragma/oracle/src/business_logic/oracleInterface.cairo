use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
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
    fn get_decimals(data_type: DataType, expiration_timestamp: Option::<felt252>) -> felt252;
    fn get_data_median(data_type: DataType, expiration_timestamp: Option::<felt252>) -> felt252;
    fn get_data_median_for_sources(
        data_type: DataType, sources: @Array<felt252>, expiration_timestamp: Option::<felt252>
    ) -> felt252;
    fn get_data(
        expiration_timestamp: Option::<felt252>, data_type: DataType, aggregation_mode: felt252
    ) -> PragmaPricesResponse;
    fn get_data_entry<T>(
        source: felt252, data_type: DataType, expiration_timestamp: Option::<felt252>, 
    ) -> T;
    fn get_data_for_sources(
        expiration_timestamp: Option::<felt252>, data_type: DataType, aggregation_mode: felt252
    ) -> Array<PragmaPricesResponse>;
    fn get_data_entries(
        expiration_timestamp: Option::<felt252>, data_type: DataType, sources: @Array<felt252>
    ) -> Array<PragmaPricesResponse>;
    fn get_last_checkpoint_before(timestamp: felt252, data_type: DataType) -> (Checkpoint, felt252);
    fn get_data_with_USD_hop(
        base_currency_id: felt252, quote_currency_id: felt252, aggregation_mode: felt252
    ) -> PragmaPricesResponse;
    fn get_admin_address() -> ContractAddress;
    fn get_publisher_registry_address() -> ContractAddress;
    fn get_latest_checkpoint_index(key: felt252) -> felt252;
    fn get_checkpoint(key: felt252, index: felt252) -> Checkpoint;
    fn get_sources_threshold() -> felt252;

    //
    // Setters
    //

    fn publish_data_entry<T>(data: T);
    fn publish_data_entries<T>(data: @Array<T>);
    fn set_admin_address(new_admin_address: ContractAddress);
    fn update_publisher_registry_address(new_publisher_registry_address: ContractAddress);
    fn add_currency(currency: Currency);
    fn update_currency(currency: Currency);
    fn add_pair(pair: Pair);
    fn set_checkpoint(paid_id: felt252, aggregation_mode: felt252);
    fn set_sources_threshold(threshold: felt252);
}
