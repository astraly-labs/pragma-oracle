use starknet::ContractAddress;
use pragma::entry::structs::{PragmaPricesResponse, DataType};
use array::{ArrayTrait, SpanTrait};


#[derive(Drop, Serde, Copy, starknet::Store)]
struct Composition {
    asset: DataType,
    weight: u64, // multiplied by 10^decimals
    weight_decimals: u32,
    sources: Option::<Span<felt252>> // if we do not provide sources, all sources will be considered
}


#[starknet::interface]
trait IIndexPriceFeed<TContractState> {
    fn create_price_index(
        ref self: TContractState, index_name: felt252, assets: Array<Composition>
    );
    // fn update_price_index_name(
    //     ref self: TContractState, index_name: felt252, new_index_name: felt252
    // );
    fn update_price_index_owner(
        ref self: TContractState, index_name: felt252, new_owner: ContractAddress
    );
    fn update_price_index_composion(
        ref self: TContractState, index_name: felt252, new_composition: Array<Composition>
    );
    fn update_oracle_address(ref self: TContractState, new_oracle_address: ContractAddress);
    fn get_index_price_composition(
        self: @TContractState, index_name: felt252
    ) -> Array<Composition>;
    fn get_median_index_price(self: @TContractState, index_name: felt252) -> PragmaPricesResponse;
}

#[starknet::contract]
mod IndexPriceFeed {
    use super::{
        ContractAddress, Composition, PragmaPricesResponse, ArrayTrait, SpanTrait, IIndexPriceFeed
    };
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use pragma::entry::structs::{DataType, AggregationMode};
    use pragma::admin::admin::Ownable;
    use option::OptionTrait;
    use cmp::{max, min};
    use pragma::operations::time_series::convert::normalize_to_decimals;
    type Owner = ContractAddress;
    type Index_Name = felt252;

    const MAX_ASSETS_COMPOSITION: u32 = 20_u32;


    mod Errors {
        const TOO_MANY_ASSETS: felt252 = 'Too many assets';
        const CALLER_NOT_OWNER: felt252 = 'Caller is not index owner';
        const UNAUTHORIZED: felt252 = 'Admin: unauthorized';
    }

    #[storage]
    struct Storage {
        oracle_address: ContractAddress,
        index_price_feed_composition: LegacyMap::<Index_Name, Array<Composition>>,
        index_price_feed_owner: LegacyMap::<Index_Name, Owner>,
    }






    #[constructor]
    fn constructor(ref self: ContractState, oracle_address: ContractAddress) {
        self.oracle_address.write(oracle_address);
    }

    #[external(v0)]
    impl IndexPriceFeedImpl of IIndexPriceFeed<ContractState> {
        fn create_price_index(
            ref self: ContractState, index_name: felt252, assets: Array<Composition>
        ) {
            let owner = starknet::get_caller_address();
            assert(assets.len() < MAX_ASSETS_COMPOSITION, Errors::TOO_MANY_ASSETS);
            self.index_price_feed_composition.write(index_name, assets);
            self.index_price_feed_owner.write(index_name, owner);
        }

        // fn update_price_index_name(
        //     ref self: ContractState, index_name: Index_Name, new_index_name: Index_Name
        // ) {
        //     let caller = starknet::get_caller_address();
        //     let owner = self.index_price_feed_composition.read(index_name);
        // }

        fn update_price_index_owner(
            ref self: ContractState, index_name: Index_Name, new_owner: ContractAddress
        ) {
            let caller = starknet::get_caller_address();
            assert(
                assert_only_price_index_owner(@self, caller, index_name), Errors::CALLER_NOT_OWNER
            );
            self.index_price_feed_owner.write(index_name, new_owner);
        }
        fn update_price_index_composion(
            ref self: ContractState, index_name: Index_Name, new_composition: Array<Composition>
        ) {
            let caller = starknet::get_caller_address();
            assert(
                assert_only_price_index_owner(@self, caller, index_name), Errors::CALLER_NOT_OWNER
            );
            self.index_price_feed_composition.write(index_name, new_composition);
        }

        fn update_oracle_address(ref self: ContractState, new_oracle_address: ContractAddress) {
            assert_only_admin();
            self.oracle_address.write(new_oracle_address);
        }

        fn get_index_price_composition(
            self: @ContractState, index_name: felt252
        ) -> Array<Composition> {
            self.index_price_feed_composition.read(index_name)
        }
        fn get_median_index_price(
            self: @ContractState, index_name: felt252
        ) -> PragmaPricesResponse {
            let composition = self.index_price_feed_composition.read(index_name);
            let oracle_address = self.oracle_address.read();
            let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
            compute_weigthed_index(composition, oracle_dispatcher)
        }
    }
    fn assert_only_admin() {
        let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        let admin = Ownable::OwnableImpl::owner(@state);
        let caller = starknet::get_caller_address();
        assert(caller == admin, Errors::UNAUTHORIZED);
    }

    fn assert_only_price_index_owner(
        self: @ContractState, caller: ContractAddress, index_name: Index_Name
    ) -> bool {
        let owner = self.index_price_feed_owner.read(index_name);
        owner == caller
    }

    fn compute_weigthed_index(composition: Array<Composition>, oracle_dispatcher: IOracleABIDispatcher) -> PragmaPricesResponse {
        let mut cur_idx = 0;
        let mut weights = 0;
        let mut decimals = 0;
        let mut weighted_prices: u128 = 0;
        let mut last_updated_timestamp : u64 = 0;
        let mut num_sources_aggregated: u32 = 0;
        loop {
            if (cur_idx == composition.len()) {
                break ();
            }
            let composition_i = *composition.at(cur_idx);
            let mut asset_entry = match composition_i.sources {
                Option::Some(source_array) => {
                    oracle_dispatcher.get_data_median_for_sources(composition_i.asset, source_array)
                }, 
                Option::None(()) => {
                    oracle_dispatcher.get_data_median(composition_i.asset)
                }
            };
            if (cur_idx == 0) {
                decimals == asset_entry.decimals;
            }
            last_updated_timestamp = min(last_updated_timestamp, asset_entry.last_updated_timestamp);
            num_sources_aggregated = min(num_sources_aggregated, asset_entry.num_sources_aggregated);
            if (asset_entry.decimals < decimals ) {
                asset_entry.price = normalize_to_decimals(asset_entry.price, asset_entry.decimals, decimals);
            } else {
                weighted_prices = normalize_to_decimals(weighted_prices, decimals, asset_entry.decimals);
                decimals = asset_entry.decimals
            }
            weighted_prices += asset_entry.price * composition_i.weight.into() ;  // handle decimals if difference in decimals for given assets 
            weights += composition_i.weight;
            cur_idx += 1;
        };

        PragmaPricesResponse {
            price: weighted_prices/weights.into(), 
            last_updated_timestamp: last_updated_timestamp, 
            num_sources_aggregated: num_sources_aggregated, 
            decimals: decimals, 
            expiration_timestamp: Option::None

        }
    }
}

