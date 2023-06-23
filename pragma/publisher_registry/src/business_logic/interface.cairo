use starknet::ContractAddress;
use array::ArrayTrait;

trait IPublisherRegistry {
    fn add_publisher(publisher: felt252, publisher_address: ContractAddress);
    fn update_publisher_address(publisher: felt252, new_publisher_address: ContractAddress);
    fn remove_publisher(publisher: felt252);
    fn add_source_for_publisher(publisher: felt252, source: felt252);
    fn add_sources_for_publisher(publisher: felt252, sources: Span<felt252>);
    fn remove_source_for_publisher(publisher: felt252, source: felt252);
    fn get_publisher_address(publisher: felt252) -> ContractAddress;
    fn can_publish_source(publisher: felt252, source: felt252) -> bool;
}
