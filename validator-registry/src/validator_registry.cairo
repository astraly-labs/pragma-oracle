use starknet::ContractAddress;

// Publisher statuses returned by `get_publisher_status`.
pub const STATUS_ACTIVE: felt252 = 'ACTIVE';
pub const STATUS_PAUSED: felt252 = 'PAUSED';
pub const STATUS_NOT_BOUND: felt252 = 'NOT_BOUND';
pub const STATUS_SUSPENDED: felt252 = 'SUSPENDED';
pub const STATUS_NOT_STAKER: felt252 = 'NOT_STAKER';
pub const STATUS_EXITING: felt252 = 'EXITING';
pub const STATUS_LOW_SELF_STAKE: felt252 = 'LOW_SELF_STAKE';
pub const STATUS_KEY_REUSED: felt252 = 'KEY_REUSED';

// Revocation reasons emitted in `OracleSignerRevoked`, besides the prunable statuses.
pub const REASON_STAKER: felt252 = 'BY_STAKER';
pub const REASON_SIGNER: felt252 = 'BY_SIGNER';

// Shadow-pilot publisher registry for Starknet validators (DP-PRA-381, scope C).
// A publisher is identified by its staker address (`publisher == staker_address.into()`)
// and publishes from a dedicated oracle signer account, distinct from the staker,
// reward and operational addresses. The binding mirrors the staking contract's
// operational address flow: the signer declares, the staker confirms.
// Exposes the IPublisherRegistryABI views the Oracle relies on, so an already declared,
// unmodified Oracle class can be deployed on top of it.
#[starknet::interface]
pub trait IValidatorRegistry<TContractState> {
    // IPublisherRegistryABI-compatible views
    fn get_publisher_address(self: @TContractState, publisher: felt252) -> ContractAddress;
    fn can_publish_source(self: @TContractState, publisher: felt252, source: felt252) -> bool;
    fn get_publisher_sources(self: @TContractState, publisher: felt252) -> Array<felt252>;
    fn get_all_publishers(self: @TContractState) -> Array<felt252>;
    fn get_admin_address(self: @TContractState) -> ContractAddress;

    // Validator flow
    fn declare_oracle_signer(ref self: TContractState, staker_address: ContractAddress);
    fn bind_oracle_signer(ref self: TContractState, oracle_signer: ContractAddress);
    fn revoke_oracle_signer(ref self: TContractState, staker_address: ContractAddress);
    fn prune(ref self: TContractState, staker_address: ContractAddress);

    // Views
    fn get_oracle_signer(self: @TContractState, staker_address: ContractAddress) -> ContractAddress;
    fn get_staker_for_signer(
        self: @TContractState, oracle_signer: ContractAddress,
    ) -> ContractAddress;
    fn get_declared_staker(
        self: @TContractState, oracle_signer: ContractAddress,
    ) -> ContractAddress;
    fn get_publisher_status(self: @TContractState, staker_address: ContractAddress) -> felt252;
    fn get_allowed_sources(self: @TContractState) -> Array<felt252>;
    fn get_min_self_stake(self: @TContractState) -> u128;
    fn get_staking_contract(self: @TContractState) -> ContractAddress;
    fn is_paused(self: @TContractState) -> bool;
    fn is_suspended(self: @TContractState, staker_address: ContractAddress) -> bool;

    // Admin
    fn set_allowed_sources(ref self: TContractState, sources: Span<felt252>);
    fn set_min_self_stake(ref self: TContractState, min_self_stake: u128);
    fn set_suspended(ref self: TContractState, staker_address: ContractAddress, suspended: bool);
    fn set_paused(ref self: TContractState, paused: bool);
    fn set_admin_address(ref self: TContractState, new_admin_address: ContractAddress);
}

#[starknet::contract]
pub mod ValidatorRegistry {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::staking::{IStakingDispatcher, IStakingDispatcherTrait, StakerInfoV1};
    use super::{
        IValidatorRegistry, REASON_SIGNER, REASON_STAKER, STATUS_ACTIVE, STATUS_EXITING,
        STATUS_KEY_REUSED, STATUS_LOW_SELF_STAKE, STATUS_NOT_BOUND, STATUS_NOT_STAKER,
        STATUS_PAUSED, STATUS_SUSPENDED,
    };

    #[storage]
    struct Storage {
        admin: ContractAddress,
        staking_contract: ContractAddress,
        min_self_stake: u128,
        paused: bool,
        staker_to_signer: Map<ContractAddress, ContractAddress>,
        signer_to_staker: Map<ContractAddress, ContractAddress>,
        declared_staker: Map<ContractAddress, ContractAddress>,
        suspended: Map<ContractAddress, bool>,
        publishers_len: u32,
        publishers: Map<u32, felt252>,
        // index + 1, 0 means absent
        publisher_position: Map<felt252, u32>,
        allowed_sources_len: u32,
        allowed_sources: Map<u32, felt252>,
        is_allowed_source: Map<felt252, bool>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OracleSignerDeclared {
        pub oracle_signer: ContractAddress,
        pub staker_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OracleSignerBound {
        pub staker_address: ContractAddress,
        pub old_signer: ContractAddress,
        pub new_signer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OracleSignerRevoked {
        pub staker_address: ContractAddress,
        pub oracle_signer: ContractAddress,
        pub reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AllowedSourcesUpdated {
        pub sources: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinSelfStakeUpdated {
        pub min_self_stake: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SuspensionUpdated {
        pub staker_address: ContractAddress,
        pub suspended: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PauseUpdated {
        pub paused: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransferOwnership {
        pub old_address: ContractAddress,
        pub new_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OracleSignerDeclared: OracleSignerDeclared,
        OracleSignerBound: OracleSignerBound,
        OracleSignerRevoked: OracleSignerRevoked,
        AllowedSourcesUpdated: AllowedSourcesUpdated,
        MinSelfStakeUpdated: MinSelfStakeUpdated,
        SuspensionUpdated: SuspensionUpdated,
        PauseUpdated: PauseUpdated,
        TransferOwnership: TransferOwnership,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin_address: ContractAddress,
        staking_contract: ContractAddress,
        min_self_stake: u128,
        allowed_sources: Span<felt252>,
    ) {
        assert(!admin_address.is_zero(), 'Admin address cannot be zero');
        assert(!staking_contract.is_zero(), 'Staking address cannot be zero');
        self.admin.write(admin_address);
        self.staking_contract.write(staking_contract);
        self.min_self_stake.write(min_self_stake);
        self._write_allowed_sources(allowed_sources);
    }

    #[abi(embed_v0)]
    impl ValidatorRegistryImpl of IValidatorRegistry<ContractState> {
        // @notice signer address for an active publisher, zero otherwise
        // @dev the Oracle rejects entries from a zero publisher address, which makes
        //      exit, low self-stake, key reuse, suspension and pause effective on the next publish
        fn get_publisher_address(self: @ContractState, publisher: felt252) -> ContractAddress {
            let staker_address = match publisher_to_staker(publisher) {
                Option::Some(staker_address) => staker_address,
                Option::None => { return Zero::zero(); },
            };
            if self._status(staker_address) != STATUS_ACTIVE {
                return Zero::zero();
            }
            self.staker_to_signer.read(staker_address)
        }

        fn can_publish_source(self: @ContractState, publisher: felt252, source: felt252) -> bool {
            if self.publisher_position.read(publisher) == 0 {
                return false;
            }
            self.is_allowed_source.read(source)
        }

        fn get_publisher_sources(self: @ContractState, publisher: felt252) -> Array<felt252> {
            if self.publisher_position.read(publisher) == 0 {
                return array![];
            }
            self.get_allowed_sources()
        }

        fn get_all_publishers(self: @ContractState) -> Array<felt252> {
            let mut publishers = array![];
            for idx in 0..self.publishers_len.read() {
                publishers.append(self.publishers.read(idx));
            }
            publishers
        }

        fn get_admin_address(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        // @notice step 1, called by the new oracle signer account
        fn declare_oracle_signer(ref self: ContractState, staker_address: ContractAddress) {
            let oracle_signer = get_caller_address();
            assert(!oracle_signer.is_zero(), 'Caller cannot be zero');
            assert(!staker_address.is_zero(), 'Staker cannot be zero');
            assert(oracle_signer != staker_address, 'Signer cannot be the staker');
            assert(self.signer_to_staker.read(oracle_signer).is_zero(), 'Signer already bound');
            self.declared_staker.write(oracle_signer, staker_address);
            self.emit(OracleSignerDeclared { oracle_signer, staker_address });
        }

        // @notice step 2, called by the staker address; also rotates an existing signer
        fn bind_oracle_signer(ref self: ContractState, oracle_signer: ContractAddress) {
            let staker_address = get_caller_address();
            assert(!self.paused.read(), 'Registry is paused');
            assert(!oracle_signer.is_zero(), 'Signer cannot be zero');
            assert(oracle_signer != staker_address, 'Signer cannot be the staker');
            assert(
                self.declared_staker.read(oracle_signer) == staker_address, 'Signer not declared',
            );
            assert(self.signer_to_staker.read(oracle_signer).is_zero(), 'Signer already bound');

            let info = match self._staker_info(staker_address) {
                Option::Some(info) => info,
                Option::None => { core::panic_with_felt252('Caller is not a staker') },
            };
            assert(info.unstake_time.is_none(), 'Staker is exiting');
            assert(info.amount_own >= self.min_self_stake.read(), 'Self stake below minimum');
            assert(oracle_signer != info.operational_address, 'Signer is operational address');
            assert(oracle_signer != info.reward_address, 'Signer is reward address');

            let old_signer = self.staker_to_signer.read(staker_address);
            if old_signer.is_zero() {
                self._add_publisher(staker_address.into());
            } else {
                self.signer_to_staker.write(old_signer, Zero::zero());
            }
            self.staker_to_signer.write(staker_address, oracle_signer);
            self.signer_to_staker.write(oracle_signer, staker_address);
            self.declared_staker.write(oracle_signer, Zero::zero());
            self.emit(OracleSignerBound { staker_address, old_signer, new_signer: oracle_signer });
        }

        // @notice callable by the staker or by its current oracle signer (emergency kill)
        fn revoke_oracle_signer(ref self: ContractState, staker_address: ContractAddress) {
            let caller = get_caller_address();
            let oracle_signer = self.staker_to_signer.read(staker_address);
            assert(!oracle_signer.is_zero(), 'No signer bound');
            let reason = if caller == staker_address {
                REASON_STAKER
            } else {
                assert(caller == oracle_signer, 'Caller cannot revoke');
                REASON_SIGNER
            };
            self._unbind(staker_address, oracle_signer, reason);
        }

        // @notice permissionless cleanup of publishers that can never publish again as is
        fn prune(ref self: ContractState, staker_address: ContractAddress) {
            let oracle_signer = self.staker_to_signer.read(staker_address);
            assert(!oracle_signer.is_zero(), 'No signer bound');
            let status = self._staking_status(staker_address, oracle_signer);
            assert(
                status == STATUS_NOT_STAKER
                    || status == STATUS_EXITING
                    || status == STATUS_KEY_REUSED,
                'Publisher not prunable',
            );
            self._unbind(staker_address, oracle_signer, status);
        }

        fn get_oracle_signer(
            self: @ContractState, staker_address: ContractAddress,
        ) -> ContractAddress {
            self.staker_to_signer.read(staker_address)
        }

        fn get_staker_for_signer(
            self: @ContractState, oracle_signer: ContractAddress,
        ) -> ContractAddress {
            self.signer_to_staker.read(oracle_signer)
        }

        fn get_declared_staker(
            self: @ContractState, oracle_signer: ContractAddress,
        ) -> ContractAddress {
            self.declared_staker.read(oracle_signer)
        }

        fn get_publisher_status(self: @ContractState, staker_address: ContractAddress) -> felt252 {
            self._status(staker_address)
        }

        fn get_allowed_sources(self: @ContractState) -> Array<felt252> {
            let mut sources = array![];
            for idx in 0..self.allowed_sources_len.read() {
                sources.append(self.allowed_sources.read(idx));
            }
            sources
        }

        fn get_min_self_stake(self: @ContractState) -> u128 {
            self.min_self_stake.read()
        }

        fn get_staking_contract(self: @ContractState) -> ContractAddress {
            self.staking_contract.read()
        }

        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn is_suspended(self: @ContractState, staker_address: ContractAddress) -> bool {
            self.suspended.read(staker_address)
        }

        fn set_allowed_sources(ref self: ContractState, sources: Span<felt252>) {
            self._assert_only_admin();
            for idx in 0..self.allowed_sources_len.read() {
                self.is_allowed_source.write(self.allowed_sources.read(idx), false);
                self.allowed_sources.write(idx, 0);
            }
            self._write_allowed_sources(sources);
        }

        fn set_min_self_stake(ref self: ContractState, min_self_stake: u128) {
            self._assert_only_admin();
            self.min_self_stake.write(min_self_stake);
            self.emit(MinSelfStakeUpdated { min_self_stake });
        }

        fn set_suspended(
            ref self: ContractState, staker_address: ContractAddress, suspended: bool,
        ) {
            self._assert_only_admin();
            self.suspended.write(staker_address, suspended);
            self.emit(SuspensionUpdated { staker_address, suspended });
        }

        fn set_paused(ref self: ContractState, paused: bool) {
            self._assert_only_admin();
            self.paused.write(paused);
            self.emit(PauseUpdated { paused });
        }

        fn set_admin_address(ref self: ContractState, new_admin_address: ContractAddress) {
            let old_admin = self.admin.read();
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Caller is the zero address');
            assert(caller == old_admin, 'Caller is not the owner');
            assert(new_admin_address != old_admin, 'Same admin address');
            assert(!new_admin_address.is_zero(), 'Admin address cannot be zero');
            self.admin.write(new_admin_address);
            self.emit(TransferOwnership { old_address: old_admin, new_address: new_admin_address });
        }
    }

    fn publisher_to_staker(publisher: felt252) -> Option<ContractAddress> {
        let staker_address: ContractAddress = publisher.try_into()?;
        if staker_address.is_zero() {
            return Option::None;
        }
        Option::Some(staker_address)
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_only_admin(self: @ContractState) {
            assert(get_caller_address() == self.admin.read(), 'Admin: unauthorized');
        }

        fn _staker_info(
            self: @ContractState, staker_address: ContractAddress,
        ) -> Option<StakerInfoV1> {
            IStakingDispatcher { contract_address: self.staking_contract.read() }
                .get_staker_info_v1(staker_address)
        }

        fn _status(self: @ContractState, staker_address: ContractAddress) -> felt252 {
            if self.paused.read() {
                return STATUS_PAUSED;
            }
            let oracle_signer = self.staker_to_signer.read(staker_address);
            if oracle_signer.is_zero() {
                return STATUS_NOT_BOUND;
            }
            if self.suspended.read(staker_address) {
                return STATUS_SUSPENDED;
            }
            self._staking_status(staker_address, oracle_signer)
        }

        // @dev status derived from the staking contract only, for a bound staker
        fn _staking_status(
            self: @ContractState, staker_address: ContractAddress, oracle_signer: ContractAddress,
        ) -> felt252 {
            let info = match self._staker_info(staker_address) {
                Option::Some(info) => info,
                Option::None => { return STATUS_NOT_STAKER; },
            };
            if info.unstake_time.is_some() {
                return STATUS_EXITING;
            }
            if oracle_signer == info.operational_address || oracle_signer == info.reward_address {
                return STATUS_KEY_REUSED;
            }
            if info.amount_own < self.min_self_stake.read() {
                return STATUS_LOW_SELF_STAKE;
            }
            STATUS_ACTIVE
        }

        fn _unbind(
            ref self: ContractState,
            staker_address: ContractAddress,
            oracle_signer: ContractAddress,
            reason: felt252,
        ) {
            self.staker_to_signer.write(staker_address, Zero::zero());
            self.signer_to_staker.write(oracle_signer, Zero::zero());
            self._remove_publisher(staker_address.into());
            self.emit(OracleSignerRevoked { staker_address, oracle_signer, reason });
        }

        fn _add_publisher(ref self: ContractState, publisher: felt252) {
            let len = self.publishers_len.read();
            self.publishers.write(len, publisher);
            self.publisher_position.write(publisher, len + 1);
            self.publishers_len.write(len + 1);
        }

        fn _remove_publisher(ref self: ContractState, publisher: felt252) {
            let position = self.publisher_position.read(publisher);
            if position == 0 {
                return;
            }
            let idx = position - 1;
            let last_idx = self.publishers_len.read() - 1;
            if idx != last_idx {
                let last_publisher = self.publishers.read(last_idx);
                self.publishers.write(idx, last_publisher);
                self.publisher_position.write(last_publisher, position);
            }
            self.publishers.write(last_idx, 0);
            self.publisher_position.write(publisher, 0);
            self.publishers_len.write(last_idx);
        }

        fn _write_allowed_sources(ref self: ContractState, sources: Span<felt252>) {
            let mut written = 0_u32;
            for source in sources {
                let source = *source;
                assert(source != 0, 'Source cannot be zero');
                if !self.is_allowed_source.read(source) {
                    self.is_allowed_source.write(source, true);
                    self.allowed_sources.write(written, source);
                    written += 1;
                }
            }
            self.allowed_sources_len.write(written);
            self.emit(AllowedSourcesUpdated { sources });
        }
    }
}
