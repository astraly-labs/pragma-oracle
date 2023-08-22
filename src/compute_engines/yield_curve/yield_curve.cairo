use starknet::ContractAddress;
use array::ArrayTrait;
use alexandria_math::math::fpow;
use traits::Into;
use traits::TryInto;
use zeroable::Zeroable;
use array::SpanTrait;
use pragma::entry::structs::BaseEntry;

#[derive(Serde, Drop, Copy, starknet::Store)]
struct YieldPoint {
    expiry_timestamp: u64,
    capture_timestamp: u64, // timestamp of data capture
    // (1 day for overnight rates and expiration date for futures)
    rate: u128, // The calculated yield rate: either overnight rate
    // or max(0, ((future/spot) - 1) * (365/days to future expiry))
    source: felt252, // An indicator for the source (str_to_felt encode uppercase one of:
// "ON" (overnight rate),
// "FUTURE/SPOT" (future/spot rate),
// "OTHER" (for future additional data sources))
}

#[derive(Serde, Drop, Copy, starknet::Store)]
struct FutureKeyStatus {
    is_active: bool,
    expiry_timestamp: u64,
}


#[starknet::interface]
trait IYieldCurveABI<TContractState> {
    fn get_yield_points(self: @TContractState, decimals: u32) -> Span<YieldPoint>;
    fn get_admin_address(self: @TContractState, ) -> ContractAddress;
    fn get_oracle_address(self: @TContractState, ) -> ContractAddress;
    fn get_future_spot_pragma_source_key(
        self: @TContractState, pair_id: felt252, future_expiry_timestamp: u64
    ) -> felt252;
    fn get_pair_id(self: @TContractState, idx: u64) -> felt252;
    fn get_pair_id_is_active(self: @TContractState, pair_id: felt252) -> bool;
    fn get_pair_ids(self: @TContractState, ) -> Span<felt252>;
    fn get_future_expiry_timestamp(self: @TContractState, pair_id: felt252, idx: u64) -> u64;
    fn get_future_expiry_timestamps(self: @TContractState, pair_id: felt252) -> Span<u64>;
    fn get_on_key(self: @TContractState, idx: u64) -> felt252;
    fn get_on_key_is_active(self: @TContractState, on_key: felt252) -> bool;
    fn get_on_keys(self: @TContractState, ) -> Span<felt252>;
    fn get_future_expiry_timestamp_status(
        self: @TContractState, pair_id: felt252, future_expiry_timestamp: u64
    ) -> FutureKeyStatus;
    fn get_future_expiry_timestamp_is_active(
        self: @TContractState, pair_id: felt252, future_expiry_timestamp: u64
    ) -> bool;
    fn get_future_expiry_timestamp_expiry(
        self: @TContractState, pair_id: felt252, future_expiry_timestamp: u64
    ) -> u64;

    //
    // Setters
    //

    fn set_admin_address(ref self: TContractState, new_address: ContractAddress);
    fn set_future_spot_pragma_source_key(ref self: TContractState, new_source_key: felt252);
    fn set_oracle_address(ref self: TContractState, oracle_address: ContractAddress);
    fn add_pair_id(ref self: TContractState, pair_id: felt252, is_active: bool);
    fn set_pair_id_is_active(ref self: TContractState, pair_id: felt252, is_active: bool);
    fn add_future_expiry_timestamp(
        ref self: TContractState,
        pair_id: felt252,
        future_expiry_timestamp: u64,
        is_active: bool,
        expiry_timestamp: u64
    );
    fn set_future_expiry_timestamp_status(
        ref self: TContractState,
        pair_id: felt252,
        future_expiry_timestamp: u64,
        new_future_expiry_timestamp_status: FutureKeyStatus,
    );

    fn set_future_expiry_timestamp_is_active(
        ref self: TContractState,
        pair_id: felt252,
        future_expiry_timestamp: u64,
        new_is_active: bool
    );

    fn add_on_key(ref self: TContractState, on_key: felt252, is_active: bool);

    fn set_on_key_is_active(ref self: TContractState, on_key: felt252, is_active: bool);
}
#[starknet::contract]
mod YieldCurve {
    use super::{
        ContractAddress, ArrayTrait, IYieldCurveABI, YieldPoint, FutureKeyStatus, fpow, Into,
        TryInto, Zeroable, SpanTrait, BaseEntry
    };
    use pragma::oracle::oracle::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use pragma::entry::structs::{
        DataType, AggregationMode, PragmaPricesResponse, PossibleEntries, SpotEntry, FutureEntry,
        GenericEntry
    };
    use debug::PrintTrait;
    use pragma::admin::admin::Admin;
    const ON_SOURCE_KEY: felt252 = 'ON'; // str_to_felt("ON")
    const FUTURE_SPOT_SOURCE_KEY: felt252 = 'FUTURE/SPOT'; // str_to_felt("FUTURE/SPOT")
    const THEGRAPH_PRAGMA_SOURCE_KEY: felt252 = 'THEGRAPH'; // str_to_felt("THEGRAPH")
    const SECONDS_IN_YEAR: u64 = 31536000; // 365 * 24 * 60 * 60
    const DEFAULT_DECIMALS: u32 = 8;
    #[storage]
    struct Storage {
        oracle_address_storage: ContractAddress,
        future_spot_pragma_source_key_storage: felt252,
        pair_id_len_storage: u32,
        pair_id_storage: LegacyMap::<u64, felt252>,
        pair_id_is_active_storage: LegacyMap::<felt252, bool>,
        future_expiry_timestamp_len_storage: LegacyMap<felt252, u64>,
        future_expiry_timestamp_storage: LegacyMap<(felt252, u64), u64>,
        future_expiry_timestamp_status_storage: LegacyMap<(felt252, u64), FutureKeyStatus>,
        on_key_len_storage: u64,
        on_key_storage: LegacyMap::<u64, felt252>,
        on_key_is_active_storage: LegacyMap::<felt252, bool>
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, admin_address: ContractAddress, oracle_address: ContractAddress
    ) {
        self.set_admin_address(admin_address);
        self.oracle_address_storage.write(oracle_address);
        return ();
    }

    #[external(v0)]
    impl IYieldCurveImpl of IYieldCurveABI<ContractState> {
        //
        // Getters
        //

        fn get_yield_points(self: @ContractState, decimals: u32) -> Span<YieldPoint> {
            let oracle_address = self.oracle_address_storage.read();

            let on_keys = IYieldCurveABI::get_on_keys(self);
            let mut on_yield_points = build_on_yield_points(self, on_keys, decimals);

            let pair_ids = IYieldCurveABI::get_pair_ids(self);
            let future_spot_pragma_source_key = self.future_spot_pragma_source_key_storage.read();
            let yield_points = build_future_spot_yield_points(
                self, pair_ids, future_spot_pragma_source_key, decimals, ref on_yield_points
            );
            return yield_points;
        }

        fn get_admin_address(self: @ContractState) -> ContractAddress {
            let state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::get_admin_address(@state)
        }

        fn get_oracle_address(self: @ContractState) -> ContractAddress {
            let oracle_address = self.oracle_address_storage.read();
            return oracle_address;
        }

        fn get_future_spot_pragma_source_key(
            self: @ContractState, pair_id: felt252, future_expiry_timestamp: u64
        ) -> felt252 {
            let future_spot_pragma_source_key = self.future_spot_pragma_source_key_storage.read();
            return future_spot_pragma_source_key;
        }

        fn get_pair_id(self: @ContractState, idx: u64) -> felt252 {
            let pair_id = self.pair_id_storage.read(idx);
            return pair_id;
        }

        fn get_pair_id_is_active(self: @ContractState, pair_id: felt252) -> bool {
            let pair_id_is_active = self.pair_id_is_active_storage.read(pair_id);
            return pair_id_is_active;
        }

        fn get_pair_ids(self: @ContractState) -> Span<felt252> {
            let mut pair_ids = ArrayTrait::<felt252>::new();
            let total_pair_ids_len = self.pair_id_len_storage.read();
            if (total_pair_ids_len == 0) {
                return pair_ids.span();
            }
            let mut cur_idx = 0;
            loop {
                if (cur_idx == total_pair_ids_len.into()) {
                    break ();
                }
                let pair_id = self.pair_id_storage.read(cur_idx);
                let is_active = IYieldCurveABI::get_pair_id_is_active(self, pair_id);
                if (!is_active) {
                    cur_idx = cur_idx + 1;
                    continue;
                }
                pair_ids.append(pair_id);
                cur_idx = cur_idx + 1;
            };
            return pair_ids.span();
        }

        fn get_future_expiry_timestamp(self: @ContractState, pair_id: felt252, idx: u64) -> u64 {
            let future_expiry_timestamp = self.future_expiry_timestamp_storage.read((pair_id, idx));
            return future_expiry_timestamp;
        }

        fn get_future_expiry_timestamps(self: @ContractState, pair_id: felt252) -> Span<u64> {
            let mut future_expiry_timestamps = ArrayTrait::<u64>::new();
            let total_future_expiry_timestamps_len = self
                .future_expiry_timestamp_len_storage
                .read(pair_id);
            if (total_future_expiry_timestamps_len == 0) {
                return future_expiry_timestamps.span();
            }
            let mut cur_idx = 0;
            loop {
                if (cur_idx == total_future_expiry_timestamps_len.into()) {
                    break ();
                }
                let future_expiry_timestamp = IYieldCurveABI::get_future_expiry_timestamp(
                    self, pair_id, cur_idx
                );
                let future_expiry_timestamp_is_active =
                    IYieldCurveABI::get_future_expiry_timestamp_is_active(
                    self, pair_id, future_expiry_timestamp
                );
                if (!future_expiry_timestamp_is_active) {
                    cur_idx = cur_idx + 1;
                    continue;
                }
                future_expiry_timestamps.append(future_expiry_timestamp);
                cur_idx = cur_idx + 1;
            };
            return future_expiry_timestamps.span();
        }


        fn get_on_keys(self: @ContractState) -> Span<felt252> {
            let mut on_keys = ArrayTrait::<felt252>::new();
            let on_key_len = self.on_key_len_storage.read();
            if (on_key_len == 0) {
                return on_keys.span();
            }
            let mut cur_idx = 0;
            loop {
                if (cur_idx == on_key_len) {
                    break ();
                }
                let on_key = IYieldCurveABI::get_on_key(self, cur_idx);
                let on_key_is_active = IYieldCurveABI::get_on_key_is_active(self, on_key);
                if (!on_key_is_active) {
                    cur_idx = cur_idx + 1;
                    continue;
                }
                on_keys.append(on_key);
                cur_idx = cur_idx + 1;
            };
            return on_keys.span();
        }

        fn get_future_expiry_timestamp_status(
            self: @ContractState, pair_id: felt252, future_expiry_timestamp: u64
        ) -> FutureKeyStatus {
            let future_expiry_timestamp_status = self
                .future_expiry_timestamp_status_storage
                .read((pair_id, future_expiry_timestamp));
            return future_expiry_timestamp_status;
        }

        fn get_future_expiry_timestamp_is_active(
            self: @ContractState, pair_id: felt252, future_expiry_timestamp: u64
        ) -> bool {
            let future_expiry_timestamp_status = IYieldCurveABI::get_future_expiry_timestamp_status(
                self, pair_id, future_expiry_timestamp
            );
            let is_active = future_expiry_timestamp_status.is_active;
            return is_active;
        }

        fn get_future_expiry_timestamp_expiry(
            self: @ContractState, pair_id: felt252, future_expiry_timestamp: u64
        ) -> u64 {
            let future_expiry_timestamp_status = IYieldCurveABI::get_future_expiry_timestamp_status(
                self, pair_id, future_expiry_timestamp
            );
            let expiry_timestamp = future_expiry_timestamp_status.expiry_timestamp;
            return expiry_timestamp;
        }


        fn get_on_key(self: @ContractState, idx: u64) -> felt252 {
            let on_key = self.on_key_storage.read(idx);
            return on_key;
        }

        fn get_on_key_is_active(self: @ContractState, on_key: felt252) -> bool {
            let on_key_is_active = self.on_key_is_active_storage.read(on_key);
            return on_key_is_active;
        }
        //
        // Setters
        // 

        fn set_admin_address(ref self: ContractState, new_address: ContractAddress) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let old_admin = Admin::get_admin_address(@state);
            assert(new_address != old_admin, 'Same admin address');
            assert(!new_address.is_zero(), 'Admin address cannot be zero');
            Admin::set_admin_address(ref state, new_address);
            return ();
        }

        fn set_oracle_address(ref self: ContractState, oracle_address: ContractAddress) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            self.oracle_address_storage.write(oracle_address);
            return ();
        }

        fn set_future_spot_pragma_source_key(ref self: ContractState, new_source_key: felt252) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            self.future_spot_pragma_source_key_storage.write(new_source_key);
            return ();
        }

        fn add_pair_id(ref self: ContractState, pair_id: felt252, is_active: bool) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let total_pair_ids_len = self.pair_id_len_storage.read();
            let new_total_pair_ids_len = total_pair_ids_len + 1;
            self.pair_id_len_storage.write(new_total_pair_ids_len);
            self.pair_id_storage.write(total_pair_ids_len.into(), pair_id);
            self.pair_id_is_active_storage.write(pair_id, is_active);
            return ();
        }

        fn set_pair_id_is_active(ref self: ContractState, pair_id: felt252, is_active: bool) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            self.pair_id_is_active_storage.write(pair_id, is_active);
            return ();
        }

        fn add_future_expiry_timestamp(
            ref self: ContractState,
            pair_id: felt252,
            future_expiry_timestamp: u64,
            is_active: bool,
            expiry_timestamp: u64
        ) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let total_future_expiry_timestamps_len = self
                .future_expiry_timestamp_len_storage
                .read(pair_id);

            self
                .future_expiry_timestamp_storage
                .write((pair_id, total_future_expiry_timestamps_len), future_expiry_timestamp);

            let future_expiry_timestamp_status = FutureKeyStatus { is_active, expiry_timestamp };
            self
                .future_expiry_timestamp_status_storage
                .write((pair_id, future_expiry_timestamp), future_expiry_timestamp_status);
            self
                .future_expiry_timestamp_len_storage
                .write(pair_id, total_future_expiry_timestamps_len + 1);

            return ();
        }

        fn set_future_expiry_timestamp_status(
            ref self: ContractState,
            pair_id: felt252,
            future_expiry_timestamp: u64,
            new_future_expiry_timestamp_status: FutureKeyStatus,
        ) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            self
                .future_expiry_timestamp_status_storage
                .write((pair_id, future_expiry_timestamp), new_future_expiry_timestamp_status);
            return ();
        }

        fn set_future_expiry_timestamp_is_active(
            ref self: ContractState,
            pair_id: felt252,
            future_expiry_timestamp: u64,
            new_is_active: bool
        ) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let old_expiry = IYieldCurveABI::get_future_expiry_timestamp_expiry(
                @self, pair_id, future_expiry_timestamp
            );
            let old_expiry = IYieldCurveABI::get_future_expiry_timestamp_expiry(
                @self, pair_id, future_expiry_timestamp
            );
            let new_future_expiry_timestamp_status = FutureKeyStatus {
                is_active: new_is_active, expiry_timestamp: old_expiry
            };
            IYieldCurveABI::set_future_expiry_timestamp_status(
                ref self, pair_id, future_expiry_timestamp, new_future_expiry_timestamp_status
            );
            return ();
        }

        fn add_on_key(ref self: ContractState, on_key: felt252, is_active: bool) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            let on_key_len = self.on_key_len_storage.read();
            self.on_key_storage.write(on_key_len, on_key);
            self.on_key_is_active_storage.write(on_key, is_active);
            self.on_key_len_storage.write(on_key_len + 1);
            return ();
        }

        fn set_on_key_is_active(ref self: ContractState, on_key: felt252, is_active: bool) {
            let mut state: Admin::ContractState = Admin::unsafe_new_contract_state();
            Admin::assert_only_admin(@state);
            self.on_key_is_active_storage.write(on_key, is_active);
            return ();
        }
    }


    fn build_on_yield_points(
        self: @ContractState, on_keys: Span<felt252>, output_decimals: u32
    ) -> Array<YieldPoint> {
        let mut cur_idx = 0;
        let mut yield_points = ArrayTrait::<YieldPoint>::new();
        let oracle_address = self.oracle_address_storage.read();
        let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
        loop {
            if (cur_idx == on_keys.len()) {
                break ();
            }
            let on_key = *on_keys.at(cur_idx);
            let is_active = IYieldCurveABI::get_on_key_is_active(self, on_key);
            if (!is_active) {
                cur_idx = cur_idx + 1;
                continue;
            }
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data(DataType::GenericEntry(on_key), AggregationMode::Median(()));

            if (output.last_updated_timestamp == 0) {
                //No data, skip to the next one 
                cur_idx = cur_idx + 1;
                continue;
            } else {
                let shifted_on_value = change_decimals(
                    self, output.price.low, output.decimals, output_decimals
                );
                yield_points
                    .append(
                        YieldPoint {
                            expiry_timestamp: output.last_updated_timestamp,
                            capture_timestamp: output.last_updated_timestamp,
                            rate: shifted_on_value,
                            source: ON_SOURCE_KEY,
                        }
                    );
                cur_idx = cur_idx + 1;
            };
        };
        return yield_points;
    }

    fn build_future_spot_yield_points(
        self: @ContractState,
        pair_ids: Span<felt252>,
        future_spot_pragma_source_key: felt252,
        output_decimals: u32,
        ref yield_points: Array<YieldPoint>
    ) -> Span<YieldPoint> {
        let mut cur_idx = 0;
        let oracle_address = self.oracle_address_storage.read();
        let oracle_dispatcher = IOracleABIDispatcher { contract_address: oracle_address };
        loop {
            if (cur_idx == pair_ids.len()) {
                break ();
            }
            let pair_id = *pair_ids.at(cur_idx);
            let is_active = IYieldCurveABI::get_pair_id_is_active(self, pair_id);
            if (!is_active) {
                cur_idx = cur_idx + 1;
                continue;
            }
            let spot_decimals = oracle_dispatcher.get_decimals(DataType::SpotEntry(pair_id));
            let spot_entry =
                match oracle_dispatcher
                    .get_data_entry(DataType::SpotEntry(pair_id), future_spot_pragma_source_key) {
                PossibleEntries::Spot(spot_entry) => spot_entry,
                PossibleEntries::Future(_) => {
                    assert(false, 'fetching failed');
                    SpotEntry {
                        base: BaseEntry {
                            timestamp: 0, source: 0, publisher: 0
                        }, price: 0, pair_id: 0, volume: 0
                    }
                },
                PossibleEntries::Generic(_) => {
                    assert(false, 'fetching failed');
                    SpotEntry {
                        base: BaseEntry {
                            timestamp: 0, source: 0, publisher: 0
                        }, price: 0, pair_id: 0, volume: 0
                    }
                },
            };
            if spot_entry.base.timestamp == 0 {
                //No data, skip to the next one 
                cur_idx = cur_idx + 1;
                continue;
            } else {
                let future_expiry_timestamps = IYieldCurveABI::get_future_expiry_timestamps(
                    self, pair_id
                );
                build_future_yield_points(
                    self,
                    future_expiry_timestamps,
                    ref yield_points,
                    future_spot_pragma_source_key,
                    spot_entry,
                    oracle_dispatcher,
                    spot_decimals,
                    output_decimals
                );
                cur_idx = cur_idx + 1;
            };
        };
        return yield_points.span();
    }

    fn build_future_yield_points(
        self: @ContractState,
        future_expiry_timestamps: Span<u64>,
        ref yield_points: Array<YieldPoint>,
        future_spot_pragma_source_key: felt252,
        spot_entry: SpotEntry,
        oracle_dispatcher: IOracleABIDispatcher,
        spot_decimals: u32,
        output_decimals: u32
    ) {
        let mut cur_idx = 0;
        loop {
            if (cur_idx == future_expiry_timestamps.len()) {
                break ();
            }
            let future_expiry_timestamp = *future_expiry_timestamps.at(cur_idx);
            let future_expiry_timestamp_status = IYieldCurveABI::get_future_expiry_timestamp_status(
                self, spot_entry.pair_id, future_expiry_timestamp
            );
            if (!future_expiry_timestamp_status.is_active) {
                cur_idx = cur_idx + 1;
                continue;
            }
            let mut future_decimals = oracle_dispatcher
                .get_decimals(DataType::FutureEntry((spot_entry.pair_id, future_expiry_timestamp)));
            if (future_decimals == 0) {
                future_decimals = DEFAULT_DECIMALS;
            }
            let future_entry =
                match oracle_dispatcher
                    .get_data_entry(
                        DataType::FutureEntry((spot_entry.pair_id, future_expiry_timestamp)),
                        future_spot_pragma_source_key
                    ) {
                PossibleEntries::Spot(_) => {
                    assert(false, 'fetching failed');
                    FutureEntry {
                        base: BaseEntry {
                            timestamp: 0, source: 0, publisher: 0
                        }, price: 0, pair_id: 0, volume: 0, expiration_timestamp: 0
                    }
                },
                PossibleEntries::Future(future_entry) => future_entry,
                PossibleEntries::Generic(generic_entry) => {
                    assert(false, 'fetching failed');
                    FutureEntry {
                        base: BaseEntry {
                            timestamp: 0, source: 0, publisher: 0
                        }, price: 0, pair_id: 0, volume: 0, expiration_timestamp: 0
                    }
                }
            };

            if future_entry.base.timestamp == 0 {
                cur_idx = cur_idx + 1;
                continue;
            }

            if future_entry.base.timestamp != spot_entry.base.timestamp {
                cur_idx = cur_idx + 1;
                continue;
            }
            let yield_point = calculate_future_spot_yield_point(
                future_entry,
                future_expiry_timestamp_status.expiry_timestamp,
                spot_entry,
                spot_decimals,
                future_decimals,
                output_decimals
            );

            yield_points.append(yield_point);
            cur_idx = cur_idx + 1;
        };
    }

    fn calculate_future_spot_yield_point(
        future_entry: FutureEntry,
        future_expiry_timestamp: u64,
        spot_entry: SpotEntry,
        spot_decimals: u32,
        future_decimals: u32,
        output_decimals: u32
    ) -> YieldPoint {
        let mut time_scaled_value = 0;
        if (future_entry.price > spot_entry.price) {
            let current_timestamp = starknet::get_block_timestamp();
            assert(future_expiry_timestamp > current_timestamp, 'YieldCurve: future expired');
            let seconds_to_expiry = future_expiry_timestamp - current_timestamp;
            let decimals_multiplier = fpow(10, output_decimals.into());
            let time_multiplier: u128 = (SECONDS_IN_YEAR.into() * decimals_multiplier)
                / seconds_to_expiry.into();
            // log of big prime is 75.5. making sure ratio multiplier is within bounds.
            let exponent_limit = 75;
            let mut shifted_ratio = 0;
            if (future_decimals <= output_decimals
                + spot_decimals) { // Shift future/spot to the left by output_decimals + spot_decimals - future_decimals
                let exponent = output_decimals + spot_decimals - future_decimals;
                assert(exponent <= exponent_limit, 'YieldCurve: Decimals OO range');
                let ratio_multiplier = fpow(10, exponent.into());
                //TURNED THE U256 PRICE INTO U128: MAYBE CONSIDER USING ONLY U128 PRICES FOR NOW, FOR COMPUTATIONAL PURPOSES
                shifted_ratio = (future_entry.price.low * ratio_multiplier) / spot_entry.price.low;
            } else {
                // Shift future/spot to the right by -1 * (output_decimals + spot_decimals - future_decimals)
                let exponent = future_decimals - output_decimals - spot_decimals;
                assert(exponent <= exponent_limit, 'YieldCurve: Decimals OO range');
                let ratio_multiplier = fpow(10, exponent.into());
                shifted_ratio = (future_entry.price.low)
                    / (spot_entry.price.low * ratio_multiplier);
            }
            let interest_ratio = shifted_ratio - decimals_multiplier;
            time_scaled_value = (interest_ratio * time_multiplier) / decimals_multiplier
        }
        let yield_point = YieldPoint {
            expiry_timestamp: future_expiry_timestamp,
            capture_timestamp: future_entry.base.timestamp,
            rate: time_scaled_value,
            source: FUTURE_SPOT_SOURCE_KEY,
        };
        return yield_point;
    }
    fn change_decimals(
        self: @ContractState, value: u128, old_decimals: u32, new_decimals: u32
    ) -> u128 {
        if (old_decimals <= new_decimals) {
            // Multiply on_entry by 10 ^ (new_decimals - old_decimals)
            // which is guaranteed to be an integer > 0 by the if statement
            let shift_by = fpow(10, (new_decimals - old_decimals).into());
            let shifted_value = value * shift_by;
            return shifted_value;
        } else {
            // Divide on_entry by 10 ^ (old_decimals - new_decimals)
            // Doing the same operation as in the last branch, so
            // changed both multiplication/division and sign of the exponent
            let shift_by = fpow(10, (old_decimals - new_decimals).into());
            let shifted_value = value / shift_by;
            return shifted_value;
        }
    }
}
