#[starknet::contract]
mod Admin {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        admin_address: ContractAddress
    }

    //
    // View
    //

    fn get_admin_address(self: @ContractState) -> ContractAddress {
        self.admin_address.read()
    }

    //
    // Internals
    //

    fn assert_only_admin(self: @ContractState) {
        let admin = get_admin_address(self);
        let caller = get_caller_address();
        assert(caller == admin, 'Admin: unauthorized');
    }


    fn initialize_admin_address(ref self: ContractState, admin_address: ContractAddress) {
        // If the admin address is already initialized, do nothing.
        assert(self.admin_address.read().is_zero(), 'Admin: already initialized');

        self.admin_address.write(admin_address);
    }


    fn set_admin_address(ref self: ContractState, new_address: ContractAddress) {
        assert_only_admin(@self);
        self.admin_address.write(new_address);
    }
}

