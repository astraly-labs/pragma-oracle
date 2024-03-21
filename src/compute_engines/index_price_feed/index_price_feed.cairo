use starknet::ContractAddress;
use pragma::entry::structs::{PragmaPricesResponse, DataType};
use array::{ArrayTrait, SpanTrait};


#[derive(Drop, Serde, Copy)]
struct Composition {
    asset: DataType,
    weight: u64, // multiplied by 10^decimals
    weight_decimals: u32,
}


#[starknet::interface]
trait IIndexPriceFeed<TContractState> {
    fn create_price_index(
        ref self: TContractState,
        index_name: felt252,
        assets: Array<Composition>,
        sources: Array<felt252>
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
    fn update_price_index_sources(
            ref self: TContractState, index_name: felt252, new_sources: Array<felt252>
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
    use alexandria_storage::list::{List, ListTrait, calculate_base_and_offset_for_index};
    use starknet::{
        storage_read_syscall, storage_write_syscall, SyscallResult, SyscallResultTrait, StorePacking
    };
    use starknet::storage_access::{
        Store, StorageBaseAddress, storage_address_to_felt252, storage_address_from_base,
        storage_address_from_base_and_offset, storage_base_address_from_felt252
    };
    use cmp::{max, min};
    use pragma::operations::time_series::convert::normalize_to_decimals;


    // use consistent types 
    type Source = felt252;
    type Owner = ContractAddress;
    type Index_Name = felt252;

    const MAX_ASSETS_COMPOSITION: u32 = 20_u32;
    const SPOT: felt252 = 'SPOT';

    const COMPOSITION_TYPE_OF_SHIFT_U36: felt252 = 0x1000000000;
    const COMPOSITION_TYPE_OF_SHIFT_MASK_U36: u256 = 0xfffffffff;
    const COMPOSITION_ASSET_SHIFT_U188: felt252 = 0x100000000000000000000000000000000000000000000000;
    const COMPOSITION_ASSET_SHIFT_MASK_U188: u256 = 0xfffffffffffffffffffffffffffffffffffffffffffffff;
    const COMPOSITION_WEIGHT_SHIFT_U208: felt252 = 0x10000000000000000000000000000000000000000000000000000;
    const COMPOSITION_WEIGHT_SHIFT_MASK_U208: u256 =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const COMPOSITION_WEIGHT_DECIMALS_SHIFT_U220: felt252 =
        0x10000000000000000000000000000000000000000000000000000000;
    const COMPOSITION_WEIGHT_DECIMALS_SHIFT_MASK_U220: u256 =
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    mod Errors {
        const TOO_MANY_ASSETS: felt252 = 'Too many assets';
        const CALLER_NOT_OWNER: felt252 = 'Caller is not index owner';
        const UNAUTHORIZED: felt252 = 'Admin: unauthorized';
        const UNSUPPORTED_TYPE_OF_DATA: felt252 = 'Type of data not suppported';
    }

    #[storage]
    struct Storage {
        oracle_address: ContractAddress,
        index_price_feed_composition: LegacyMap::<Index_Name, List<Composition>>,
        index_price_feed_owner: LegacyMap::<Index_Name, Owner>,
        index_price_feed_sources: LegacyMap::<Index_Name, List<Source>>
    }

    impl CompositionStorePacking of StorePacking<Composition, felt252> {
        fn pack(value: Composition) -> felt252 {
            let (type_of_data, pair_id) = match value.asset {
                DataType::SpotEntry(val) => {
                    (SPOT, val)
                },
                DataType::FutureEntry(_) => {
                    panic_with_felt252(Errors::UNSUPPORTED_TYPE_OF_DATA);
                    (0, 0)
                },
                DataType::GenericEntry(_) => {
                    panic_with_felt252(Errors::UNSUPPORTED_TYPE_OF_DATA);
                    (0, 0)
                }
            };
            // add assertions
            assert(
                (type_of_data.into() == type_of_data.into() & COMPOSITION_TYPE_OF_SHIFT_MASK_U36),
                'Composition:type too big'
            );
            assert(
                pair_id.into() == pair_id.into() & COMPOSITION_ASSET_SHIFT_MASK_U188,
                'Composition:pair id too big'
            );
            assert(
                value.weight.into() == value.weight.into() & COMPOSITION_WEIGHT_SHIFT_MASK_U208,
                'Composition:weight too big'
            );
            assert(
                value.weight_decimals.into() == value.weight_decimals.into() & COMPOSITION_WEIGHT_DECIMALS_SHIFT_MASK_U220,
                'Composition:weight dec too big'
            );
            type_of_data.into() * COMPOSITION_TYPE_OF_SHIFT_U36
                + pair_id.into() * COMPOSITION_ASSET_SHIFT_U188
                + value.weight.into() * COMPOSITION_WEIGHT_SHIFT_U208
                + value.weight_decimals.into() * COMPOSITION_WEIGHT_DECIMALS_SHIFT_U220
        }
        fn unpack(value: felt252) -> Composition {
            let value: u256 = value.into();
            let weight_decimals_shift: NonZero<u256> = integer::u256_try_as_non_zero(
                COMPOSITION_WEIGHT_DECIMALS_SHIFT_U220.into()
            )
                .unwrap();
            let (weight_decimals, rest) = integer::u256_safe_div_rem(value, weight_decimals_shift);
            let weight_shift: NonZero<u256> = integer::u256_try_as_non_zero(
                COMPOSITION_WEIGHT_SHIFT_U208.into()
            )
                .unwrap();

            let (weight, rest_2) = integer::u256_safe_div_rem(rest, weight_shift);
            let asset_shift: NonZero<u256> = integer::u256_try_as_non_zero(
                COMPOSITION_ASSET_SHIFT_U188.into()
            )
                .unwrap();

            let (asset, type_of_data) = integer::u256_safe_div_rem(rest_2, asset_shift);
            let data_type = if (type_of_data == 'SPOT') {
                DataType::SpotEntry(asset.try_into().unwrap())
            } else {
                // to be modified
                panic_with_felt252('Type of data not supported');
                DataType::GenericEntry(0)
            };
            Composition {
                asset: data_type,
                weight: weight.try_into().unwrap(),
                weight_decimals: weight_decimals.try_into().unwrap()
            }
        }
    }


    #[constructor]
    fn constructor(ref self: ContractState, oracle_address: ContractAddress) {
        self.oracle_address.write(oracle_address);
    }

    #[external(v0)]
    impl IndexPriceFeedImpl of IIndexPriceFeed<ContractState> {
        fn create_price_index(
            ref self: ContractState,
            index_name: felt252,
            mut assets: Array<Composition>,
            mut sources: Array<Source>
        ) {
            let owner = starknet::get_caller_address();
            assert(assets.len() < MAX_ASSETS_COMPOSITION, Errors::TOO_MANY_ASSETS);
            store_composition_configuration(ref self, index_name, ref assets);
            store_sources_configuration(ref self, index_name, ref sources);
            self.index_price_feed_owner.write(index_name, owner);
        }

        fn update_price_index_owner(
            ref self: ContractState, index_name: Index_Name, new_owner: ContractAddress
        ) {
            let caller = starknet::get_caller_address();
            assert(
                assert_only_price_index_owner(@self, caller, index_name), Errors::CALLER_NOT_OWNER
            );
            self.index_price_feed_owner.write(index_name, new_owner);
        }


        fn update_price_index_sources(
            ref self: ContractState, index_name: Index_Name, mut new_sources: Array<Source>
        ) {
            let caller = starknet::get_caller_address();
            assert(
                assert_only_price_index_owner(@self, caller, index_name), Errors::CALLER_NOT_OWNER
            );
            let mut sources_list: List<Source> = self
                .index_price_feed_sources
                .read(index_name);
            sources_list.clean();
            store_sources_configuration(ref self, index_name, ref new_sources);

        }
        fn update_price_index_composion(
            ref self: ContractState, index_name: Index_Name, mut new_composition: Array<Composition>
        ) {
            let caller = starknet::get_caller_address();
            assert(
                assert_only_price_index_owner(@self, caller, index_name), Errors::CALLER_NOT_OWNER
            );
            let mut composition_list: List<Composition> = self
                .index_price_feed_composition
                .read(index_name);
            composition_list.clean();
            store_composition_configuration(ref self, index_name, ref new_composition);

        }


        fn update_oracle_address(ref self: ContractState, new_oracle_address: ContractAddress) {
            assert_only_admin();
            self.oracle_address.write(new_oracle_address);
        }

        fn get_index_price_composition(
            self: @ContractState, index_name: felt252
        ) -> Array<Composition> {
            self.index_price_feed_composition.read(index_name).array()
        }
        fn get_median_index_price(
            self: @ContractState, index_name: felt252
        ) -> PragmaPricesResponse {
            let composition = self.index_price_feed_composition.read(index_name);
            let oracle_address = self.oracle_address.read();
            let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
            let sources = self.index_price_feed_sources.read(index_name);
            compute_weigthed_index(
                composition.array().span(), sources.array().span(), oracle_dispatcher
            )
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

    fn store_composition_configuration(
        ref self: ContractState, index_name: Index_Name, ref elements: Array<Composition>
    ) {
        let mut index_price_feed_composition = self.index_price_feed_composition.read(index_name);
        loop {
            match elements.pop_front() {
                Option::Some(element) => {
                    index_price_feed_composition.append(element)
                },
                Option::None(_) => {
                    break ();
                }
            };
        }
    }

    fn store_sources_configuration(
        ref self: ContractState, index_name: Index_Name, ref elements: Array<Source>
    ) {
        let mut index_price_feed_sources = self.index_price_feed_sources.read(index_name);
        loop {
            match elements.pop_front() {
                Option::Some(element) => {
                    index_price_feed_sources.append(element)
                },
                Option::None(_) => {
                    break ();
                }
            };
        }
    }

    fn compute_weigthed_index(
        composition: Span<Composition>,
        sources: Span<Source>,
        oracle_dispatcher: IOracleABIDispatcher
    ) -> PragmaPricesResponse {
        let mut cur_idx = 0;
        let mut weights = 0;
        let mut decimals = 0;
        let mut weighted_prices: u128 = 0;
        let mut last_updated_timestamp: u64 = 0;
        let mut num_sources_aggregated: u32 = 0;
        loop { //replace by pop_front
            if (cur_idx == composition.len()) {
                break ();
            }
            let composition_i = *composition.at(cur_idx);
            let mut asset_entry = if (sources.len() != 0) {
                oracle_dispatcher.get_data_median_for_sources(composition_i.asset, sources)
            } else {
                oracle_dispatcher.get_data_median(composition_i.asset)
            };
            if (cur_idx == 0) {
                decimals == asset_entry.decimals;
            }
            last_updated_timestamp =
                min(last_updated_timestamp, asset_entry.last_updated_timestamp);
            num_sources_aggregated =
                min(num_sources_aggregated, asset_entry.num_sources_aggregated);
            if (asset_entry.decimals < decimals) {
                asset_entry
                    .price =
                        normalize_to_decimals(asset_entry.price, asset_entry.decimals, decimals);
            } else {
                weighted_prices =
                    normalize_to_decimals(weighted_prices, decimals, asset_entry.decimals);
                decimals = asset_entry.decimals
            }
            weighted_prices += asset_entry.price
                * composition_i
                    .weight
                    .into(); // handle decimals if difference in decimals for given assets 
            weights += composition_i.weight;
            cur_idx += 1;
        };

        PragmaPricesResponse {
            price: weighted_prices / weights.into(),
            last_updated_timestamp: last_updated_timestamp,
            num_sources_aggregated: num_sources_aggregated,
            decimals: decimals,
            expiration_timestamp: Option::None
        }
    }
}

