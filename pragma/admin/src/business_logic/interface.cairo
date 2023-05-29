use starknet::ContractAddress;

#[abi]
trait IAdmin {
    fn get_admin_address() -> ContractAddress;
    fn set_admin_address(new_address: ContractAddress);
}