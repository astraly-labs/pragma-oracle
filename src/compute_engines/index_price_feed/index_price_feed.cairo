use starknet::ContractAddress;
use pragma::entry::structs::{PragmaPricesResponse, DataType};
use array::{ArrayTrait, SpanTrait};
use starknet::class_hash::ClassHash;


#[derive(Drop, Serde, Copy)]
struct Composition {
    asset: DataType,
    weight: u64, // multiplied by 10^weight_decimals
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
    fn update_price_index_composition(
        ref self: TContractState, index_name: felt252, new_composition: Array<Composition>
    );
    fn update_price_index_sources(
        ref self: TContractState, index_name: felt252, new_sources: Array<felt252>
    );
    fn update_oracle_address(ref self: TContractState, new_oracle_address: ContractAddress);
    fn get_index_price_composition(
        self: @TContractState, index_name: felt252
    ) -> Array<Composition>;
    fn get_index_price_sources(self: @TContractState, index_name: felt252) -> Array<felt252>;
    fn get_index_price_owner(self: @TContractState, index_name: felt252) -> ContractAddress;
    fn get_median_index_price(self: @TContractState, index_name: felt252) -> PragmaPricesResponse;
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
}

#[starknet::contract]
mod IndexPriceFeed {
    use core::zeroable::Zeroable;
    use super::{
        ContractAddress, Composition, PragmaPricesResponse, ArrayTrait, SpanTrait, IIndexPriceFeed,
        ClassHash
    };
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use pragma::entry::structs::{DataType, AggregationMode};
    use pragma::admin::admin::Ownable;
    use pragma::upgradeable::upgradeable::Upgradeable;
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
    use debug::PrintTrait;

    // type assignation (for clarity)
    type Source = felt252;
    type Owner = ContractAddress;
    type Index_Name = felt252;

    // constants
    const MAX_ASSETS_COMPOSITION: u32 = 20_u32;
    const SPOT: felt252 = 'SPOT';
    const MAX_FELT: u256 =
        3618502788666131213697322783095070105623107215331596699973092056135872020480; //max felt value
    const COMPOSITION_TYPE_OF_SHIFT_U36: u256 = 0x1000000000000;
    const COMPOSITION_TYPE_OF_SHIFT_MASK_U36: u256 = 0xffffffffffff;
    const COMPOSITION_ASSET_SHIFT_U188: u256 = 0x10000000000000000000000000000000000000000000;
    const COMPOSITION_ASSET_SHIFT_MASK_U188: u256 = 0xfffffffffffffffffffffffffffffffffffffffffff;
    const COMPOSITION_WEIGHT_SHIFT_U208: u256 =
        0x10000000000000000000000000000000000000000000000000000000000;
    const COMPOSITION_WEIGHT_SHIFT_MASK_U208: u256 =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const COMPOSITION_WEIGHT_DECIMALS_SHIFT_U220: u256 =
        0x1000000000000000000000000000000000000000000000000000000000000000;
    const COMPOSITION_WEIGHT_DECIMALS_SHIFT_MASK_U220: u256 =
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;


    mod Errors {
        const TOO_MANY_ASSETS: felt252 = 'Too many assets';
        const CALLER_NOT_OWNER: felt252 = 'Caller is not index owner';
        const UNAUTHORIZED: felt252 = 'Admin: unauthorized';
        const UNSUPPORTED_TYPE_OF_DATA: felt252 = 'Type of data not suppported';
        const EMPTY_COMPOSITION: felt252 = 'Composition array is empty';
        const ERROR_FETCHING_PRICE: felt252 = 'Error fetching asset price';
        const INDEX_ALREADY_CREATED: felt252 = 'Index already created';
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
                value.weight_decimals.into() == value.weight_decimals.into()
                    & COMPOSITION_WEIGHT_DECIMALS_SHIFT_MASK_U220,
                'Composition:weight dec too big'
            );
            let pack_value: u256 = type_of_data.into()
                + pair_id.into() * COMPOSITION_TYPE_OF_SHIFT_U36
                + value.weight.into() * COMPOSITION_ASSET_SHIFT_U188
                + value.weight_decimals.into() * COMPOSITION_WEIGHT_SHIFT_U208;
            assert(pack_value.into() < MAX_FELT, 'Composition cannot to be stored');
            pack_value.try_into().unwrap()
        }
        fn unpack(value: felt252) -> Composition {
            let value: u256 = value.into();
            let weight_decimals_shift: NonZero<u256> = integer::u256_try_as_non_zero(
                COMPOSITION_WEIGHT_SHIFT_U208.into()
            )
                .unwrap();
            let (weight_decimals, rest) = integer::u256_safe_div_rem(value, weight_decimals_shift);
            let weight_shift: NonZero<u256> = integer::u256_try_as_non_zero(
                COMPOSITION_ASSET_SHIFT_U188.into()
            )
                .unwrap();

            let (weight, rest_2) = integer::u256_safe_div_rem(rest, weight_shift);
            let asset_shift: NonZero<u256> = integer::u256_try_as_non_zero(
                COMPOSITION_TYPE_OF_SHIFT_U36.into()
            )
                .unwrap();

            let (asset, type_of_data) = integer::u256_safe_div_rem(rest_2, asset_shift);
            let data_type = if (type_of_data == 'SPOT') {
                DataType::SpotEntry(asset.try_into().unwrap())
            } else {
                // supporting for now only spot assets
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
        /// Create an new index, only modifiable by the owner of the index 
        ///
        /// # Arguments
        ///
        /// * `index_name` -  Name of the index to be created.
        /// * `assets` - Array of assets composing the index.
        /// * `sources` - Sources to work with(can be set to an empty array, all sources will then be considered).
        fn create_price_index(
            ref self: ContractState,
            index_name: felt252,
            mut assets: Array<Composition>,
            mut sources: Array<felt252>
        ) {
            let owner = starknet::get_caller_address();
            check_name_validity(@self, index_name);
            assert(assets.len() < MAX_ASSETS_COMPOSITION, Errors::TOO_MANY_ASSETS);
            store_composition_configuration(ref self, index_name, ref assets);
            store_sources_configuration(ref self, index_name, ref sources);
            self.index_price_feed_owner.write(index_name, owner);
        }

        /// Upgrade an existing index owner, only callable by the actual owner of the index
        ///
        /// # Arguments
        ///
        /// * `index_name` - Name of the index to be updated.
        /// * `new_owner` - New owner contract address
        fn update_price_index_owner(
            ref self: ContractState, index_name: felt252, new_owner: ContractAddress
        ) {
            let caller = starknet::get_caller_address();
            assert_only_price_index_owner(@self, caller, index_name);
            self.index_price_feed_owner.write(index_name, new_owner);
        }

        /// Upgrade an existing index sources, only callable by the actual owner of the index
        ///
        /// # Arguments
        ///
        /// * `index_name` - Name of the index to be updated.
        /// * `new_sources` - New array of sources to work with(if set to an empty array, all sources will be considered)
        fn update_price_index_sources(
            ref self: ContractState, index_name: felt252, mut new_sources: Array<felt252>
        ) {
            let caller = starknet::get_caller_address();
            assert_only_price_index_owner(@self, caller, index_name);
            let mut sources_list: List<felt252> = self.index_price_feed_sources.read(index_name);
            sources_list.clean();
            store_sources_configuration(ref self, index_name, ref new_sources);
        }

        /// Upgrade an existing index asset composition, only callable by the actual owner of the index
        ///
        /// # Arguments
        ///
        /// * `index_name` - Name of the index to be updated.
        /// * `new_composition` - New array of composition associated to the given index name
        fn update_price_index_composition(
            ref self: ContractState, index_name: felt252, mut new_composition: Array<Composition>
        ) {
            let caller = starknet::get_caller_address();
            assert_only_price_index_owner(@self, caller, index_name);
            assert(new_composition.len() != 0, Errors::EMPTY_COMPOSITION);
            let mut composition_list: List<Composition> = self
                .index_price_feed_composition
                .read(index_name);
            composition_list.clean();
            store_composition_configuration(ref self, index_name, ref new_composition);
        }

        /// Upgrade the oracle address of the contract, only callable by the admin
        ///
        /// # Arguments
        ///
        /// * `new_oracle_address` - New oracle address.
        fn update_oracle_address(ref self: ContractState, new_oracle_address: ContractAddress) {
            assert_only_admin();
            self.oracle_address.write(new_oracle_address);
        }

        /// Retrieve the asset composition associated to an index
        ///
        /// # Arguments
        ///
        /// * `index_name` - Name of the index to be consider.
        ///
        /// # Returns 
        ///
        /// * An array of asset composition(see structure format above)
        fn get_index_price_composition(
            self: @ContractState, index_name: felt252
        ) -> Array<Composition> {
            self.index_price_feed_composition.read(index_name).array()
        }

        /// Retrieve the sources associated to an index
        ///
        /// # Arguments
        ///
        /// * `index_name` - Name of the index to be consider.
        ///
        /// # Returns 
        ///
        /// * An array of asset source
        fn get_index_price_sources(self: @ContractState, index_name: felt252) -> Array<felt252> {
            self.index_price_feed_sources.read(index_name).array()
        }

        /// Retrieve the owner associated to an index
        ///
        /// # Arguments
        ///
        /// * `index_name` - Name of the index to be consider.
        ///
        /// # Returns 
        ///
        /// * Contract address of the owner of the index
        fn get_index_price_owner(self: @ContractState, index_name: felt252) -> ContractAddress {
            self.index_price_feed_owner.read(index_name)
        }

        /// Compute the index price of an already createad index
        ///
        /// # Arguments
        ///
        /// * `index_name` - Name of the index to be consider.
        ///
        /// # Returns 
        ///
        /// * A PragmaPricesResponse structure (see structs), containing the price, decimals, last updated_timestamp associated to the index
        fn get_median_index_price(
            self: @ContractState, index_name: felt252
        ) -> PragmaPricesResponse {
            let composition = self.index_price_feed_composition.read(index_name);
            let oracle_address = self.oracle_address.read();
            let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
            let sources = self.index_price_feed_sources.read(index_name);
            let mut composition_array = composition.array();
            compute_weigthed_index(ref composition_array, sources.array().span(), oracle_dispatcher)
        }


        /// Upgrade the contract
        ///
        /// # Arguments
        ///
        /// * `impl_hash` - New class hash.
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert_only_admin();
            let mut upstate: Upgradeable::ContractState = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::upgrade(ref upstate, impl_hash);
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
    )  {
        let owner = self.index_price_feed_owner.read(index_name);
        assert(owner == caller, Errors::CALLER_NOT_OWNER);
    }

    fn check_name_validity(self: @ContractState, index_name: felt252) {
        assert(
            self.index_price_feed_owner.read(index_name) == 0.try_into().unwrap(),
            Errors::INDEX_ALREADY_CREATED
        );
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
        ref composition: Array<Composition>,
        sources: Span<Source>,
        oracle_dispatcher: IOracleABIDispatcher
    ) -> PragmaPricesResponse {
        let mut weights: u64 = 0;
        let mut decimals = 0;
        let mut weighted_prices: u128 = 0;
        let mut last_updated_timestamp: u64 = 0;
        let mut num_sources_aggregated: u32 = 0;
        loop { //replace by pop_front
            match composition.pop_front() {
                Option::Some(element) => {
                    let mut asset_entry = if (sources.len() != 0) {
                        oracle_dispatcher.get_data_median_for_sources(element.asset, sources)
                    } else {
                        oracle_dispatcher.get_data_median(element.asset)
                    };
                    assert(!asset_entry.price.is_zero(), Errors::ERROR_FETCHING_PRICE);
                    if (decimals == 0) {
                        decimals = asset_entry.decimals;
                        last_updated_timestamp = asset_entry.last_updated_timestamp;
                        num_sources_aggregated = asset_entry.num_sources_aggregated
                    }
                    last_updated_timestamp =
                        min(last_updated_timestamp, asset_entry.last_updated_timestamp);
                    num_sources_aggregated =
                        min(num_sources_aggregated, asset_entry.num_sources_aggregated);
                    if (asset_entry.decimals < decimals) {
                        asset_entry
                            .price =
                                normalize_to_decimals(
                                    asset_entry.price, asset_entry.decimals, decimals
                                );
                    } else {
                        weighted_prices =
                            normalize_to_decimals(weighted_prices, decimals, asset_entry.decimals);
                        decimals = asset_entry.decimals
                    }
                    weighted_prices += asset_entry.price * element.weight.into();
                    weights += element.weight;
                },
                Option::None(_) => {
                    break ();
                }
            };
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

