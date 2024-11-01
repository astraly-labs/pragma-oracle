// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IPragmaCaller {
    enum AggregationMode {
        Median
    }
    enum DataType {
        SpotEntry,
        FuturesEntry,
        GenericEntry
    }

    struct PragmaPricesRequest {
        AggregationMode aggregationMode;
        DataType dataType;
        uint256 pairId;
        uint256 expirationTimestamp;
    }

    struct PragmaPricesResponse {
        uint256 price;
        uint256 decimals;
        uint256 last_updated_timestamp;
        uint256 num_sources_aggregated;
        uint256 maybe_expiration_timestamp;
    }

    function getData(
        PragmaPricesRequest memory request
    ) external view returns (PragmaPricesResponse memory);
}

// This interface is forked from the Pyth Adapter found here:
// https://github.com/pyth-network/pyth-crosschain/blob/78cb03a76d850c3c6e2b0d2d0b07e6c89fa8bde9/target_chains/ethereum/sdk/solidity/PythAggregatorV3.sol

/**
 * @title A port of the ChainlinkAggregatorV3 interface that supports Pragma price feeds
 * @notice This does not store any roundId information on-chain. Please review the code before using this implementation.
 * Users should deploy an instance of this contract to wrap every price feed id that they need to use.
 */
contract PragmaAggregatorV3 {
    uint256 public priceId;
    IPragmaCaller public pragmaCaller;

    constructor(address _pragmaCaller, uint256 _pairId) {
        pragmaCaller = IPragmaCaller(_pragmaCaller);
        priceId = _pairId;
    }

    // Wrapper utility function to get the Pragma Oracle response. Not part of the AggregatorV3 interface.
    function getDataMedianSpot(
        uint256 pairId
    ) private view returns (IPragmaCaller.PragmaPricesResponse memory) {
        IPragmaCaller.PragmaPricesRequest memory request = IPragmaCaller
            .PragmaPricesRequest(
                IPragmaCaller.AggregationMode.Median,
                IPragmaCaller.DataType.SpotEntry,
                pairId,
                0
            );
        return pragmaCaller.getData(request);
    }

    function decimals() public view virtual returns (uint8) {
        IPragmaCaller.PragmaPricesResponse memory response = getDataMedianSpot(
            priceId
        );
        return uint8(response.decimals);
    }

    function description() public pure returns (string memory) {
        return "A port of a chainlink aggregator powered by pragma data feeds";
    }

    function version() public pure returns (uint256) {
        return 1;
    }

    function latestAnswer() public view virtual returns (int256) {
        IPragmaCaller.PragmaPricesResponse memory response = getDataMedianSpot(
            priceId
        );
        return int256(response.price);
    }

    function latestTimestamp() public view returns (uint256) {
        IPragmaCaller.PragmaPricesResponse memory response = getDataMedianSpot(
            priceId
        );
        return response.last_updated_timestamp;
    }

    function latestRound() public view returns (uint256) {
        // use timestamp as the round id
        return latestTimestamp();
    }

    function getAnswer(uint256) public view returns (int256) {
        return latestAnswer();
    }

    function getTimestamp(uint256) external view returns (uint256) {
        return latestTimestamp();
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        IPragmaCaller.PragmaPricesResponse memory response = getDataMedianSpot(
            priceId
        );
        return (
            _roundId,
            int256(response.price),
            response.last_updated_timestamp,
            response.last_updated_timestamp,
            _roundId
        );
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        IPragmaCaller.PragmaPricesResponse memory response = getDataMedianSpot(
            priceId
        );
        roundId = uint80(response.last_updated_timestamp);
        return (
            roundId,
            int256(response.price),
            response.last_updated_timestamp,
            response.last_updated_timestamp,
            roundId
        );
    }
}
