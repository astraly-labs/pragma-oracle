#[starknet::contract]
mod Upgradeable {
    use starknet::class_hash::ClassHash;
    use zeroable::Zeroable;
    use result::ResultTrait;
    use starknet::SyscallResult;

    #[storage]
    struct Storage {
        impl_hash: ClassHash, 
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    fn Upgraded(implementation: ClassHash) {}

    #[internal]
    fn upgrade(ref self: ContractState, new_impl_hash: ClassHash) {
        assert(!new_impl_hash.is_zero(), 'Class hash cannot be zero');
        starknet::replace_class_syscall(new_impl_hash).unwrap_syscall();
        self.impl_hash.write(new_impl_hash);
        Upgraded(new_impl_hash);
    }

    #[view]
    fn get_implementation_hash(self: @ContractState) -> ClassHash {
        self.impl_hash.read()
    }
}
