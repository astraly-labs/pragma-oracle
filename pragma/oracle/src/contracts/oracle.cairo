#[contract]
mod Oracle {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use cmp::{max, min};
    use entry::contracts::entry::{Entry, hasBaseEntry};
    
    use entry::contracts::structs::{
        BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
        USD_CURRENCY_ID, SPOT, FUTURE
    };
    use oracle::business_logic::oracleInterface::IOracle;
    use publisher_registry::business_logic::interface::IPublisherRegistry;
    struct Storage {

        //oracle controller address storage
        oracle_controller_address_storage: ContractAddress,

        // oracle publisher registry address
        oracle_publisher_registry_address: ContractAddress,

        //oracle pair storage, inside the data type, we have the informations of spot, futures...

        oracle_pairs_storage: LegacyMap::<felt252,Pair>,
        oracle_pair_id_storage : LegacyMap::<(felt252, felt252), felt252>,
        oracle_currencies_storage: LegacyMap::<(felt252, felt252), Currency>,
        oracle_sources_storage: LegacyMap::<(felt252, felt252, felt252), felt252>,

        oracle_sources_len_storage: LegacyMap::<(felt252, felt252), felt252>,
        oracle_data_storage: LegacyMap::<(felt252, felt252, felt252, Option::<felt252>),T>,
        oracle_checkpoints: LegacyMap::<(felt252, felt252, u256, Option::<felt252>), Checkpoint>,
        oracle_checkpoint_index: LegacyMap::<(felt252, felt252, Option::<felt252>), felt252>,
        oracle_sources_threshold_storage: u256,
    }

    enum simpleDataType { 
        SpotEntry: (), 
        FutureEntry: (), 
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
            let oracle_controller_address = oracle_controller_address_storage::read();
            if (oracle_controller_address == 0) {
                return ();
            }
            assert(
                caller_address == oracle_controller_address,
                'OracleImplementation: This function can only be called by the oracle controller'
            );
            return ();
        }

        //
        //Getters
        //

        // available for futures and spot data types
        fn get_data_with_USD_hop(
            base_currency_id: felt252, quote_currency_id: felt252, aggregation_mode: felt252, typeof :simpleDataType
        ) -> PragmaPricesResponse
        {
            let mut sources = ArrayTrait::new();
            let base_pair_id = oracle_pair_id_storage::read(base_currency_id, USD_CURRENCY_ID);
            let quote_pair_id = oracle_pair_id_storage::read(quote_currency_id, USD_CURRENCY_ID);
            let (base_data_type, quote_data_typeof, currency) = match data_type {
                simpleDataType::SpotEntry => {(DataType::SpotEntry(base_pair_id), DataType::SpotEntry(quote_pair_id), oracle_currencies_storage::read(quote_currency_id,SPOT)); },
                simpleDataType::FutureEntry => {
                    if let Some(expiration) = expiration_timestamp {
                        (DataType::FutureEntry((base_pair_id, expiration)), DataType::FutureEntry((quote_pair_id, expiration)), oracle_currencies_storage::read(quote_currency_id, FUTURE));
                    } else {
                        // Handle case where Future or Option data type was provided without an expiration timestamp
                        panic!('Future or Option data type requires an expiration timestamp');
                    },
            };
            let (base_value, _, base_last_updated_timestamp, base_num_sources_aggregated) = get_data(
                base_data_type, aggregation_mode, sources
            );
            let (quote_value, _, quote_last_updated_timestamp, quote_num_sources_aggregated) = get_data(
                quote_data_type, aggregation_mode, sources
            );
            let decimals = currency.decimals;
            let rebased_value = convert_via_usd(base_value, quote_value, decimals);
            let last_updated_timestamp = max(
                quote_last_updated_timestamp, base_last_updated_timestamp
            );
            let num_sources_aggregated = max(
                quote_num_sources_aggregated, base_num_sources_aggregated
            );

            PragmaPricesResponse::new(
                rebased_value, decimals, last_updated_timestamp, num_sources_aggregated
            )
        }

        fn get_data(data_type: DataType, aggregation_mode: felt252, sources: @Array::<felt252>) -> PragmaPricesResponse {
            let entries = get_data_entries(data_type, sources); 
            if (entries.len() ==0) { 
                return PragmaPricesResponse::new(0, 0, 0, 0);
            }
            let price = Entry.aggregate_entries(entries, aggregation_mode );
            let decimals = get_decimals( data_type);
            let last_updated_timestamp = Entry.aggregate_timestamp_max(entries); 
            return PragmaPricesResponse::new(price, decimals, last_updated_timestamp, entries.len());
        }

        fn get_decimals(data_type: DataType, expiration_timestamp:Option::<u256>) -> u32 {
            let currency = match data_type { 
                DataType::SpotEntry(pair_id) => {
                let pair = oracle_pairs_storage::read(pair_id);
                oracle_currencies_storage::read(pair.base_currency_id, SPOT);
                },
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {
                    oracle_pairs_storage::read(pair_id);
                    oracle_currencies_storage::read(pair.base_currency_id, FUTURE);
                 },

            }
            currency.decimals
        }

        fn get_publisher_registry_address() -> ContractAddress {
            let publisher_registry_address = oracle_publisher_registry_address_storage::read();
            return publisher_registry_address;
    }

        fn get_entries<T>(data_type : DataType,sources : @Array<felt252> ) -> (Array::<T>, u256) { 
            let last_updated_timestamp = get_last_entry_timestamp(data_type, sources);
            let current_timestamp = get_block_timestamp();
            let (conservative_current_timestamp) = min(last_updated_timestamp, current_timestamp);
            let entries = get_all_entries(data_type, sources , conservative_current_timestamp);
            return (entries, last_updated_timestamp);

        }

        fn get_entry<T>( data_type : DataType, sources : @Array<felt252>) -> T {
           
           let _entry = match data_type {
           DataType::SpotEntry(pair_id) => {oracle_data_storage::read(pair_id, source, SPOT);},
           DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_data_storage::read(pair_id, source, FUTURE, expiration_timestamp)},
           }
            let timestamp = actual_get_element_at(_entry.timestamp__volume__price, 0, 31);
            let volume = actual_get_element_at(_entry.timestamp__volume__price, 32, 42);
            let price = actual_get_element_at(_entry.timestamp__volume__price, 75, 128);
            let entry = match data_type { 
                DataType ::SpotEntry(pair_id) => {SpotEntry::new(BaseEntry::new(timestamp, source, 0), pair_id, price, volume);},
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {FutureEntry::new(BaseEntry::new(timestamp, source, 0), pair_id, price, volume, expiration_timestamp);},
            }
           return (entry,);  
            }


        fn get_all_sources(data_type : DataType) -> @Array<felt252> { 
            sources = ArrayTrait::new();
                //TODO
        }

        fn get_latest_checkpoint_index(data_type : DataType) -> u256 {
            let checkpoint_index = match data_type { 
                DataType::SpotEntry(pair_id) => {oracle_checkpoint_index_storage::read(pair_id, SPOT);},
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoint_index_storage::read(pair_id, FUTURE, expiration_timestamp);},
            }
            return checkpoint_index;
        }

        fn get_latest_checkpoint ( data_type : DataType) -> Checkpoint { 
            let cur_idx = get_latest_checkpoint_index(data_type);
            let latest_checkpoint = match data_type { 
                DataType::SpotEntry(pair_id) => {oracle_checkpoints::read(pair_id, SPOT, cur_idx);},
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoints::read(pair_id, FUTURE,cur_idx, expiration_timestamp);},
            }
            return latest_checkpoint;
        }
        

        fn get_checkpoint_by_index(data_type : DataType, checkpoint_index : u256)-> Checkpoint { 
            let checkpoint = match data_type { 
                DataType::SpotEntry(pair_id) => {oracle_checkpoints::read(pair_id, SPOT, checkpoint_index);},
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoints::read(pair_id, FUTURE,checkpoint_index, expiration_timestamp);},
            }
            return checkpoint;
        }
        

        fn validate_sender_for_source<T, impl THasBaseEntry: hasBaseEntry<T>>(_entry : T ) { 
            let publisher_registry_address = get_publisher_registry_address();
            let publisher_address = IPublisherRegistry::get_publisher_address(publisher_registry_address,_entry.base.source );
            let _can_publish_source = IPublisherRegistry::can_publish_source ( publisher_registry_address, _entry.base.publisher, _entry.base.source);
            let caller_address = get_caller_address( );
            assert(publisher_address!=0, 'Oracle: Publisher is not registered'); 
            assert(caller_address != 0 , 'Oracle: Caller must not be a zero address'); 
            asset (caller_address == publisher_address, 'Oracle: Transaction not from the publisher account');
            asset (_can_publish_source==true, 'Oracle: Publisher is not authorized for this source');
            return (); 

        }
        fn publish_data<T>(new_data : T) { 


        }

        }
        

    } 
}


