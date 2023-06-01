#[contract]
mod Admin {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    struct Storage {
        admin_address: ContractAddress
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
        let caller = get_caller_address();
        assert(caller == admin, 'Admin: unauthorized');
    }

    #[internal]
    fn initialize_admin_address(admin_address: ContractAddress) {
        // If the admin address is already initialized, do nothing.
        assert(admin_address::read().is_zero(), 'Admin: already initialized');

        admin_address::write(admin_address);
    }

    #[internal]
    fn set_admin_address(new_address: ContractAddress) {
        assert_only_admin();
        admin_address::write(new_address);
    }
}

