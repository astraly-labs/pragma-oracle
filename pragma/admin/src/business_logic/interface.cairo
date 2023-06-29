use starknet::ContractAddress;


trait IAdmin<TContractState> {
    fn get_admin_address(self: @TContractState) -> ContractAddress;
    fn set_admin_address(ref self: TContractState, new_address: ContractAddress);
    fn initialize_admin_address(ref self: TContractState, admin_address: ContractAddress);
}
