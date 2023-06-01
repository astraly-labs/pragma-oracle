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
}
