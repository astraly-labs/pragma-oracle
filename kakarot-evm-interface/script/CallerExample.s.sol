// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {CallerExample} from "../src/CallerExample.sol";

contract DeployCallerExample is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("EVM_PRIVATE_KEY");
        address pragmaCallerAddress = vm.envAddress("EVM_PRAGMA_CALLER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        CallerExample callerExample = new CallerExample(pragmaCallerAddress);
        console2.log("CallerExample deployed at:", address(callerExample));

        vm.stopBroadcast();
    }
}
