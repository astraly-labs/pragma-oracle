// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {PragmaAggregatorV3} from "../src/PragmaAggregatorV3.sol";

contract DeployPragmaAggregatorV3 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("EVM_PRIVATE_KEY");
        address pragmaCallerAddress = vm.envAddress("EVM_PRAGMA_CALLER_ADDRESS");
        uint256 pairId = vm.envUint("PAIR_ID");

        vm.startBroadcast(deployerPrivateKey);
        PragmaAggregatorV3 aggregator = new PragmaAggregatorV3(pragmaCallerAddress, pairId);
        console2.log("PragmaAggregatorV3 deployed for pair ID", pairId, "at:", address(aggregator));

        vm.stopBroadcast();
    }
}
