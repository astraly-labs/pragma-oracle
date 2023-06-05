#[contract]
mod Oracle {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use cmp::{max, min};
    use entry::contracts::entry::{Entry, hasBaseEntry};
    use option::OptionTrait;
    
    use entry::contracts::structs::{
        BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
        USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntries, FutureEntry, OptionEntry, simpleDataType, 
    };
    use oracle::business_logic::oracleInterface::IOracle;
    use publisher_registry::business_logic::interface::IPublisherRegistry;
    struct Storage {

        //oracle controller address storage, contractAddress
        oracle_controller_address_storage: ContractAddress,

        // oracle publisher registry address, ContractAddres
        oracle_publisher_registry_address: ContractAddress,

        //oracle pair storage, legacy map between the pair_id and the pair in question (no need to specify the data type here).
        oracle_pairs_storage: LegacyMap::<felt252,Pair>,

        //oracle_pair_id_storage, legacy Map between (quote_currency_id, base_currency_id) and the pair_id
        oracle_pair_id_storage : LegacyMap::<(felt252, felt252), felt252>,

        //oracle_currencies_storage, legacy Map between (currency_id, (SPOT/FUTURES/OPTIONS)) and the currency
        oracle_currencies_storage: LegacyMap::<(felt252, felt252), Currency>,

        //oralce_sources_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS), index ) and the source
        oracle_sources_storage: LegacyMap::<(felt252, felt252, felt252), felt252>,

        //oracle_sources_len_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS)) and the len of the sources array
        oracle_sources_len_storage: LegacyMap::<(felt252, felt252), felt252>,

        //oracle_data_entry_storage, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), source, expiration_timestamp (0 for SPOT))
        oracle_data_entry_storage: LegacyMap::<(felt252, felt252, felt252, felt252),PossibleEntries>,

        //oracle_checkpoints, legacyMap between, (pair_id, (SPOT/FUTURES/OPTIONS), index, expiration_timestamp (0 for SPOT)) asociated to a checkpoint
        oracle_checkpoints: LegacyMap::<(felt252, felt252, u256, felt252), Checkpoint>,

        //oracle_checkpoint_index, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), expiration_timestamp (0 for SPOT)) and the index of the last checkpoint
        oracle_checkpoint_index: LegacyMap::<(felt252, felt252, felt252), felt252>,
        oracle_sources_threshold_storage: u256,
    }

    trait workingEntry<T> { 
        fn process(self : @T) -> felt252; 
    }
    impl SworkingEntryImpl of workingEntry<SpotEntry> { 
        fn process(self : @SpotEntry) -> felt252 { 
            SPOT
        }
    }
    impl FworkingEntryImpl of workingEntry<FutureEntry> { 
        fn process(self : @FutureEntry) -> felt252 { 
            FUTURE
        }
    }
    impl OworkingEntryImpl of workingEntry<OptionEntry> { 
        fn process(self : @OptionEntry) -> felt252{ 
            OPTION
        }
    }
    

    #[event]
    fn UpdatedPublisherRegistryAddress(
        old_publisher_registry_address: ContractAddress,
        new_publisher_registry_address: ContractAddress
    ) {}

    #[event]
    fn SubmittedData(new_data: PossibleEntries) {}

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
            if (oracle_controller_address.is_zero()) {
                return ();
            }
            assert(
                caller_address == oracle_controller_address,
                'oracle: can only be called by the oracle controller'
            );
            return ();
        }

        //
        //Getters
        //

        // available for futures and spot data types
        fn get_data_with_USD_hop(
            base_currency_id: felt252, quote_currency_id: felt252, aggregation_mode: felt252, typeof :simpleDataType, expiration_timestamp : Option::<u256>
        ) -> PragmaPricesResponse
        {
            let mut sources = ArrayTrait::<felt252>::new();
            let base_pair_id = oracle_pair_id_storage::read((base_currency_id, USD_CURRENCY_ID));
            let quote_pair_id = oracle_pair_id_storage::read((quote_currency_id, USD_CURRENCY_ID));
            let (base_data_type, quote_data_typeof, currency) = match typeof {
                simpleDataType::SpotEntry(()) => {(DataType::SpotEntry(base_pair_id), DataType::SpotEntry(quote_pair_id), oracle_currencies_storage::read((quote_currency_id,SPOT))); },
                simpleDataType::FutureEntry(()) => {   
                    match expiration_timestamp { 
                        Option::Some(expiration)=> {
                        let base_dt  = DataType::FutureEntry((base_pair_id, expiration)); 
                        let quote_dt = DataType::FutureEntry((quote_pair_id, expiration));
                        (base_dt, quote_dt, oracle_currencies_storage::read((quote_currency_id, FUTURE)));
                    },
                        Option::None(_) => {
                        // Handle case where Future data type was provided without an expiration timestamp
                        assert(1==1,'Requires an expiration timestamp');
                            }
                    }
            }
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

            PragmaPricesResponse {
                price: rebased_value, 
                decimals : decimals, 
                last_updated_timestamp : last_updated_timestamp, 
                num_sources_aggregated  : num_sources_aggregated
            } 
            
        }

        fn get_data(data_type: DataType, aggregation_mode: felt252, sources: @Array::<felt252>) -> PragmaPricesResponse {
            let entries = get_data_entries(data_type, sources); 
            if (entries.len() ==0) { 
                return PragmaPricesResponse { 
                    price : 0, 
                    decimals : 0, 
                    last_updated_timestamp : 0, 
                    num_sources_aggregated : 0

                };
            }
            let price = Entry.aggregate_entries(entries, aggregation_mode );
            let decimals = get_decimals( data_type);
            let last_updated_timestamp = Entry.aggregate_timestamp_max(entries); 
            return PragmaPricesResponse {
                price: rebased_value, 
                decimals : decimals, 
                last_updated_timestamp : last_updated_timestamp, 
                num_sources_aggregated  : entries.len()
            };
        }

        fn get_decimals(data_type: DataType, expiration_timestamp:Option::<u256>) -> u32 {
            let currency = match data_type { 
                DataType::SpotEntry(pair_id) => {
                let pair = oracle_pairs_storage::read(pair_id);
                oracle_currencies_storage::read((pair.base_currency_id, SPOT));
                },
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {
                    oracle_pairs_storage::read(pair_id);
                    oracle_currencies_storage::read((pair.base_currency_id, FUTURE));
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
            let conservative_current_timestamp = min(last_updated_timestamp, current_timestamp);
            let entries = get_all_entries(data_type, sources , conservative_current_timestamp);
            return (entries, last_updated_timestamp);

        }

        fn get_entry<T>( data_type : DataType, sources : @Array<felt252>) -> T {
           
           let _entry = match data_type {
           DataType::SpotEntry(pair_id) => {oracle_data_entry_storage::read(pair_id, source, SPOT, 0);},
           DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_data_entry_storage::read(pair_id, source, FUTURE, expiration_timestamp)},
           }
            let timestamp = actual_get_element_at(_entry.timestamp__volume__price, 0, 31);
            let volume = actual_get_element_at(_entry.timestamp__volume__price, 32, 42);
            let price = actual_get_element_at(_entry.timestamp__volume__price, 75, 128);
            let entry = match data_type { 
                DataType ::SpotEntry(pair_id) => 
                    SpotEntry { 
                        base_entry : BaseEntry { 
                            timestamp : timestamp, 
                            source : source, 
                            num_sources_aggregated : 0
                        }, 
                        pair_id : pair_id, 
                        price : price, 
                        volume : volume
                    },
                DataType::FutureEntry((pair_id, expiration_timestamp)) => 
                FutureEntry { 
                    base_entry : BaseEntry { 
                        timestamp : timestamp, 
                        source : source, 
                        num_sources_aggregated : 0
                    }, 
                    pair_id : pair_id, 
                    price : price, 
                    volume : volume, 
                    expiration_timestamp : expiration_timestamp
                },
            }           
           return (entry,);  
            }


        fn get_all_sources(data_type : DataType) -> @Array<felt252> { 
            sources = ArrayTrait::<felt252>::new();
                //TODO
        }

        fn get_latest_checkpoint_index(data_type : DataType) -> u256 {
            let checkpoint_index = match data_type { 
                DataType::SpotEntry(pair_id) => {oracle_checkpoint_index::read((pair_id, SPOT, 0));},
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoint_index::read((pair_id, FUTURE, expiration_timestamp));},
            }
            return checkpoint_index;
        }

        fn get_latest_checkpoint ( data_type : DataType) -> Checkpoint { 
            let cur_idx = get_latest_checkpoint_index(data_type);
            let latest_checkpoint = match data_type { 
                DataType::SpotEntry(pair_id) => {oracle_checkpoints::read((pair_id, SPOT, cur_idx, 0));},
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoints::read((pair_id, FUTURE,cur_idx, expiration_timestamp));},
            }
            return latest_checkpoint;
        }
        

        fn get_checkpoint_by_index(data_type : DataType, checkpoint_index : u256)-> Checkpoint { 
            let checkpoint = match data_type { 
                DataType::SpotEntry(pair_id) => {oracle_checkpoints::read((pair_id, SPOT, checkpoint_index,0));},
                DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoints::read((pair_id, FUTURE,checkpoint_index, expiration_timestamp));},
            }
            return checkpoint;
        }
        

        fn validate_sender_for_source<T, impl THasBaseEntry: hasBaseEntry<T>>(_entry : T ) { 
            let publisher_registry_address = get_publisher_registry_address();
            let publisher_address = IPublisherRegistry::get_publisher_address(publisher_registry_address,_entry.base.source );
            let _can_publish_source = IPublisherRegistry::can_publish_source( publisher_registry_address, _entry.base.publisher, _entry.base.source);
            let caller_address = get_caller_address( );
            assert(publisher_address!=0, 'Oracle: Publisher is not registered'); 
            assert(!caller_address.is_zero() , 'Oracle: Caller must not be a zero address'); 
            assert (caller_address == publisher_address, 'Oracle: Transaction not from the publisher account');
            assert (_can_publish_source==true, 'Oracle: Publisher is not authorized for this source');
            return (); 

        }

        fn validate_data_timestamp<T, impl THasBaseEntry : hasBaseEntry<T>>(new_entry :T , last_entry : T, typeof: simpleDataType)  { 
            assert(new_entry.base.timestamp > last_entry.base.timestamp, 'Oracle: Existing entry is more recent');
            if (last_entry.base.timestamp ==0) { 
                match typeof { 
                    simpleDataType::SpotEntry(())=> {
                        let sources_len = oracle_sources_len_storage::read(new_entry.pair_id,SPOT);
                        oracle_sources_storage::write(new_entry.pair_id, SPOT, sources_len, new_entry.base.source );
                        oracle_sources_len_storage::write(new_entry.pair_id, SPOT, sources_len +1 );
                    }
                    simpleDataType::FutureEntry(())=> {
                        let sources_len = oracle_sources_len_storage::read(new_entry.pair_id,FUTURE, new_entry.expiration_timestamp);
                        oracle_sources_storage::write()
                    }
                }
            }
            else {
                return();
            }
        }

    
    //     fn publish_data<T>(new_data : T) { 
            

    //     }

        // fn build_data_entry_array{

        // }
        }
        

    } 


