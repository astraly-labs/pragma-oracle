#[contract]
mod Oracle {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use entry::contracts::structs::{
        BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    };
    struct Storage {
        oracle_address_storage: ContractAddress,
        oracle_publisher_registry_address: ContractAddress,
        oracle_pairs_storage: LegacyMap::<felt252, Pair>,
        oracle_currencies_storage: LegacyMap::<felt252, Currency>,
        oracle_sources_storage: LegacyMap::<(felt252, felt252), felt252>,
        oracle_sources_len_storage: LegacyMap::<(felt252, felt252), felt252>,
        oracle_pair_id_storage: LegacyMap::<(felt252, felt252), felt252>,
        oracle_data_storage: LegacyMap::<T>,
        oracle_checkpoints: LegacyMap::<(felt252, felt252), Checkpoint>,
        oracle_checkpoint_index: LegacyMap::<felt252, felt252>,
        oracl_checkpoint_index: LegacyMap::<felt252, felt252>,
    }
    #[event]
    fn UpdatedPublisherRegistryAddress(
        old_publisher_registry_address: ContractAddress,
        new_publisher_registry_address: ContractAddress
    ) {}

    #[event]
    fn SubmittedData(new_data: T) {}

    #[event]
    fn SubmittedCurrency(currency: Currency) {}

    #[event]
    fn UpdatedCurrency(currency: Currency) {}

    #[event]
    fn SubmittedPair(pair: Pair) {}

    #[event]
    fn CheckpointData(pair_id: felt252) {}


    #[constructor]
    fn constructor(
        publisher_registry_address: ContractAddress,
        currencies: @Array<Currency>,
        pairs: @Array<Pair>
    ) {
        oracle_publisher_registry_address::write(publisher_registry_address);
        _set_keys_currencies(currencies_len, currencies, 0);
        _set_keys_pairs(pairs_len, pairs, 0);
    }
    impl OracleImpl of IOracle {
        //
        //Guard
        //
        fn only_oracle_controller() {
            let caller_address = get_caller_address();
            let oracle_controller_address = oracle_address_storage::read();
            if (oracle_controller_address == 0) {
                return ();
            }
            assert(
                caller_address == oracle_controller_address,
                'OracleImplementation: This function can only be called by the oracle controller'
            );
            return ();
        //
        //Getters
        //

        fn get_spot_with_USD_hop()
        }
    }
}

