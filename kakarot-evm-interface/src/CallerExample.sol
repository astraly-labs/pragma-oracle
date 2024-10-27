// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface IPragmaCaller {
    enum DataType { SpotEntry, FuturesEntry, GenericEntry }

    struct DataRequest {
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

    function getDataMedianSpot(DataRequest memory request) external view returns (PragmaPricesResponse memory);
}

contract CallerExample {
    IPragmaCaller private pragmaCaller;
    uint256 constant BTC_USD_FEED = 18669995996566340;

    constructor(address pragmaCallerAddress) {
        pragmaCaller = IPragmaCaller(pragmaCallerAddress);
    }

    function getDataMedianSpot(uint256 pairId) public view returns (IPragmaCaller.PragmaPricesResponse memory) {
        IPragmaCaller.DataRequest memory request = IPragmaCaller.DataRequest(
            IPragmaCaller.DataType.SpotEntry,
            pairId,
            0
        );
        return pragmaCaller.getDataMedianSpot(request);
    }

    function getBtcMedianPrice() public view returns (uint256) {
        IPragmaCaller.PragmaPricesResponse memory response = getDataMedianSpot(BTC_USD_FEED);
        return response.price;
    }
}
