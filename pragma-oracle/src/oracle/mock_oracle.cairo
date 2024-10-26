use pragma::entry::structs::{DataType, PragmaPricesResponse};

#[starknet::interface]
trait IOracle<TContractState> {
    fn get_data_median(self: @TContractState, data_type: DataType) -> PragmaPricesResponse;
}

#[starknet::contract]
mod MockOracle {
    use starknet::{get_block_timestamp};
    use super::{IOracle, PragmaPricesResponse, DataType};
    use option::OptionTrait;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {
        return ();
    }

    #[external(v0)]
    impl IOracleImpl of IOracle<ContractState> {
        /// @notice Returns a fixed mocked price of 1000 USD
        fn get_data_median(self: @ContractState, data_type: DataType) -> PragmaPricesResponse {
            let timestamp = get_block_timestamp();
            PragmaPricesResponse {
                price: 100000000000,
                decimals: 8,
                last_updated_timestamp: timestamp,
                num_sources_aggregated: 5,
                expiration_timestamp: Option::None,
            }
        }
    }
}

