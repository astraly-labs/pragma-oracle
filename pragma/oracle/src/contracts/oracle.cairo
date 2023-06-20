#[contract]
use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
    USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntryStorage, FutureEntry, OptionEntry,
    simpleDataType, SpotEntryStorage, FutureEntryStorage, AggregationMode, PossibleEntries,
    ArrayEntry
};

use oracle::contracts::library::Oracle;
use oracle::business_logic::oracleInterface::IOracle;
use starknet::{ContractAddress, get_caller_address};
use array::ArrayTrait;
use admin::contracts::Admin::Admin;
use starknet::class_hash::ClassHash;
use zeroable::Zeroable;
use pragma::upgradeable::contracts::Upgradeable;

#[external]
fn initializer(
    proxy_admin: felt252,
    publisher_registry_address: ContractAddress,
    currencies: @Array<Currency>,
    pairs: @Array<Pair>
) {
    Oracle::initializer(publisher_registry_address, currencies, pairs);
    return ();
}

//
// Getters
//

#[view]
fn get_data_entries_for_sources(
    data_type: DataType, sources: @Array<felt252>
) -> Array<PossibleEntries> {
    let (entries, _, _) = Oracle::get_data_entries(data_type, sources);
    entries
}


#[view]
fn get_data_entries(data_type: DataType) -> Array<PossibleEntries> {
    let mut sources = ArrayTrait::<felt252>::new();
    let sources = Oracle::get_all_sources(data_type);
    let (entries, _, _) = Oracle::get_data_entries(data_type, @sources);
    entries
}


#[view]
fn get_data_median(data_type: DataType) -> PragmaPricesResponse {
    let sources = Oracle::get_all_sources(data_type);
    let prices_response: PragmaPricesResponse = Oracle::get_data(
        data_type, AggregationMode::Median(()), @sources
    );
    prices_response
}

#[view]
fn get_data_median_for_sources(
    data_type: DataType, sources: Array<felt252>
) -> PragmaPricesResponse {
    let prices_response: PragmaPricesResponse = Oracle::get_data(
        data_type, AggregationMode::Median(()), @sources
    );
    prices_response
}

#[view]
fn get_data_median_multi(
    data_types: @Array<DataType>, sources: Array<felt252>
) -> Array<PragmaPricesResponse> {
    let mut prices_response = ArrayTrait::<PragmaPricesResponse>::new();
    let mut cur_idx = 0;
    loop {
        if (cur_idx >= data_types.len()) {
            break ();
        }

        let data_type = *data_types.at(cur_idx);
        let cur_prices_response: PragmaPricesResponse = Oracle::get_data(
            data_type, AggregationMode::Median(()), @sources
        );
        prices_response.append(cur_prices_response);
        cur_idx += 1;
    };
    prices_response
}

#[view]
fn get_data(data_type: DataType, aggregation_mode: AggregationMode) -> PragmaPricesResponse {
    let sources = Oracle::get_all_sources(data_type);
    Oracle::get_data(data_type, aggregation_mode, @sources)
}

#[view]
fn get_data_for_sources(
    data_type: DataType, aggregationMode: AggregationMode, sources: Array<felt252>
) -> PragmaPricesResponse {
    Oracle::get_data(data_type, aggregationMode, @sources)
}


#[view]
fn get_publisher_registry_address() -> ContractAddress {
    Oracle::get_publisher_registry_address()
}

#[view]
fn get_decimals(data_type: DataType) -> u32 {
    Oracle::get_decimals(data_type)
}

#[view]
fn get_data_with_USD_hop(
    base_currency_id: felt252,
    quote_currency_id: felt252,
    aggregation_mode: AggregationMode,
    typeof: simpleDataType,
    expiration_timestamp: Option<u256>
) -> PragmaPricesResponse {
    Oracle::get_data_with_USD_hop(
        base_currency_id, quote_currency_id, aggregation_mode, typeof, expiration_timestamp
    )
}

#[view]
fn get_latest_checkpoint_index(data_type: DataType, aggregation_mode: AggregationMode) -> u256 {
    Oracle::get_latest_checkpoint_index(data_type, aggregation_mode)
}

#[view]
fn get_checkpoint(data_type: DataType, checkpoint_index: u256) -> Checkpoint {
    Oracle::get_checkpoint_by_index(data_type, checkpoint_index)
}

#[view]
fn get_sources_threshold() -> u32 {
    Oracle::get_sources_threshold()
}

#[view]
fn get_admin_address() -> ContractAddress {
    Oracle::get_admin_address()
}

#[view]
fn get_implementation_hash() -> ContractAddress {
    Upgradeable::get_implementation_hash()
}

#[view]
fn get_last_checkpoint_before(
    data_type: DataType, aggregation_mode: AggregationMode, timestamp: u256
) -> Checkpoint {
    let idx = Oracle::find_startpoint(data_type, aggregation_mode, timestamp);
    let checkpoint = Oracle::get_checkpoint_by_index(data_type, idx);
    checkpoint
}


//
// Setters
//

#[external]
fn publish_data(new_entry: PossibleEntries) {
    Oracle::publish_data(new_entry);
}


#[external]
fn update_publisher_registry_address(new_publisher_registry_addrress: ContractAddress) {
    assert_only_admin();
    Oracle::update_publisher_registry_address(new_publisher_registry_addrress);
}

#[external]
fn add_currency(new_currency: Currency) {
    assert_only_admin();
    Oracle::add_currency(new_currency);
}

#[external]
fn update_currency(new_currency: Currency, typeof: felt252) {
    assert_only_admin();
    Oracle::update_currency(new_currency, typeof);
}

#[external]
fn add_pair(new_pair: Pair) {
    assert_only_admin();
    Oracle::add_pair(new_pair);
}

#[external]
fn set_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) {
    Oracle::set_checkpoint(data_type, aggregation_mode);
}

#[external]
fn set_checkpoints(data_types: Array<DataType>, aggregation_mode: AggregationMode) {
    Oracle::set_checkpoints(data_types, aggregation_mode);
}

//
// Upgrades
//

#[external]
fn upgrade(impl_hash: ClassHash) {
    assert_only_admin();
    Upgradeable::upgrade(impl_hash);
}

#[external]
fn set_admin_address(admin_address: ContractAddress) {
    assert_only_admin();
    Admin::set_admin_address(admin_address);
}

#[external]
fn set_sources_threshold(threshold: u32) {
    assert_only_admin();
    Oracle::set_sources_threshold(threshold);
}


#[internal]
fn assert_only_admin() {
    let admin = Admin::get_admin_address();
    let caller = get_caller_address();
    assert(caller == admin, 'Admin: unauthorized');
}
