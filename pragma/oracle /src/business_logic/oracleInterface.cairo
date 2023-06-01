use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse
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
    fn get_decimals(pair_id: felt252, data_type: DataType) -> felt252;
    fn get_data_median(pair_id: felt252, data_type: DataType) -> felt252;
    fn get_data_median_for_sources(
        pair_id: felt252, data_type: DataType, sources: @Array<felt252>
    ) -> felt252;
    fn get_data(
        pair_id: felt252, expiration_timestamp: Option::<u256>, data_type: DataType
    ) -> PragmaPricesResponse;
    fn get_data_for_sources(
        pair_id: felt252,
        expiration_timestamp: Option::<u256>,
        data_type: DataType,
        sources: @Array<felt252>
    ) -> Array<PragmaPricesResponse>;
    //For all the sources
    fn get_data_entries(
        pair_id: felt252, expiration_timestamp: Option::<u256>, data_type: DataType
    ) -> Array<PragmaPricesResponse>;
    fn get_last_checkpoint_before(timestamp: u256m, data_type: DataType) -> (Checkpoint, u256);
}
