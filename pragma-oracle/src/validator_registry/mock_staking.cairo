use starknet::ContractAddress;

#[starknet::interface]
trait IMockStaking<TContractState> {
    fn set_staker(
        ref self: TContractState,
        staker_address: ContractAddress,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount_own: u128
    );
    fn set_operational_address(
        ref self: TContractState,
        staker_address: ContractAddress,
        operational_address: ContractAddress
    );
    fn set_amount_own(ref self: TContractState, staker_address: ContractAddress, amount_own: u128);
    fn set_unstake_time(ref self: TContractState, staker_address: ContractAddress, seconds: u64);
    fn remove_staker(ref self: TContractState, staker_address: ContractAddress);
}

#[starknet::contract]
mod MockStaking {
    use starknet::ContractAddress;
    use option::OptionTrait;
    use pragma::validator_registry::staking::{IStaking, StakerInfoV1, Timestamp};
    use super::IMockStaking;

    #[storage]
    struct Storage {
        exists: LegacyMap::<ContractAddress, bool>,
        reward_address: LegacyMap::<ContractAddress, ContractAddress>,
        operational_address: LegacyMap::<ContractAddress, ContractAddress>,
        amount_own: LegacyMap::<ContractAddress, u128>,
        // 0 means no unstake intent
        unstake_time: LegacyMap::<ContractAddress, u64>,
    }

    #[external(v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn get_staker_info_v1(
            self: @ContractState, staker_address: ContractAddress
        ) -> Option<StakerInfoV1> {
            if !self.exists.read(staker_address) {
                return Option::None(());
            }
            let seconds = self.unstake_time.read(staker_address);
            let unstake_time = if seconds == 0 {
                Option::None(())
            } else {
                Option::Some(Timestamp { seconds })
            };
            Option::Some(
                StakerInfoV1 {
                    reward_address: self.reward_address.read(staker_address),
                    operational_address: self.operational_address.read(staker_address),
                    unstake_time,
                    amount_own: self.amount_own.read(staker_address),
                    unclaimed_rewards_own: 0,
                    pool_info: Option::None(()),
                }
            )
        }
    }

    #[external(v0)]
    impl MockStakingImpl of IMockStaking<ContractState> {
        fn set_staker(
            ref self: ContractState,
            staker_address: ContractAddress,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount_own: u128
        ) {
            self.exists.write(staker_address, true);
            self.reward_address.write(staker_address, reward_address);
            self.operational_address.write(staker_address, operational_address);
            self.amount_own.write(staker_address, amount_own);
            self.unstake_time.write(staker_address, 0);
        }

        fn set_operational_address(
            ref self: ContractState,
            staker_address: ContractAddress,
            operational_address: ContractAddress
        ) {
            self.operational_address.write(staker_address, operational_address);
        }

        fn set_amount_own(
            ref self: ContractState, staker_address: ContractAddress, amount_own: u128
        ) {
            self.amount_own.write(staker_address, amount_own);
        }

        fn set_unstake_time(
            ref self: ContractState, staker_address: ContractAddress, seconds: u64
        ) {
            self.unstake_time.write(staker_address, seconds);
        }

        fn remove_staker(ref self: ContractState, staker_address: ContractAddress) {
            self.exists.write(staker_address, false);
        }
    }
}
