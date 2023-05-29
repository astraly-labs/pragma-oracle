#[contract]
mod Admin {
    use starknet::get_caller_address;
    use starknet::ContractAddress;

    struct Storage {
        admin_address: ContractAddress
    }

    //
    // Externals
    //

    #[external]
    fn set_admin_address(new_address: ContractAddress) {
        assert_only_admin();
        admin_address::write(new_address);
    }

    //
    // View
    //

    #[view]
    fn get_admin_address() -> ContractAddress {
        admin_address::read()
    }

    //
    // Internals
    //

    #[internal]
    fn assert_only_admin() {
        let admin = get_admin_address();
        let self = get_contract_address();
        assert(self == caller, 'Admin: unauthorized');
    }

}

