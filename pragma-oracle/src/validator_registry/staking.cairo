use starknet::ContractAddress;

// Minimal mirror of the Starknet staking contract as deployed on mainnet and sepolia
// (starkware-libs/starknet-staking @staking/contracts-v1.0.1-dev.854).
// Field order must match the deployed Serde layout.

#[derive(Copy, Drop, Serde)]
struct Timestamp {
    seconds: u64,
}

#[derive(Copy, Drop, Serde)]
struct StakerPoolInfoV1 {
    pool_contract: ContractAddress,
    amount: u128,
    commission: u16,
}

#[derive(Copy, Drop, Serde)]
struct StakerInfoV1 {
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    unstake_time: Option<Timestamp>,
    amount_own: u128,
    unclaimed_rewards_own: u128,
    pool_info: Option<StakerPoolInfoV1>,
}

#[starknet::interface]
trait IStaking<TContractState> {
    fn get_staker_info_v1(
        self: @TContractState, staker_address: ContractAddress
    ) -> Option<StakerInfoV1>;
}
