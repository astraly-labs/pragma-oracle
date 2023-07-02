// TAKEN FROM : https://github.com/OpenZeppelin/cairo-contracts/blob/cairo-1/src/openzeppelin/introspection/erc165.cairo
// CREDITS TO OZ TEAM

const IERC165_ID: u32 = 0x01ffc9a7_u32;
const INVALID_ID: u32 = 0xffffffff_u32;


#[starknet::interface]
trait IERC165<TContractState> {
    fn supports_interface(self: @TContractState, interface_id: u32) -> bool;
}

#[starknet::contract]
mod ERC165 {
    use super::IERC165_ID;
    use super::INVALID_ID;
    use super::IERC165;

    #[storage]
    struct Storage {
        supported_interfaces: LegacyMap<u32, bool>
    }

    impl ERC165 of IERC165<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: u32) -> bool {
            if interface_id == IERC165_ID {
                return true;
            }
            self.supported_interfaces.read(interface_id)
        }
    }


    #[internal]
    fn register_interface(ref self: ContractState, interface_id: u32) {
        assert(interface_id != INVALID_ID, 'Invalid id');
        self.supported_interfaces.write(interface_id, true);
    }

    #[internal]
    fn deregister_interface(ref self: ContractState, interface_id: u32) {
        assert(interface_id != IERC165_ID, 'Invalid id');
        self.supported_interfaces.write(interface_id, false);
    }
}
