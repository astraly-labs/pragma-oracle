use starknet::ContractAddress;

// Publisher statuses returned by `get_publisher_status`.
const STATUS_ACTIVE: felt252 = 'ACTIVE';
const STATUS_PAUSED: felt252 = 'PAUSED';
const STATUS_NOT_BOUND: felt252 = 'NOT_BOUND';
const STATUS_SUSPENDED: felt252 = 'SUSPENDED';
const STATUS_NOT_STAKER: felt252 = 'NOT_STAKER';
const STATUS_EXITING: felt252 = 'EXITING';
const STATUS_LOW_SELF_STAKE: felt252 = 'LOW_SELF_STAKE';
const STATUS_KEY_REUSED: felt252 = 'KEY_REUSED';

// Revocation reasons emitted in `OracleSignerRevoked`, besides the prunable statuses.
const REASON_STAKER: felt252 = 'BY_STAKER';
const REASON_SIGNER: felt252 = 'BY_SIGNER';

// Shadow-pilot publisher registry for Starknet validators (DP-PRA-381, scope C).
// A publisher is identified by its staker address (`publisher == staker_address.into()`)
// and publishes from a dedicated oracle signer account, distinct from the staker,
// reward and operational addresses. The binding mirrors the staking contract's
// operational address flow: the signer declares, the staker confirms.
// Exposes the IPublisherRegistryABI views the Oracle relies on, so an unmodified
// Oracle class can be deployed on top of it.
#[starknet::interface]
trait IValidatorRegistry<TContractState> {
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
        self: @TContractState, oracle_signer: ContractAddress
    ) -> ContractAddress;
    fn get_declared_staker(
        self: @TContractState, oracle_signer: ContractAddress
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
mod ValidatorRegistry {
    use starknet::{ContractAddress, get_caller_address};
    use zeroable::Zeroable;
    use option::OptionTrait;
    use array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto};
    use pragma::admin::admin::Ownable;
    use pragma::validator_registry::staking::{
        IStakingDispatcher, IStakingDispatcherTrait, StakerInfoV1
    };
    use super::{
        IValidatorRegistry, STATUS_ACTIVE, STATUS_PAUSED, STATUS_NOT_BOUND, STATUS_SUSPENDED,
        STATUS_NOT_STAKER, STATUS_EXITING, STATUS_LOW_SELF_STAKE, STATUS_KEY_REUSED, REASON_STAKER,
        REASON_SIGNER
    };

    #[storage]
    struct Storage {
        staking_contract: ContractAddress,
        min_self_stake: u128,
        paused: bool,
        staker_to_signer: LegacyMap::<ContractAddress, ContractAddress>,
        signer_to_staker: LegacyMap::<ContractAddress, ContractAddress>,
        declared_staker: LegacyMap::<ContractAddress, ContractAddress>,
        suspended: LegacyMap::<ContractAddress, bool>,
        publishers_len: usize,
        publishers: LegacyMap::<usize, felt252>,
        // index + 1, 0 means absent
        publisher_position: LegacyMap::<felt252, usize>,
        allowed_sources_len: usize,
        allowed_sources: LegacyMap::<usize, felt252>,
        is_allowed_source: LegacyMap::<felt252, bool>,
    }

    #[derive(Drop, starknet::Event)]
    struct OracleSignerDeclared {
        oracle_signer: ContractAddress,
        staker_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct OracleSignerBound {
        staker_address: ContractAddress,
        old_signer: ContractAddress,
        new_signer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct OracleSignerRevoked {
        staker_address: ContractAddress,
        oracle_signer: ContractAddress,
        reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AllowedSourcesUpdated {
        sources: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct MinSelfStakeUpdated {
        min_self_stake: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct SuspensionUpdated {
        staker_address: ContractAddress,
        suspended: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct PauseUpdated {
        paused: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferOwnership {
        old_address: ContractAddress,
        new_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
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
        allowed_sources: Span<felt252>
    ) {
        assert(!admin_address.is_zero(), 'Admin address cannot be zero');
        assert(!staking_contract.is_zero(), 'Staking address cannot be zero');
        let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref state, admin_address);
        self.staking_contract.write(staking_contract);
        self.min_self_stake.write(min_self_stake);
        _write_allowed_sources(ref self, allowed_sources);
    }

    #[external(v0)]
    impl ValidatorRegistryImpl of IValidatorRegistry<ContractState> {
        // @notice signer address for an active publisher, zero otherwise
        // @dev the Oracle rejects entries from a zero publisher address, which makes
        //      exit, low self-stake, key reuse, suspension and pause effective on the next publish
        fn get_publisher_address(self: @ContractState, publisher: felt252) -> ContractAddress {
            let staker_address = match _publisher_to_staker(publisher) {
                Option::Some(staker_address) => staker_address,
                Option::None(_) => {
                    return Zeroable::zero();
                },
            };
            if _status(self, staker_address) != STATUS_ACTIVE {
                return Zeroable::zero();
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
                return ArrayTrait::new();
            }
            ValidatorRegistryImpl::get_allowed_sources(self)
        }

        fn get_all_publishers(self: @ContractState) -> Array<felt252> {
            let len = self.publishers_len.read();
            let mut publishers = ArrayTrait::new();
            let mut idx = 0_usize;
            loop {
                if idx == len {
                    break ();
                }
                publishers.append(self.publishers.read(idx));
                idx += 1;
            };
            publishers
        }

        fn get_admin_address(self: @ContractState) -> ContractAddress {
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::owner(@state)
        }

        // @notice step 1, called by the new oracle signer account
        fn declare_oracle_signer(ref self: ContractState, staker_address: ContractAddress) {
            let oracle_signer = get_caller_address();
            assert(!oracle_signer.is_zero(), 'Caller cannot be zero');
            assert(!staker_address.is_zero(), 'Staker cannot be zero');
            assert(oracle_signer != staker_address, 'Signer cannot be the staker');
            assert(self.signer_to_staker.read(oracle_signer).is_zero(), 'Signer already bound');
            self.declared_staker.write(oracle_signer, staker_address);
            self
                .emit(
                    Event::OracleSignerDeclared(
                        OracleSignerDeclared { oracle_signer, staker_address }
                    )
                );
        }

        // @notice step 2, called by the staker address; also rotates an existing signer
        fn bind_oracle_signer(ref self: ContractState, oracle_signer: ContractAddress) {
            let staker_address = get_caller_address();
            assert(!self.paused.read(), 'Registry is paused');
            assert(!oracle_signer.is_zero(), 'Signer cannot be zero');
            assert(oracle_signer != staker_address, 'Signer cannot be the staker');
            assert(
                self.declared_staker.read(oracle_signer) == staker_address, 'Signer not declared'
            );
            assert(self.signer_to_staker.read(oracle_signer).is_zero(), 'Signer already bound');

            let info = match _staker_info(@self, staker_address) {
                Option::Some(info) => info,
                Option::None(_) => {
                    panic_with_felt252('Caller is not a staker')
                },
            };
            assert(info.unstake_time.is_none(), 'Staker is exiting');
            assert(info.amount_own >= self.min_self_stake.read(), 'Self stake below minimum');
            assert(oracle_signer != info.operational_address, 'Signer is operational address');
            assert(oracle_signer != info.reward_address, 'Signer is reward address');

            let old_signer = self.staker_to_signer.read(staker_address);
            if old_signer.is_zero() {
                _add_publisher(ref self, staker_address.into());
            } else {
                self.signer_to_staker.write(old_signer, Zeroable::zero());
            }
            self.staker_to_signer.write(staker_address, oracle_signer);
            self.signer_to_staker.write(oracle_signer, staker_address);
            self.declared_staker.write(oracle_signer, Zeroable::zero());
            self
                .emit(
                    Event::OracleSignerBound(
                        OracleSignerBound { staker_address, old_signer, new_signer: oracle_signer }
                    )
                );
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
            _unbind(ref self, staker_address, oracle_signer, reason);
        }

        // @notice permissionless cleanup of publishers that can never publish again as is
        fn prune(ref self: ContractState, staker_address: ContractAddress) {
            let oracle_signer = self.staker_to_signer.read(staker_address);
            assert(!oracle_signer.is_zero(), 'No signer bound');
            let status = _staking_status(@self, staker_address, oracle_signer);
            assert(
                status == STATUS_NOT_STAKER
                    || status == STATUS_EXITING
                    || status == STATUS_KEY_REUSED,
                'Publisher not prunable'
            );
            _unbind(ref self, staker_address, oracle_signer, status);
        }

        fn get_oracle_signer(
            self: @ContractState, staker_address: ContractAddress
        ) -> ContractAddress {
            self.staker_to_signer.read(staker_address)
        }

        fn get_staker_for_signer(
            self: @ContractState, oracle_signer: ContractAddress
        ) -> ContractAddress {
            self.signer_to_staker.read(oracle_signer)
        }

        fn get_declared_staker(
            self: @ContractState, oracle_signer: ContractAddress
        ) -> ContractAddress {
            self.declared_staker.read(oracle_signer)
        }

        fn get_publisher_status(self: @ContractState, staker_address: ContractAddress) -> felt252 {
            _status(self, staker_address)
        }

        fn get_allowed_sources(self: @ContractState) -> Array<felt252> {
            let len = self.allowed_sources_len.read();
            let mut sources = ArrayTrait::new();
            let mut idx = 0_usize;
            loop {
                if idx == len {
                    break ();
                }
                sources.append(self.allowed_sources.read(idx));
                idx += 1;
            };
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
            assert_only_admin();
            let len = self.allowed_sources_len.read();
            let mut idx = 0_usize;
            loop {
                if idx == len {
                    break ();
                }
                self.is_allowed_source.write(self.allowed_sources.read(idx), false);
                self.allowed_sources.write(idx, 0);
                idx += 1;
            };
            _write_allowed_sources(ref self, sources);
        }

        fn set_min_self_stake(ref self: ContractState, min_self_stake: u128) {
            assert_only_admin();
            self.min_self_stake.write(min_self_stake);
            self.emit(Event::MinSelfStakeUpdated(MinSelfStakeUpdated { min_self_stake }));
        }

        fn set_suspended(
            ref self: ContractState, staker_address: ContractAddress, suspended: bool
        ) {
            assert_only_admin();
            self.suspended.write(staker_address, suspended);
            self.emit(Event::SuspensionUpdated(SuspensionUpdated { staker_address, suspended }));
        }

        fn set_paused(ref self: ContractState, paused: bool) {
            assert_only_admin();
            self.paused.write(paused);
            self.emit(Event::PauseUpdated(PauseUpdated { paused }));
        }

        fn set_admin_address(ref self: ContractState, new_admin_address: ContractAddress) {
            let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::assert_only_owner(@state);
            let old_admin = Ownable::OwnableImpl::owner(@state);
            assert(new_admin_address != old_admin, 'Same admin address');
            assert(!new_admin_address.is_zero(), 'Admin address cannot be zero');
            Ownable::OwnableImpl::transfer_ownership(ref state, new_admin_address);
            self
                .emit(
                    Event::TransferOwnership(
                        TransferOwnership { old_address: old_admin, new_address: new_admin_address }
                    )
                );
        }
    }

    fn assert_only_admin() {
        let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        let admin = Ownable::OwnableImpl::owner(@state);
        assert(get_caller_address() == admin, 'Admin: unauthorized');
    }

    fn _publisher_to_staker(publisher: felt252) -> Option<ContractAddress> {
        let staker_address: ContractAddress = publisher.try_into()?;
        if staker_address.is_zero() {
            return Option::None(());
        }
        Option::Some(staker_address)
    }

    fn _staker_info(self: @ContractState, staker_address: ContractAddress) -> Option<StakerInfoV1> {
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
        _staking_status(self, staker_address, oracle_signer)
    }

    // @dev status derived from the staking contract only, for a bound staker
    fn _staking_status(
        self: @ContractState, staker_address: ContractAddress, oracle_signer: ContractAddress
    ) -> felt252 {
        let info = match _staker_info(self, staker_address) {
            Option::Some(info) => info,
            Option::None(_) => {
                return STATUS_NOT_STAKER;
            },
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
        reason: felt252
    ) {
        self.staker_to_signer.write(staker_address, Zeroable::zero());
        self.signer_to_staker.write(oracle_signer, Zeroable::zero());
        _remove_publisher(ref self, staker_address.into());
        self
            .emit(
                Event::OracleSignerRevoked(
                    OracleSignerRevoked { staker_address, oracle_signer, reason }
                )
            );
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
            return ();
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
        let mut idx = 0_usize;
        let mut written = 0_usize;
        loop {
            if idx == sources.len() {
                break ();
            }
            let source = *sources.at(idx);
            assert(source != 0, 'Source cannot be zero');
            if !self.is_allowed_source.read(source) {
                self.is_allowed_source.write(source, true);
                self.allowed_sources.write(written, source);
                written += 1;
            }
            idx += 1;
        };
        self.allowed_sources_len.write(written);
        self.emit(Event::AllowedSourcesUpdated(AllowedSourcesUpdated { sources }));
    }
}
