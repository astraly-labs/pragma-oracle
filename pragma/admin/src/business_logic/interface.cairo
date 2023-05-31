use starknet::ContractAddress;

trait IAdmin {
    fn get_admin_address() -> ContractAddress;
    fn set_admin_address(new_address: ContractAddress);
    fn initialize_admin_address(admin_address: ContractAddress);
}