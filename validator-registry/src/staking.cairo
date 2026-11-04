use starknet::ContractAddress;

// Minimal mirror of the Starknet staking contract as deployed on mainnet and sepolia
// (starkware-libs/starknet-staking @staking/contracts-v1.0.1-dev.854).
// Field order must match the deployed Serde layout.

#[derive(Copy, Drop, Serde)]
pub struct Timestamp {
    pub seconds: u64,
}

#[derive(Copy, Drop, Serde)]
pub struct StakerPoolInfoV1 {
    pub pool_contract: ContractAddress,
    pub amount: u128,
    pub commission: u16,
}

#[derive(Copy, Drop, Serde)]
pub struct StakerInfoV1 {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<Timestamp>,
    pub amount_own: u128,
    pub unclaimed_rewards_own: u128,
    pub pool_info: Option<StakerPoolInfoV1>,
}

#[starknet::interface]
pub trait IStaking<TContractState> {
    fn get_staker_info_v1(
        self: @TContractState, staker_address: ContractAddress,
    ) -> Option<StakerInfoV1>;
}
