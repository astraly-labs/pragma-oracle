// SPDX-License-Identifier: Apache 2
pragma solidity >=0.7.0 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {PragmaAggregatorV3} from "../src/PragmaAggregatorV3.sol";

contract DeployPragmaAggregatorV3 is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address pragmaCallerAddress = vm.envAddress("PRAGMA_CALLER_DEPLOYED_ADDRESS");
        
        uint256 pairId = vm.envUint("PAIR_ID");

        vm.startBroadcast(deployerPrivateKey);

        PragmaAggregatorV3 aggregator = new PragmaAggregatorV3(pragmaCallerAddress, pairId);
        
        console2.log("PragmaAggregatorV3 deployed for pair ID", pairId, "at:", address(aggregator));

        vm.stopBroadcast();
    }
}
