// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {CallerExample} from "../src/CallerExample.sol";

contract DeployCallerExample is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address pragmaCallerAddress = vm.envAddress("PRAGMA_CALLER_DEPLOYED_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        CallerExample callerExample = new CallerExample(pragmaCallerAddress);

        console2.log("CallerExample deployed at:", address(callerExample));

        vm.stopBroadcast();
    }
}
