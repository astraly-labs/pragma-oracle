use core::num::traits::Zero;
use starknet::syscalls::deploy_syscall;
use starknet::testing::{set_block_timestamp, set_contract_address};
use starknet::{ContractAddress, SyscallResultTrait};
use crate::mock_staking::{IMockStakingDispatcher, IMockStakingDispatcherTrait, MockStaking};
use crate::validator_registry::{
    IValidatorRegistryDispatcher, IValidatorRegistryDispatcherTrait, STATUS_ACTIVE, STATUS_EXITING,
    STATUS_KEY_REUSED, STATUS_LOW_SELF_STAKE, STATUS_NOT_BOUND, STATUS_NOT_STAKER, STATUS_PAUSED,
    STATUS_SUSPENDED, ValidatorRegistry,
};

const MIN_SELF_STAKE: u128 = 20000;
const SELF_STAKE: u128 = 25000;
const BLOCK_TIMESTAMP: u64 = 103374042;

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
fn admin() -> ContractAddress {
    addr(0x12345)
}
fn staker() -> ContractAddress {
    addr(0xa11ce)
}
fn reward() -> ContractAddress {
    addr(0xbeef)
}
fn operational() -> ContractAddress {
    addr(0x0fe1)
}
fn signer() -> ContractAddress {
    addr(0x5161)
}
fn other_signer() -> ContractAddress {
    addr(0x5162)
}
fn other_staker() -> ContractAddress {
    addr(0xb0b)
}
fn stranger() -> ContractAddress {
    addr(0x98765)
}

fn setup() -> (IValidatorRegistryDispatcher, IMockStakingDispatcher) {
    set_block_timestamp(BLOCK_TIMESTAMP);
    set_contract_address(admin());
    let (staking_address, _) = deploy_syscall(
        MockStaking::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), true,
    )
        .unwrap_syscall();
    let staking = IMockStakingDispatcher { contract_address: staking_address };
    staking.set_staker(staker(), reward(), operational(), SELF_STAKE);
    staking.set_staker(other_staker(), addr(0xbeef2), addr(0x0fe2), SELF_STAKE);

    let mut calldata = array![];
    admin().serialize(ref calldata);
    staking_address.serialize(ref calldata);
    MIN_SELF_STAKE.serialize(ref calldata);
    array!['BINANCE', 'OKX'].span().serialize(ref calldata);
    let (registry_address, _) = deploy_syscall(
        ValidatorRegistry::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), true,
    )
        .unwrap_syscall();
    (IValidatorRegistryDispatcher { contract_address: registry_address }, staking)
}

fn bind(registry: IValidatorRegistryDispatcher, staker: ContractAddress, signer: ContractAddress) {
    set_contract_address(signer);
    registry.declare_oracle_signer(staker);
    set_contract_address(staker);
    registry.bind_oracle_signer(signer);
}

fn publisher() -> felt252 {
    staker().into()
}

#[test]
fn test_bind_happy_path() {
    let (registry, _) = setup();
    assert(registry.get_publisher_status(staker()) == STATUS_NOT_BOUND, 'should be unbound');
    bind(registry, staker(), signer());

    assert(registry.get_publisher_address(publisher()) == signer(), 'wrong signer');
    assert(registry.get_oracle_signer(staker()) == signer(), 'wrong binding');
    assert(registry.get_staker_for_signer(signer()) == staker(), 'wrong reverse binding');
    assert(registry.get_declared_staker(signer()).is_zero(), 'declaration not cleared');
    assert(registry.get_publisher_status(staker()) == STATUS_ACTIVE, 'should be active');
    assert(registry.can_publish_source(publisher(), 'BINANCE'), 'should publish BINANCE');
    assert(!registry.can_publish_source(publisher(), 'KRAKEN'), 'KRAKEN not allowed');
    assert(registry.get_publisher_sources(publisher()).len() == 2, 'wrong sources');
    let publishers = registry.get_all_publishers();
    assert(publishers.len() == 1, 'wrong publishers len');
    assert(*publishers.at(0) == publisher(), 'wrong publisher');
}

#[test]
fn test_unbound_publisher_has_no_rights() {
    let (registry, _) = setup();
    assert(registry.get_publisher_address(publisher()).is_zero(), 'should be zero');
    assert(!registry.can_publish_source(publisher(), 'BINANCE'), 'should not publish');
    assert(registry.get_publisher_sources(publisher()).len() == 0, 'should have no sources');
}

#[test]
#[should_panic(expected: ('Signer not declared', 'ENTRYPOINT_FAILED'))]
fn test_bind_without_declaration_fails() {
    let (registry, _) = setup();
    set_contract_address(staker());
    registry.bind_oracle_signer(signer());
}

#[test]
#[should_panic(expected: ('Signer not declared', 'ENTRYPOINT_FAILED'))]
fn test_bind_declared_for_other_staker_fails() {
    let (registry, _) = setup();
    set_contract_address(signer());
    registry.declare_oracle_signer(other_staker());
    set_contract_address(staker());
    registry.bind_oracle_signer(signer());
}

#[test]
#[should_panic(expected: ('Caller is not a staker', 'ENTRYPOINT_FAILED'))]
fn test_bind_by_non_staker_fails() {
    let (registry, _) = setup();
    set_contract_address(signer());
    registry.declare_oracle_signer(stranger());
    set_contract_address(stranger());
    registry.bind_oracle_signer(signer());
}

#[test]
#[should_panic(expected: ('Signer is operational address', 'ENTRYPOINT_FAILED'))]
fn test_bind_operational_address_fails() {
    let (registry, _) = setup();
    bind(registry, staker(), operational());
}

#[test]
#[should_panic(expected: ('Signer is reward address', 'ENTRYPOINT_FAILED'))]
fn test_bind_reward_address_fails() {
    let (registry, _) = setup();
    bind(registry, staker(), reward());
}

#[test]
#[should_panic(expected: ('Signer cannot be the staker', 'ENTRYPOINT_FAILED'))]
fn test_declare_staker_as_signer_fails() {
    let (registry, _) = setup();
    set_contract_address(staker());
    registry.declare_oracle_signer(staker());
}

#[test]
#[should_panic(expected: ('Staker is exiting', 'ENTRYPOINT_FAILED'))]
fn test_bind_exiting_staker_fails() {
    let (registry, staking) = setup();
    staking.set_unstake_time(staker(), BLOCK_TIMESTAMP + 604800);
    bind(registry, staker(), signer());
}

#[test]
#[should_panic(expected: ('Self stake below minimum', 'ENTRYPOINT_FAILED'))]
fn test_bind_low_self_stake_fails() {
    let (registry, staking) = setup();
    staking.set_amount_own(staker(), MIN_SELF_STAKE - 1);
    bind(registry, staker(), signer());
}

#[test]
#[should_panic(expected: ('Signer already bound', 'ENTRYPOINT_FAILED'))]
fn test_signer_cannot_serve_two_stakers() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(signer());
    registry.declare_oracle_signer(other_staker());
}

#[test]
fn test_rotation() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    bind(registry, staker(), other_signer());

    assert(registry.get_publisher_address(publisher()) == other_signer(), 'not rotated');
    assert(registry.get_staker_for_signer(signer()).is_zero(), 'old signer still bound');
    assert(registry.get_staker_for_signer(other_signer()) == staker(), 'new signer not bound');
    assert(registry.get_all_publishers().len() == 1, 'publisher duplicated');

    // the old signer is free again
    bind(registry, other_staker(), signer());
    assert(registry.get_oracle_signer(other_staker()) == signer(), 'old signer not reusable');
    assert(registry.get_all_publishers().len() == 2, 'wrong publishers len');
}

#[test]
fn test_revoke_by_staker() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(staker());
    registry.revoke_oracle_signer(staker());

    assert(registry.get_publisher_address(publisher()).is_zero(), 'still publishing');
    assert(registry.get_staker_for_signer(signer()).is_zero(), 'signer still bound');
    assert(registry.get_publisher_status(staker()) == STATUS_NOT_BOUND, 'should be unbound');
    assert(registry.get_all_publishers().len() == 0, 'publisher not removed');
    assert(!registry.can_publish_source(publisher(), 'BINANCE'), 'source still allowed');
}

#[test]
fn test_revoke_by_signer() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(signer());
    registry.revoke_oracle_signer(staker());
    assert(registry.get_oracle_signer(staker()).is_zero(), 'not revoked');
}

#[test]
#[should_panic(expected: ('Caller cannot revoke', 'ENTRYPOINT_FAILED'))]
fn test_revoke_by_stranger_fails() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(stranger());
    registry.revoke_oracle_signer(staker());
}

#[test]
fn test_exit_intent_revokes_and_prunes() {
    let (registry, staking) = setup();
    bind(registry, staker(), signer());
    staking.set_unstake_time(staker(), BLOCK_TIMESTAMP + 604800);

    assert(registry.get_publisher_status(staker()) == STATUS_EXITING, 'should be exiting');
    assert(registry.get_publisher_address(publisher()).is_zero(), 'exiting can publish');

    set_contract_address(stranger());
    registry.prune(staker());
    assert(registry.get_oracle_signer(staker()).is_zero(), 'not pruned');
    assert(registry.get_all_publishers().len() == 0, 'publisher not removed');
}

#[test]
fn test_deleted_staker_revokes() {
    let (registry, staking) = setup();
    bind(registry, staker(), signer());
    staking.remove_staker(staker());
    assert(registry.get_publisher_status(staker()) == STATUS_NOT_STAKER, 'should be not staker');
    assert(registry.get_publisher_address(publisher()).is_zero(), 'deleted can publish');
}

#[test]
fn test_operational_key_reuse_revokes() {
    let (registry, staking) = setup();
    bind(registry, staker(), signer());
    staking.set_operational_address(staker(), signer());
    assert(registry.get_publisher_status(staker()) == STATUS_KEY_REUSED, 'should be key reused');
    assert(registry.get_publisher_address(publisher()).is_zero(), 'reused key can publish');
    registry.prune(staker());
    assert(registry.get_oracle_signer(staker()).is_zero(), 'not pruned');
}

#[test]
fn test_low_self_stake_suspends_until_topped_up() {
    let (registry, staking) = setup();
    bind(registry, staker(), signer());
    staking.set_amount_own(staker(), MIN_SELF_STAKE - 1);
    assert(registry.get_publisher_status(staker()) == STATUS_LOW_SELF_STAKE, 'should be low');
    assert(registry.get_publisher_address(publisher()).is_zero(), 'low stake can publish');

    staking.set_amount_own(staker(), MIN_SELF_STAKE);
    assert(registry.get_publisher_address(publisher()) == signer(), 'should publish again');
}

#[test]
#[should_panic(expected: ('Publisher not prunable', 'ENTRYPOINT_FAILED'))]
fn test_prune_active_publisher_fails() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    registry.prune(staker());
}

#[test]
fn test_admin_suspend_and_pause() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());

    set_contract_address(admin());
    registry.set_suspended(staker(), true);
    assert(registry.get_publisher_status(staker()) == STATUS_SUSPENDED, 'should be suspended');
    assert(registry.get_publisher_address(publisher()).is_zero(), 'suspended can publish');
    registry.set_suspended(staker(), false);
    assert(registry.get_publisher_address(publisher()) == signer(), 'should be restored');

    registry.set_paused(true);
    assert(registry.get_publisher_status(staker()) == STATUS_PAUSED, 'should be paused');
    assert(registry.get_publisher_address(publisher()).is_zero(), 'paused can publish');
    registry.set_paused(false);
    assert(registry.get_publisher_address(publisher()) == signer(), 'should be unpaused');
}

#[test]
#[should_panic(expected: ('Admin: unauthorized', 'ENTRYPOINT_FAILED'))]
fn test_suspend_non_admin_fails() {
    let (registry, _) = setup();
    set_contract_address(stranger());
    registry.set_suspended(staker(), true);
}

#[test]
#[should_panic(expected: ('Registry is paused', 'ENTRYPOINT_FAILED'))]
fn test_bind_while_paused_fails() {
    let (registry, _) = setup();
    set_contract_address(admin());
    registry.set_paused(true);
    bind(registry, staker(), signer());
}

#[test]
fn test_set_allowed_sources_replaces_list() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(admin());
    registry.set_allowed_sources(array!['KRAKEN', 'KRAKEN', 'BYBIT'].span());

    let sources = registry.get_allowed_sources();
    assert(sources.len() == 2, 'duplicates not removed');
    assert(!registry.can_publish_source(publisher(), 'BINANCE'), 'old source still allowed');
    assert(registry.can_publish_source(publisher(), 'KRAKEN'), 'new source not allowed');
}

#[test]
fn test_set_min_self_stake() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(admin());
    registry.set_min_self_stake(SELF_STAKE + 1);
    assert(registry.get_min_self_stake() == SELF_STAKE + 1, 'min not updated');
    assert(registry.get_publisher_status(staker()) == STATUS_LOW_SELF_STAKE, 'should be low');
}

#[test]
fn test_admin_transfer() {
    let (registry, _) = setup();
    set_contract_address(admin());
    registry.set_admin_address(stranger());
    assert(registry.get_admin_address() == stranger(), 'admin not transferred');
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_admin_transfer_by_stranger_fails() {
    let (registry, _) = setup();
    set_contract_address(stranger());
    registry.set_admin_address(stranger());
}

#[test]
fn test_publisher_id_out_of_address_range() {
    let (registry, _) = setup();
    // felt252 values >= 2**251 are not contract addresses
    let invalid: felt252 = 0x800000000000000000000000000000000000000000000000000000000000000;
    assert(registry.get_publisher_address(invalid).is_zero(), 'should be zero');
    assert(registry.get_publisher_address(0).is_zero(), 'zero should be zero');
}
