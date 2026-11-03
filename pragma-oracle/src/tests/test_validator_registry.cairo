use array::{ArrayTrait, SpanTrait};
use option::OptionTrait;
use result::ResultTrait;
use traits::{Into, TryInto};
use serde::Serde;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::syscalls::deploy_syscall;
use starknet::testing::{set_contract_address, set_block_timestamp, set_chain_id};
use starknet::contract_address::contract_address_const;
use zeroable::Zeroable;
use pragma::entry::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PossibleEntries, USD_CURRENCY_ID
};
use pragma::oracle::oracle::{Oracle, IOracleABIDispatcher, IOracleABIDispatcherTrait};
use pragma::validator_registry::validator_registry::{
    ValidatorRegistry, IValidatorRegistryDispatcher, IValidatorRegistryDispatcherTrait,
    STATUS_ACTIVE, STATUS_PAUSED, STATUS_NOT_BOUND, STATUS_SUSPENDED, STATUS_NOT_STAKER,
    STATUS_EXITING, STATUS_LOW_SELF_STAKE, STATUS_KEY_REUSED
};
use pragma::validator_registry::mock_staking::{
    MockStaking, IMockStakingDispatcher, IMockStakingDispatcherTrait
};

const MIN_SELF_STAKE: u128 = 20000;
const SELF_STAKE: u128 = 25000;
const BLOCK_TIMESTAMP: u64 = 103374042;
const PAIR_ID: felt252 = 'BTC/USD';
const BTC: felt252 = 'BTC';

fn admin() -> ContractAddress {
    contract_address_const::<0x12345>()
}
fn staker() -> ContractAddress {
    contract_address_const::<0xa11ce>()
}
fn reward() -> ContractAddress {
    contract_address_const::<0xbeef>()
}
fn operational() -> ContractAddress {
    contract_address_const::<0x0fe1>()
}
fn signer() -> ContractAddress {
    contract_address_const::<0x5161>()
}
fn other_signer() -> ContractAddress {
    contract_address_const::<0x5162>()
}
fn other_staker() -> ContractAddress {
    contract_address_const::<0xb0b>()
}
fn stranger() -> ContractAddress {
    contract_address_const::<0x98765>()
}

fn setup() -> (IValidatorRegistryDispatcher, IMockStakingDispatcher) {
    set_block_timestamp(BLOCK_TIMESTAMP);
    set_contract_address(admin());
    let (staking_address, _) = deploy_syscall(
        MockStaking::TEST_CLASS_HASH.try_into().unwrap(), 0, ArrayTrait::new().span(), true
    )
        .unwrap_syscall();
    let staking = IMockStakingDispatcher { contract_address: staking_address };
    staking.set_staker(staker(), reward(), operational(), SELF_STAKE);
    staking
        .set_staker(
            other_staker(),
            contract_address_const::<0xbeef2>(),
            contract_address_const::<0x0fe2>(),
            SELF_STAKE
        );

    let mut calldata = ArrayTrait::<felt252>::new();
    admin().serialize(ref calldata);
    staking_address.serialize(ref calldata);
    MIN_SELF_STAKE.serialize(ref calldata);
    array!['BINANCE', 'OKX'].span().serialize(ref calldata);
    let (registry_address, _) = deploy_syscall(
        ValidatorRegistry::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), true
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
#[available_gas(200000000)]
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
#[available_gas(200000000)]
fn test_unbound_publisher_has_no_rights() {
    let (registry, _) = setup();
    assert(registry.get_publisher_address(publisher()).is_zero(), 'should be zero');
    assert(!registry.can_publish_source(publisher(), 'BINANCE'), 'should not publish');
    assert(registry.get_publisher_sources(publisher()).len() == 0, 'should have no sources');
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Signer not declared', 'ENTRYPOINT_FAILED'))]
fn test_bind_without_declaration_fails() {
    let (registry, _) = setup();
    set_contract_address(staker());
    registry.bind_oracle_signer(signer());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Signer not declared', 'ENTRYPOINT_FAILED'))]
fn test_bind_declared_for_other_staker_fails() {
    let (registry, _) = setup();
    set_contract_address(signer());
    registry.declare_oracle_signer(other_staker());
    set_contract_address(staker());
    registry.bind_oracle_signer(signer());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Caller is not a staker', 'ENTRYPOINT_FAILED'))]
fn test_bind_by_non_staker_fails() {
    let (registry, _) = setup();
    set_contract_address(signer());
    registry.declare_oracle_signer(stranger());
    set_contract_address(stranger());
    registry.bind_oracle_signer(signer());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Signer is operational address', 'ENTRYPOINT_FAILED'))]
fn test_bind_operational_address_fails() {
    let (registry, _) = setup();
    bind(registry, staker(), operational());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Signer is reward address', 'ENTRYPOINT_FAILED'))]
fn test_bind_reward_address_fails() {
    let (registry, _) = setup();
    bind(registry, staker(), reward());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Signer cannot be the staker', 'ENTRYPOINT_FAILED'))]
fn test_declare_staker_as_signer_fails() {
    let (registry, _) = setup();
    set_contract_address(staker());
    registry.declare_oracle_signer(staker());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Staker is exiting', 'ENTRYPOINT_FAILED'))]
fn test_bind_exiting_staker_fails() {
    let (registry, staking) = setup();
    staking.set_unstake_time(staker(), BLOCK_TIMESTAMP + 604800);
    bind(registry, staker(), signer());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Self stake below minimum', 'ENTRYPOINT_FAILED'))]
fn test_bind_low_self_stake_fails() {
    let (registry, staking) = setup();
    staking.set_amount_own(staker(), MIN_SELF_STAKE - 1);
    bind(registry, staker(), signer());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Signer already bound', 'ENTRYPOINT_FAILED'))]
fn test_signer_cannot_serve_two_stakers() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(signer());
    registry.declare_oracle_signer(other_staker());
}

#[test]
#[available_gas(200000000)]
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
#[available_gas(200000000)]
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
#[available_gas(200000000)]
fn test_revoke_by_signer() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(signer());
    registry.revoke_oracle_signer(staker());
    assert(registry.get_oracle_signer(staker()).is_zero(), 'not revoked');
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Caller cannot revoke', 'ENTRYPOINT_FAILED'))]
fn test_revoke_by_stranger_fails() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(stranger());
    registry.revoke_oracle_signer(staker());
}

#[test]
#[available_gas(200000000)]
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
#[available_gas(200000000)]
fn test_deleted_staker_revokes() {
    let (registry, staking) = setup();
    bind(registry, staker(), signer());
    staking.remove_staker(staker());
    assert(registry.get_publisher_status(staker()) == STATUS_NOT_STAKER, 'should be not staker');
    assert(registry.get_publisher_address(publisher()).is_zero(), 'deleted can publish');
}

#[test]
#[available_gas(200000000)]
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
#[available_gas(200000000)]
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
#[available_gas(200000000)]
#[should_panic(expected: ('Publisher not prunable', 'ENTRYPOINT_FAILED'))]
fn test_prune_active_publisher_fails() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    registry.prune(staker());
}

#[test]
#[available_gas(200000000)]
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
#[available_gas(200000000)]
#[should_panic(expected: ('Admin: unauthorized', 'ENTRYPOINT_FAILED'))]
fn test_suspend_non_admin_fails() {
    let (registry, _) = setup();
    set_contract_address(stranger());
    registry.set_suspended(staker(), true);
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Registry is paused', 'ENTRYPOINT_FAILED'))]
fn test_bind_while_paused_fails() {
    let (registry, _) = setup();
    set_contract_address(admin());
    registry.set_paused(true);
    bind(registry, staker(), signer());
}

#[test]
#[available_gas(200000000)]
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
#[available_gas(200000000)]
fn test_set_min_self_stake() {
    let (registry, _) = setup();
    bind(registry, staker(), signer());
    set_contract_address(admin());
    registry.set_min_self_stake(SELF_STAKE + 1);
    assert(registry.get_min_self_stake() == SELF_STAKE + 1, 'min not updated');
    assert(registry.get_publisher_status(staker()) == STATUS_LOW_SELF_STAKE, 'should be low');
}

#[test]
#[available_gas(200000000)]
fn test_publisher_id_out_of_address_range() {
    let (registry, _) = setup();
    // felt252 values >= 2**251 are not contract addresses
    let invalid: felt252 = 0x800000000000000000000000000000000000000000000000000000000000000;
    assert(registry.get_publisher_address(invalid).is_zero(), 'should be zero');
    assert(registry.get_publisher_address(0).is_zero(), 'zero should be zero');
}

fn deploy_oracle(registry: IValidatorRegistryDispatcher) -> IOracleABIDispatcher {
    set_chain_id('SN_MAIN');
    let currencies = array![
        Currency {
            id: BTC,
            decimals: 8_u32,
            is_abstract_currency: false,
            starknet_address: Zeroable::zero(),
            ethereum_address: Zeroable::zero(),
        },
        Currency {
            id: USD_CURRENCY_ID,
            decimals: 8_u32,
            is_abstract_currency: true,
            starknet_address: Zeroable::zero(),
            ethereum_address: Zeroable::zero(),
        }
    ];
    let pairs = array![
        Pair { id: PAIR_ID, quote_currency_id: USD_CURRENCY_ID, base_currency_id: BTC }
    ];
    let mut calldata = ArrayTrait::<felt252>::new();
    admin().serialize(ref calldata);
    registry.contract_address.serialize(ref calldata);
    currencies.serialize(ref calldata);
    pairs.serialize(ref calldata);
    set_contract_address(admin());
    let (oracle_address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), true
    )
        .unwrap_syscall();
    IOracleABIDispatcher { contract_address: oracle_address }
}

fn spot_entry(source: felt252, price: u128) -> PossibleEntries {
    PossibleEntries::Spot(
        SpotEntry {
            base: BaseEntry { timestamp: BLOCK_TIMESTAMP, source, publisher: publisher() },
            pair_id: PAIR_ID,
            price,
            volume: 0
        }
    )
}

#[test]
#[available_gas(2000000000)]
fn test_unmodified_oracle_accepts_bound_validator() {
    let (registry, _) = setup();
    let oracle = deploy_oracle(registry);
    bind(registry, staker(), signer());

    set_contract_address(signer());
    oracle.publish_data(spot_entry('BINANCE', 6500000000000));
    oracle.publish_data(spot_entry('OKX', 6510000000000));

    let res = oracle.get_data_median(DataType::SpotEntry(PAIR_ID));
    assert(res.price == 6505000000000, 'wrong median');
    assert(res.num_sources_aggregated == 2, 'wrong sources count');
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Not allowed for source', 'ENTRYPOINT_FAILED'))]
fn test_unmodified_oracle_rejects_disallowed_source() {
    let (registry, _) = setup();
    let oracle = deploy_oracle(registry);
    bind(registry, staker(), signer());
    set_contract_address(signer());
    oracle.publish_data(spot_entry('KRAKEN', 6500000000000));
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Transaction not from publisher', 'ENTRYPOINT_FAILED'))]
fn test_unmodified_oracle_rejects_operational_key() {
    let (registry, _) = setup();
    let oracle = deploy_oracle(registry);
    bind(registry, staker(), signer());
    set_contract_address(operational());
    oracle.publish_data(spot_entry('BINANCE', 6500000000000));
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Publisher is not registered', 'ENTRYPOINT_FAILED'))]
fn test_unmodified_oracle_rejects_exiting_validator() {
    let (registry, staking) = setup();
    let oracle = deploy_oracle(registry);
    bind(registry, staker(), signer());
    set_contract_address(signer());
    oracle.publish_data(spot_entry('BINANCE', 6500000000000));

    staking.set_unstake_time(staker(), BLOCK_TIMESTAMP + 604800);
    set_contract_address(signer());
    oracle.publish_data(spot_entry('OKX', 6510000000000));
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Publisher is not registered', 'ENTRYPOINT_FAILED'))]
fn test_unmodified_oracle_rejects_revoked_signer() {
    let (registry, _) = setup();
    let oracle = deploy_oracle(registry);
    bind(registry, staker(), signer());
    set_contract_address(staker());
    registry.revoke_oracle_signer(staker());
    set_contract_address(signer());
    oracle.publish_data(spot_entry('BINANCE', 6500000000000));
}
