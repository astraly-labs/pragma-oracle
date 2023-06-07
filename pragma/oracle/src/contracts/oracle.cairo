#[contract]
mod Oracle {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use cmp::{max, min};
    use entry::contracts::entry::Entry;
    use option::OptionTrait;
    use array::ArrayTrait;
    use traits::Into;
    use traits::TryInto;
    use entry::contracts::structs::{
        BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
        USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntries, FutureEntry, OptionEntry, simpleDataType, entryDataType
    };
    use oracle::business_logic::oracleInterface::IOracle;
    use pragma::publisher_registry::business_logic::interface::IPublisherRegistry;
    use pragma::bits_manipulation::bits_manipulation::{actual_set_element_at, actual_get_element_at}; 
    use pragma::time_series::convert::convert_via_usd;
    use admin::contracts::Admin::Admin;
    use serde::Serde;
    use serde::deserialize_array_helper; 
    use serde::serialize_array_helper;
    use starknet::{SyscallResult, storage_access::{StorageAccess, StorageBaseAddress, storage_address_from_base_and_offset, storage_write_syscall, storage_read_syscall}};

    //Structure
    
    struct Storage {


        //oracle controller address storage, contractAddress
        oracle_controller_address_storage: ContractAddress,

        // oracle publisher registry address, ContractAddres
        oracle_publisher_registry_address_storage: ContractAddress,

        //oracle pair storage, legacy map between the pair_id and the pair in question (no need to specify the data type here).
        oracle_pairs_storage: LegacyMap::<felt252,Pair>,

        //oracle_pair_id_storage, legacy Map between (quote_currency_id, base_currency_id) and the pair_id
        oracle_pair_id_storage : LegacyMap::<(felt252, felt252), felt252>,

        //oracle_currencies_storage, legacy Map between (currency_id) and the currency
        oracle_currencies_storage: LegacyMap::<felt252, Currency>,

        //oralce_sources_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS), index, expiration_timestamp ) and the source
        oracle_sources_storage: LegacyMap::<(felt252, felt252, usize, u256), felt252>,

        //oracle_sources_len_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS), expiration_timestamp) and the len of the sources array
        oracle_sources_len_storage: LegacyMap::<(felt252, felt252, u256), u256>,

        //oracle_data_entry_storage, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), source, expiration_timestamp (0 for SPOT))
        oracle_data_entry_storage: LegacyMap::<(felt252, felt252, felt252, u256),PossibleEntries>,

        //oracle_checkpoints, legacyMap between, (pair_id, (SPOT/FUTURES/OPTIONS), index, expiration_timestamp (0 for SPOT)) asociated to a checkpoint
        oracle_checkpoints: LegacyMap::<(felt252, felt252, usize, u256), Checkpoint>,

        //oracle_checkpoint_index, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), expiration_timestamp (0 for SPOT)) and the index of the last checkpoint
        oracle_checkpoint_index: LegacyMap::<(felt252, felt252, u256), usize>,
        oracle_sources_threshold_storage: u32,
    }

    trait workingEntry<T> { 
        fn process(self : @T) -> felt252;
    }
    impl SworkingEntryImpl of workingEntry<SpotEntry> { 
        fn process(self : @SpotEntry) -> felt252 { 
            return(SPOT);
        }
    }
    impl FworkingEntryImpl of workingEntry<FutureEntry> { 
        fn process(self : @FutureEntry) -> felt252 { 
            return (FUTURE);
        }
    }
    impl OworkingEntryImpl of workingEntry<OptionEntry> { 
        fn process(self : @OptionEntry) -> felt252{ 
            return (OPTION);
        }
    }

    trait hasBaseEntry<T> {
        fn get_base_entry(self: @T) -> BaseEntry;
        fn get_base_timestamp(self: @T) -> u256;
    }

    impl hasBaseEntryImpl of hasBaseEntry<SpotEntry> {
        fn get_base_entry(self: @SpotEntry) -> BaseEntry {
            (*self).base
        }
        fn get_base_timestamp(self: @SpotEntry) -> u256 {
            (*self).base.timestamp
        }
    }

    trait hasPrice<T> {
        fn get_price(self: @T) -> u256;
    }

    impl hasPriceImpl of hasPrice<SpotEntry> {
        fn get_price(self: @SpotEntry) -> u256 {
            (*self).price
        }
    }

    impl PairStorageAccess of StorageAccess<Pair> {
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Pair> {
            Result::Ok(
                Pair { 
                    id : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 0_u8)
                    )?,
                    quote_currency_id : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 1_u8)
                    )?,
                    base_currency_id : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 2_u8)
                    )?
                }
            )
        }
        #[inline(always)]
        fn write(
            address_domain: u32, base: StorageBaseAddress, value: Pair
        ) -> SyscallResult<()> {
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 0_u8), value.id,
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 1_u8), value.quote_currency_id,
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 2_u8), value.base_currency_id,
            )?;
        }
    }
    
    impl CheckpointStorageAccess of StorageAccess<Checkpoint> { 
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Checkpoint> {
            Result::Ok(
                Checkpoint { 
                    timestamp : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 0_u8)
                    )?.try_into().unwrap(),
                    value : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 1_u8)
                    )?.try_into().unwrap(),
                    aggregation_mode : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 2_u8)
                    )?.try_into().unwrap(),
                    num_sources_aggregated : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 3_u8)
                    )?.try_into().unwrap(),
                }
            )
        }
        #[inline(always)]
        fn write(
            address_domain: u32, base: StorageBaseAddress, value: Checkpoint
        ) -> SyscallResult<()> {
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 0_u8), value.timestamp.into(),
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 1_u8), value.value.into(),
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 2_u8), value.aggregation_mode.into(),
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 3_u8), value.num_sources_aggregated.into(),
            )?;
        }
    }

    impl CurrencyStorageAccess of StorageAccess<Currency> { 
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Currency> {
            Result::Ok(
                Checkpoint { 
                    id : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 0_u8)
                    )?,
                    decimals : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 1_u8)
                    )?.try_into().unwrap(),
                    is_abstract_currency : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 2_u8)
                    )?,
                    starknet_address : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 3_u8)
                    )?.try_into().unwrap(),
                    ethereum_address : storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 4_u8)
                    )?.try_into().unwrap(),
                }
            )
        }
        #[inline(always)]
        fn write(
            address_domain: u32, base: StorageBaseAddress, value: Currency
        ) -> SyscallResult<()> {
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 0_u8), value.id,
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 1_u8), value.decimals.into(),
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 2_u8), value.is_abstract_currency.into(),
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 3_u8), value.starknet_address.into(),
            )?;
            storage_write_syscall(
                address_domain, storage_address_from_base_and_offset(base, 4_u8), value.ethereum_address.into(),
            )?;
        }
    }
    // impl PossibleEntriesStorageAccess of StorageAccess<PossibleEntries> { 
    //     fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<PossibleEntries> {
    //         Result::Ok(
    //             PossibleEntries { 
    //                 Spot : storage_read_syscall(
    //                     address_domain, storage_address_from_base_and_offset(base, 0_u8)
    //                 )?,
    //                 decimals : storage_read_syscall(
    //                     address_domain, storage_address_from_base_and_offset(base, 1_u8)
    //                 )?.try_into().unwrap(),
    //                 is_abstract_currency : storage_read_syscall(
    //                     address_domain, storage_address_from_base_and_offset(base, 2_u8)
    //                 )?,
    //                 starknet_address : storage_read_syscall(
    //                     address_domain, storage_address_from_base_and_offset(base, 3_u8)
    //                 )?.try_into().unwrap(),
    //                 ethereum_address : storage_read_syscall(
    //                     address_domain, storage_address_from_base_and_offset(base, 4_u8)
    //                 )?.try_into().unwrap(),
    //             }
    //         )
    //     }
    //     #[inline(always)]
    //     fn write(
    //         address_domain: u32, base: StorageBaseAddress, value: Currency
    //     ) -> SyscallResult<()> {
    //         storage_write_syscall(
    //             address_domain, storage_address_from_base_and_offset(base, 0_u8), value.id,
    //         )?;
    //         storage_write_syscall(
    //             address_domain, storage_address_from_base_and_offset(base, 1_u8), value.decimals.into(),
    //         )?;
    //         storage_write_syscall(
    //             address_domain, storage_address_from_base_and_offset(base, 2_u8), value.is_abstract_currency.into(),
    //         )?;
    //         storage_write_syscall(
    //             address_domain, storage_address_from_base_and_offset(base, 3_u8), value.starknet_address.into(),
    //         )?;
    //         storage_write_syscall(
    //             address_domain, storage_address_from_base_and_offset(base, 4_u8), value.ethereum_address.into(),
    //         )?;
    //     }
    // }

    

    #[event]
    fn UpdatedPublisherRegistryAddress(
        old_publisher_registry_address: ContractAddress,
        new_publisher_registry_address: ContractAddress
    ) {}

    #[event]
    fn SubmittedSpotEntry(spot_entry: SpotEntry) {}

    #[event]
    fn SubmittedFutureEntry(future_entry: FutureEntry) {}

    #[event]
    fn SubmittedOptionEntry(option_entry: OptionEntry) {}

    #[event]
    fn SubmittedCurrency(currency: Currency) {}

    #[event]
    fn UpdatedCurrency(currency: Currency) {}

    #[event]
    fn SubmittedPair(pair: Pair) {}

    #[event]
    fn CheckpointSpotEntry(pair_id: felt252) {}

    #[event]
    fn CheckpointFutureEntry(pair_id: felt252, expiration_timestamp : u256) {}


    #[constructor]
    fn constructor(
        publisher_registry_address: ContractAddress,
        currencies: @Array<Currency>,
        pairs: @Array<Pair>
    ) {
        oracle_publisher_registry_address_storage::write(publisher_registry_address);
        _set_keys_currencies(currencies_len, currencies, 0);
        _set_keys_pairs(pairs_len, pairs, 0);
    }
    impl OracleImpl of IOracle {
        

        //
        //Getters
        //

        // fn get_decimals(data_type: DataType, expiration_timestamp:Option::<u256>) -> u32 {
        //             let currency = match data_type { 
        //                 DataType::SpotEntry(pair_id) => {
        //                 let pair = oracle_pairs_storage::read(pair_id);
        //                 oracle_currencies_storage::read(pair.base_currency_id);
        //                 },
        //                 DataType::FutureEntry((pair_id, expiration_timestamp)) => {
        //                     oracle_pairs_storage::read(pair_id);
        //                     oracle_currencies_storage::read(pair.base_currency_id);
        //                 },

        //             }
        //             currency.decimals
        //         }

        

    //     // available for futures and spot data types
    //     fn get_data_with_USD_hop(
    //         base_currency_id: felt252, quote_currency_id: felt252, aggregation_mode: felt252, typeof :simpleDataType, expiration_timestamp : Option<u256>
    //     ) -> PragmaPricesResponse
    //     {
    //         let mut sources = ArrayTrait::<felt252>::new();
    //         let base_pair_id = oracle_pair_id_storage::read((base_currency_id, USD_CURRENCY_ID));
    //         let quote_pair_id = oracle_pair_id_storage::read((quote_currency_id, USD_CURRENCY_ID));
    //         let (base_data_type, quote_data_typeof, currency) = match typeof {
    //             simpleDataType::SpotEntry(()) => {(DataType::SpotEntry(base_pair_id), DataType::SpotEntry(quote_pair_id), oracle_currencies_storage::read(quote_currency_id)); },
    //             simpleDataType::FutureEntry(()) => {   
    //                 match expiration_timestamp { 
    //                     Option::Some(expiration)=> {
    //                     let base_dt  = DataType::FutureEntry((base_pair_id, expiration)); 
    //                     let quote_dt = DataType::FutureEntry((quote_pair_id, expiration));
    //                     (base_dt, quote_dt, oracle_currencies_storage::read(quote_currency_id));
    //                 },
    //                     Option::None(_) => {
    //                     // Handle case where Future data type was provided without an expiration timestamp
    //                     assert(1==1,'Requires an expiration timestamp');
    //                         }
    //                 }
    //         },
    //         };
    //         let (base_value, _, base_last_updated_timestamp, base_num_sources_aggregated) = get_data(
    //             base_data_type, aggregation_mode, sources
    //         );
    //         let (quote_value, _, quote_last_updated_timestamp, quote_num_sources_aggregated) = get_data(
    //             quote_data_type, aggregation_mode, sources
    //         );
    //         let decimals = currency.decimals;
    //         let rebased_value = convert_via_usd(base_value, quote_value, decimals);
    //         let last_updated_timestamp = max(
    //             quote_last_updated_timestamp, base_last_updated_timestamp
    //         );
    //         let num_sources_aggregated = max(
    //             quote_num_sources_aggregated, base_num_sources_aggregated
    //         );

    //         PragmaPricesResponse {
    //             price: rebased_value, 
    //             decimals : decimals, 
    //             last_updated_timestamp : last_updated_timestamp, 
    //             num_sources_aggregated  : num_sources_aggregated
    //         } 
            
    //     }



    //     fn get_data(data_type: DataType, aggregation_mode: felt252, sources: @Array<felt252>) -> PragmaPricesResponse {
    //         let entries = get_data_entries(data_type, sources); 
    //         if (entries.len().is_zero()) { 
    //             return PragmaPricesResponse { 
    //                 price : 0, 
    //                 decimals : 0, 
    //                 last_updated_timestamp : 0, 
    //                 num_sources_aggregated : 0,

    //             };
    //         }
    //         let price = Entry.aggregate_entries(entries, aggregation_mode );
    //         let decimals = get_decimals( data_type);
    //         let last_updated_timestamp = Entry.aggregate_timestamp_max(entries); 
    //         return PragmaPricesResponse {
    //             price: rebased_value, 
    //             decimals : decimals, 
    //             last_updated_timestamp : last_updated_timestamp, 
    //             num_sources_aggregated  : entries.len()
    //         };
    //     }

    
     


    //     fn get_data_entries<T>(data_type : DataType,sources : @Array<felt252> ) -> (@Array<T>, u256) { 
    //         let last_updated_timestamp = get_latest_entry_timestamp(data_type, sources);
    //         let current_timestamp = get_block_timestamp();
    //         let conservative_current_timestamp = min(last_updated_timestamp, current_timestamp);
    //         let entries = get_all_entries(data_type, sources , conservative_current_timestamp);
    //         return (entries, last_updated_timestamp);

    //     }

    //     fn get_data_entry<T>(data_type : DataType, sources : felt252) -> T {
           
    //        let _entry = match data_type {
    //        DataType::SpotEntry(pair_id) => {oracle_data_entry_storage::read(pair_id, source, SPOT, 0);},
    //        DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_data_entry_storage::read(pair_id, source, FUTURE, expiration_timestamp)},
    //        }
    //         let timestamp = actual_get_element_at(_entry.timestamp__volume__price, 0, 31);
    //         let volume = actual_get_element_at(_entry.timestamp__volume__price, 32, 42);
    //         let price = actual_get_element_at(_entry.timestamp__volume__price, 75, 128);
    //         let entry = match data_type { 
    //             DataType ::SpotEntry(pair_id) => 
    //             {
    //                 return SpotEntry { 
    //                     base_entry : BaseEntry { 
    //                         timestamp : timestamp, 
    //                         source : source, 
    //                         num_sources_aggregated : 0
    //                     }, 
    //                     pair_id : pair_id, 
    //                     price : price, 
    //                     volume : volume
    //                 };
    //             },
    //             DataType::FutureEntry((pair_id, expiration_timestamp)) => 
                
    //             {
    //                 return FutureEntry { 
    //                 base_entry : BaseEntry { 
    //                     timestamp : timestamp, 
    //                     source : source, 
    //                     num_sources_aggregated : 0
    //                 }, 
    //                 pair_id : pair_id, 
    //                 price : price, 
    //                 volume : volume, 
    //                 expiration_timestamp : expiration_timestamp
    //             };
    //             },
    //         }             
    //         }


    //     fn get_latest_checkpoint_index(data_type : DataType, aggregation_mode : felt252) -> u256 {
    //         let checkpoint_index = match data_type { 
    //             DataType::SpotEntry(pair_id) => {oracle_checkpoint_index::read((pair_id, SPOT, 0));},
    //             DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoint_index::read((pair_id, FUTURE, expiration_timestamp));},
    //         }
    //         return checkpoint_index;
    //     }


    //     //TODO, ADD AGGREGATION_MODE
    //     fn get_latest_checkpoint ( data_type : DataType, aggregation_mode :felt252) -> Checkpoint { 
    //         let cur_idx = get_latest_checkpoint_index(data_type, aggregation_mode);
    //         let latest_checkpoint = match data_type { 
    //             DataType::SpotEntry(pair_id) => {oracle_checkpoints::read((pair_id, SPOT, cur_idx, 0));},
    //             DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoints::read((pair_id, FUTURE,cur_idx, expiration_timestamp));},
    //         }
    //         return latest_checkpoint;
    //     }
        
    //     fn get_decimals_for_currency(currency_id : felt252, typeof : felt252) -> u32 { 
    //         let key_currency = oracle_currencies_storage::read(currency_id);
    //         if (key_currency.id.is_zero()){
    //             return 0;
    //         }
    //         key_currency.decimals
    //     }
    }


    //     //
    //     //Guard
    //     //
    //     fn only_oracle_controller() {
    //         let caller_address = get_caller_address();
    //         let oracle_controller_address = oracle_controller_address_storage::read();
    //         if (oracle_controller_address.is_zero()) {
    //             return ();
    //         }
    //         assert(
    //             caller_address == oracle_controller_address,
    //             'oracle: can only be called by the oracle controller'
    //         );
    //         return ();
    //     }


    //     //
    //     //View 
    //     //

    //     #[view]
    //     fn get_admin_address() -> ContractAddress {
    //         return Admin::get_admin_address();
    //     }

    //     #[view]
    //     fn get_publisher_registry_address() -> ContractAddress {
    //         let publisher_registry_address = oracle_publisher_registry_address_storage::read();
    //         return publisher_registry_address;
    //     }


    //     //
    //     //Setters
    //     //

        

    //     fn publish_data(new_entry : entryDataType) { 
    //         match new_entry { 
    //             entryDataType::SpotEntry(spot_entry) => { 
    //                 validate_sender_for_source(spot_entry);
    //                 let entry = get_data_entry(spot_entry.pair_id,spot_entry.base.source );
    //                 validate_data_timestamp(new_entry, entry); 
    //                 SubmittedSpotEntry(spot_entry);
    //                 let element = actual_set_element_at(0, 0, 31, spot_entry.base.timestamp);
    //                 let element = actual_set_element_at(element, 32, 42, spot_entry.volume);
    //                 let element = actual_set_element_at(element, 75, 128, spot_entry.price);
    //                 let spot_entry_storage = SpotEntryStorage(timestamp__volume__price=element);
    //                 oracle_data_entry_storage::write(
    //                     spot_entry.pair_id, spot_entry.base.source, SPOT, 0
    //                 );
    //             }, 
    //             entryDataType::FutureEntry(future_entry) => {
    //                 validate_sender_for_source(future_entry);
    //                 let entry = get_data_entry(future_entry.pair_id,future_entry.base.source );
    //                 validate_data_timestamp(new_entry, entry); 
    //                 SubmittedFutureEntry(future_entry);
    //                 let element = actual_set_element_at(0, 0, 31, future_entry.base.timestamp);
    //                 let element = actual_set_element_at(element, 32, 42, future_entry.volume);
    //                 let element = actual_set_element_at(element, 75, 128, future_entry.price);
    //                 let future_entry_storage = FutureEntryStorage(timestamp__volume__price=element);
    //                 oracle_data_entry_storage::write(
    //                     future_entry.pair_id, future_entry.base.source, FUTURE, expiration_timestamp
    //                 );
    //             }
    //         }
    //         return();
     
    //     }

    //     fn update_publisher_registry_address(publisher_registry_address : ContractAddress){ 
    //         let old_publisher_registry_address = oracle_publisher_registry_address_storage::read();
    //         oracle_publisher_registry_address_storage::write(publisher_registry_address);
    //         UpdatedPublisherRegistryAddress(
    //             old_publisher_registry_address, publisher_registry_address
    //         );
    //         return ();
    //     }

       
    //     //
    //     //Internal
    //     //
    //     fn build_sources_array(data_type:DataType, ref sources : Array<felt252>, idx : usize) { 
    //         match data_type { 
    //             DataType::SpotEntry(pair_id) => {
    //                 let new_source = oracle_sources_storage::read((pair_id, SPOT,idx, 0 ));
    //                 sources.append(new_source);

    //             }, 
    //             DataType::FutureEntry((pair_id, expiration_timestamp)) => { 
    //                 let new_source = oracle_sources_storage::read((pair_id, FUTURE, idx, expiration_timestamp));
    //                 sources.append(new_source);
    //             }
    //         }
            
    //     }

        
        
    //     fn get_latest_entry_timestamp(data_type : DataType, sources: @Array<felt252>) -> u256{ 
    //         let mut cur_idx = 0;
    //         let mut latest_timestamp = 0;
    //         loop { 
    //             if (cur_idx >= sources.len()) { 
    //                 break ();
    //             }
    //             let entry = get_data_entry(data_type, sources.at(cur_idx));
    //             if entry.base.timestamp > latest_timestamp { 
    //                 latest_timestamp = entry.base.timestamp;
    //             }
    //             cur_idx += 1;
    //         }
    //         return latest_timestamp;
    //     }

    //     fn get_checkpoint_by_index(data_type : DataType, checkpoint_index : u256)-> Checkpoint { 
    //         let checkpoint = match data_type { 
    //             DataType::SpotEntry(pair_id) => {oracle_checkpoints::read((pair_id, SPOT, checkpoint_index,0));},
    //             DataType::FutureEntry((pair_id, expiration_timestamp)) => {oracle_checkpoints::read((pair_id, FUTURE,checkpoint_index, expiration_timestamp));},
    //         }
    //         return checkpoint;
    //     }

    //     fn validate_sender_for_source<T, impl THasBaseEntry: hasBaseEntry<T>>(_entry : T ) { 
    //         let publisher_registry_address = get_publisher_registry_address();
    //         let publisher_address = IPublisherRegistry::get_publisher_address(publisher_registry_address,_entry.base.source );
    //         let _can_publish_source = IPublisherRegistry::can_publish_source( publisher_registry_address, _entry.base.publisher, _entry.base.source);
    //         let caller_address = get_caller_address( );
    //         assert(publisher_address!=0, 'Oracle: Publisher is not registered'); 
    //         assert(!caller_address.is_zero() , 'Oracle: Caller must not be a zero address'); 
    //         assert (caller_address == publisher_address, 'Oracle: Transaction not from the publisher account');
    //         assert (_can_publish_source==true, 'Oracle: Publisher is not authorized for this source');
    //         return (); 

    //     }

        fn get_all_sources(data_type : DataType) -> Array<felt252> { 
            let mut sources = ArrayTrait::<felt252>::new();
            match data_type { 
                DataType::SpotEntry(pair_id) => { 
                    let source_len = oracle_sources_len_storage::read((pair_id, SPOT, 0));
                    build_sources_array(data_type, ref sources, source_len); 
                    return sources;
                }, 
                DataType::FutureEntry((pair_id, expiration_timestamp)) => { 
                    let source_len = oracle_sources_len_storage::read((pair_id, FUTURE, expiration_timestamp));
                    build_sources_array(data_type ,ref sources, source_len, expiration_timestamp);
                    return sources;
                },
            }
            
        }

        fn validate_data_timestamp<T, impl THasBaseEntry : hasBaseEntry<T>>(new_entry : entryDataType , last_entry : T)  { 
            
                match new_entry { 
                    entryDataType::SpotEntry(spot_entry)=> {
                        assert(spot_entry.base.timestamp > last_entry.base.timestamp, 'Existing entry is more recent');
                        if (last_entry.base.timestamp.is_zero()) { 
                            let sources_len = oracle_sources_len_storage::read((spot_entry.pair_id,SPOT));
                            oracle_sources_storage::write((spot_entry.pair_id, SPOT, sources_len, 0), spot_entry.base.source );
                            oracle_sources_len_storage::write((spot_entry.pair_id, SPOT, 0), sources_len +1 ); }
                    },
                    entryDataType::FutureEntry(future_entry)=> {
                        assert(future_entry.base.timestamp > last_entry.base.timestamp, 'Existing entry is more recent');
                        if (last_entry.base.timestamp.is_zero()) { 
                            let sources_len = oracle_sources_len_storage::read((future_entry.pair_id,FUTURE, future_entry.expiration_timestamp));
                            oracle_sources_storage::write((future_entry.pair_id, FUTURE, sources_len, future_entry.expiration_timestamp), future_entry.base.source);
                            oracle_sources_len_storage::write((future_entry.pair_id, FUTURE,future_entry.expiration_timestamp), sources_len +1 ); }
                            }
                        }
                        return ();
        }
            
            
        

    


        fn add_currency(currency: Currency) {

            let existing_currency = oracle_currencies_storage::read(currency.id);
            assert(existing_currency.id == 0, 'Currency already exists for key');
            SubmittedCurrency(currency);
            oracle_currencies_storage::write(currency.id, currency);
            return ();
        }



        // fn update_currency(currency: Currency, typeof : felt252) {
        //     oracle_currencies_storage::write(currency.id, currency);
        //     UpdatedCurrency(currency);
        //     return ();
        // }
        
        // fn add_pair(pair : Pair) { 
        //     let pair_id = oracle_pairs_storage::read(pair.id);
        //     assert(pair_id.is_zero(), 'Oracle: pair with this key already registered');
        //     SubmittedPair(pair);
        //     oracle_pairs_storage::write(pair.id, pair);
        //     oracle_pair_id_storage::write((pair.quote_currency_id, pair.base_currency_id), pair.id);
        //     return();
        // }

       
        
        // fn _set_keys_currencies(key_currencies: @Array<Currency> , idx :usize) { 
            
        //     loop {
        //         if (idx == key_currencies.len()) { 
        //             break ();
        //         }
        //         let key_currency = *key_currencies.at(idx);
        //         oracle_currencies_storage::write(key_currency.id, key_currency);
        //         _set_keys_currencies(key_currencies, idx+1);
        //     }  
        //     return();
        // }

        // fn set_sources_threshold(threshold: u32) {
        //         oracle_sources_threshold_storage::write(threshold);
        //         return ();
        //     }
    
        // fn _set_keys_pairs(key_pairs: @Array<Pair>) { 
        //     let mut idx : usize  =0; 
        //     loop {
        //         if (idx>= key_pairs.len()) { 
        //             break ();
        //         }
        //         let key_pair = *key_pairs.at(idx);
        //         oracle_pairs_storage::write(key_pair.id, key_pair);
        //         oracle_pair_id_storage::write((key_pair.quote_currency_id, key_pair.base_currency_id), key_pair.id);
        //         idx = idx +1;
        //     }  
        //     return();
        // }

        fn set_checkpoint(data_type : DataType, aggregation_mode :felt252) { 
            let priceResponse = get_data(data_type, aggregation_mode); 
            let sources_threshold = oracle_sources_threshold_storage::read();
            let cur_checkpoint = get_latest_checkpoint(data_type, aggregation_mode);
            if (sources_threshold< priceResponse.num_sources_aggregated & (cur_checkpoint.timestamp+1)< priceResponse.timestamp) { 
                let new_checkpoint = Checkpoint
                {timestamp: priceResponse.timestamp, value: priceResponse.price, aggregation_mode:aggregation_mode, num_sources_aggregated:priceResponse.num_sources_aggregated};
                match data_type {
                    DataType::SpotEntry(pair_id) => {
                        let cur_idx = oracle_checkpoint_index::read((pair_id, SPOT, 0));
                        oracle_checkpoints::write((pair_id, SPOT, cur_idx, 0.into()),  new_checkpoint); 
                        oracle_checkpoint_index::write((pair_id, SPOT, 0), cur_idx+1);
                        CheckpointSpotEntry(pair_id);
                      

                    },
                    DataType::FutureEntry((pair_id, expiration_timestamp)) => { 
                        let cur_idx = oracle_checkpoint_index::read((pair_id, FUTURE, expiration_timestamp));
                        oracle_checkpoints::write((pair_id, FUTURE, cur_idx, expiration_timestamp) ,new_checkpoint); 
                        oracle_checkpoint_index::write((pair_id, FUTURE, expiration_timestamp), cur_idx+1);
                        CheckpointFutureEntry(pair_id, expiration_timestamp);
                       
                    },
                }
            }
            return ();
        }
 }
 
 


