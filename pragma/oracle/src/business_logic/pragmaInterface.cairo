use entry::contracts::structs::{
    BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
};
use array::ArrayTrait;
trait IPragmaOracle {
    /// Get info about some data e.g spot, future, generic
    /// Queried data should implement the `Query` trait
    ///
    /// # Arguments
    ///
    /// * `aggregation_mode` - Aggregation mode to use for the price
    /// * `data_type` - Type of the data to get
    ///
    /// # Returns
    ///
    /// * `price` - Price of the pair
    /// * `decimals` - Number of decimals of the price
    /// * `last_updated_timestamp` - Timestamp of the most recent update, UTC epoch
    /// * `num_sources_aggregated` - Number of sources aggregated into this price
    fn get_data(data_type: DataType, aggregation_mode: felt252) -> PragmaPricesResponse;
    /// Get a specific data entry e.g spot, future, generic
    /// 
    /// # Arguments
    ///
    /// * `source` - UTF-8 encoded uppercased string, e.g. "GEMINI"
    /// * `data_type` - Type of the price to get
    /// * `expiration_timestamp` - Expiration timestamp if applicable (Futures)
    ///
    /// # Returns
    ///
    /// * `T` - Data entry
    fn get_data_entry<T>(source: felt252, data_type: DataType) -> T;
    /// Get the median of some data e.g spot, future, generic
    ///
    /// # Arguments
    ///
    /// * `data_type` - Type of the data to get
    /// * `expiration_timestamp` - Expiration timestamp if applicable (Futures)
    ///
    /// # Returns
    ///
    /// * `price` - Median price of the pair
    fn get_data_median(data_type: DataType, ) -> PragmaPricesResponse;
    ///Get the data entries for a specific data type for given sources
    ///
    /// # Arguments
    ///
    /// * `expiration_timestamp` - Expiration timestamp if applicable (Futures)
    /// * `data_type` - Type of the data to get
    /// * `sources` - Array of sources to get data for
    ///
    /// # Returns
    ///
    /// * `Array::<T>` - Array of data entries
    fn get_data_entries_for_sources<T>(
        expiration_timestamp: Option::<felt252>, data_type: DataType, sources: @Array<felt252>
    ) -> Array::<T>;
    ///Get the data entries for a specific data type for all the sources
    ///
    /// # Arguments
    ///
    /// * `data_type` - Type of the data to get
    /// * `sources` - Array of sources to get data for
    /// * `aggregation_mode` - Aggregation mode to use for the price
    ///
    /// # Returns
    ///
    /// * `Array::<T>` - Array of data entries
    fn get_data_entries<T>(data_type: DataType, aggregation_mode: felt252) -> Array::<T>;
    /// Get the number of decimals of some data e.g spot, future, generic
    /// # Arguments
    ///
    /// * `data_type` - Type of the data to get
    ///
    /// # Returns
    ///
    ///  felt252 - Number of decimals of for the given data
    fn get_data_decimals(data_type: DataType) -> felt252;
    /// Get the last updated timestamp of some data e.g spot, future, generic
    ///
    /// # Arguments
    ///
    /// * `data_type` - Type of the data to get
    /// * `timestamp` - the timestamp to get the last updated timestamp before
    /// 
    /// # Returns
    ///
    /// * `felt252` - Timestamp of the most recent update, before the given timestamp, UTC epoch
    /// * `Checkpoint` - The checkpoint associated with the timestamp
    fn get_last_data_checkpoint_before(
        timestamp: felt252, data_type: DataType
    ) -> (Checkpoint, felt252);
}
