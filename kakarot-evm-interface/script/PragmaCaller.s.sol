// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {PragmaCaller} from "../src/PragmaCaller.sol";

contract PragmaCallerScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("EVM_PRIVATE_KEY");
        uint256 pragmaOracleAddress = vm.envUint("CAIRO_PRAGMA_ORACLE_ADDRESS");
        uint256 pragmaSummaryStatsAddress = vm.envUint("CAIRO_PRAGMA_SUMMARY_STATS_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        PragmaCaller pragmaCaller = new PragmaCaller(pragmaOracleAddress, pragmaSummaryStatsAddress);
        console2.log("PragmaCaller deployed at:", address(pragmaCaller));

        vm.stopBroadcast();
    }
}
