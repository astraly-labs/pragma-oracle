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


    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash
    }

    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        Upgraded: Upgraded, 
    }


    fn upgrade(ref self: ContractState, new_impl_hash: ClassHash) {
        assert(!new_impl_hash.is_zero(), 'Class hash cannot be zero');
        starknet::replace_class_syscall(new_impl_hash).unwrap_syscall();
        self.impl_hash.write(new_impl_hash);
        self.emit(Event::Upgraded(Upgraded { implementation: new_impl_hash }));
    }


    fn get_implementation_hash(self: @ContractState) -> ClassHash {
        self.impl_hash.read()
    }
}
