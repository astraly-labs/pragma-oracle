// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IPragmaCaller {
    enum AggregationMode {
        Median,
        Mean
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

    struct PragmaCalculateVolatilityRequest {
        DataType dataType;
        uint256 pairId;
        uint256 expirationTimestamp;
        uint64 startTimestamp;
        uint64 endTimestamp;
        uint64 numSamples;
        AggregationMode aggregationMode;
    }

    struct PragmaPricesResponse {
        uint256 price;
        uint256 decimals;
        uint256 last_updated_timestamp;
        uint256 num_sources_aggregated;
        uint256 maybe_expiration_timestamp;
    }

    struct PragmaSummaryStatsResponse {
        uint256 price;
        uint256 decimals;
    }

    function getData(
        PragmaPricesRequest memory request
    ) external view returns (PragmaPricesResponse memory);

    function calculateVolatility(
        PragmaCalculateVolatilityRequest memory request
    ) external view returns (PragmaSummaryStatsResponse memory);
}

contract CallerExample {
    IPragmaCaller private pragmaCaller;
    uint256 constant BTC_USD_FEED = 18669995996566340;
    uint64 constant SECONDS_IN_ONE_WEEK = 604800;
    uint64 constant CALCULATE_VOL_NUM_SAMPLES = 200;

    constructor(address pragmaCallerAddress) {
        pragmaCaller = IPragmaCaller(pragmaCallerAddress);
    }

    function getBtcSpotMedianPrice()
        public
        view
        returns (IPragmaCaller.PragmaPricesResponse memory)
    {
        return getDataMedianSpot(BTC_USD_FEED);
    }

    function getBtcVolatilyOverLastWeek()
        public
        view
        returns (IPragmaCaller.PragmaSummaryStatsResponse memory)
    {
        uint64 blockTimestamp = uint64(block.timestamp);

        IPragmaCaller.PragmaCalculateVolatilityRequest
            memory request = IPragmaCaller.PragmaCalculateVolatilityRequest(
                IPragmaCaller.DataType.SpotEntry,
                BTC_USD_FEED,
                0,
                blockTimestamp - SECONDS_IN_ONE_WEEK,
                blockTimestamp,
                CALCULATE_VOL_NUM_SAMPLES,
                IPragmaCaller.AggregationMode.Median
            );
        return pragmaCaller.calculateVolatility(request);
    }

    function getDataMedianSpot(
        uint256 pairId
    ) public view returns (IPragmaCaller.PragmaPricesResponse memory) {
        IPragmaCaller.PragmaPricesRequest memory request = IPragmaCaller
            .PragmaPricesRequest(
                IPragmaCaller.AggregationMode.Median,
                IPragmaCaller.DataType.SpotEntry,
                pairId,
                0
            );
        return pragmaCaller.getData(request);
    }

    function getDataMeanSpot(
        uint256 pairId
    ) public view returns (IPragmaCaller.PragmaPricesResponse memory) {
        IPragmaCaller.PragmaPricesRequest memory request = IPragmaCaller
            .PragmaPricesRequest(
                IPragmaCaller.AggregationMode.Mean,
                IPragmaCaller.DataType.SpotEntry,
                pairId,
                0
            );
        return pragmaCaller.getData(request);
    }

    function getDataMedianPerp(
        uint256 pairId
    ) public view returns (IPragmaCaller.PragmaPricesResponse memory) {
        IPragmaCaller.PragmaPricesRequest memory request = IPragmaCaller
            .PragmaPricesRequest(
                IPragmaCaller.AggregationMode.Median,
                IPragmaCaller.DataType.FuturesEntry,
                pairId,
                0
            );
        return pragmaCaller.getData(request);
    }

    function getDataMedianFuture(
        uint256 pairId,
        uint64 expiryTimestamp
    ) public view returns (IPragmaCaller.PragmaPricesResponse memory) {
        IPragmaCaller.PragmaPricesRequest memory request = IPragmaCaller
            .PragmaPricesRequest(
                IPragmaCaller.AggregationMode.Median,
                IPragmaCaller.DataType.FuturesEntry,
                pairId,
                uint256(expiryTimestamp)
            );
        return pragmaCaller.getData(request);
    }

    function getVolatilyOverLastWeek(
        uint256 pairId
    ) public view returns (IPragmaCaller.PragmaSummaryStatsResponse memory) {
        uint64 blockTimestamp = uint64(block.timestamp);

        IPragmaCaller.PragmaCalculateVolatilityRequest
            memory request = IPragmaCaller.PragmaCalculateVolatilityRequest(
                IPragmaCaller.DataType.SpotEntry,
                pairId,
                0,
                blockTimestamp - SECONDS_IN_ONE_WEEK,
                blockTimestamp,
                CALCULATE_VOL_NUM_SAMPLES,
                IPragmaCaller.AggregationMode.Median
            );
        return pragmaCaller.calculateVolatility(request);
    }
}
