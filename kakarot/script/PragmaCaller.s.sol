// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {Script, console2} from "forge-std/Script.sol";
import {PragmaCaller} from "../src/PragmaCaller.sol";

contract DeployPragmaCaller is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 pragmaOracleAddress = vm.envUint("PRAGMA_ORACLE_DEPLOYED_CAIRO_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        PragmaCaller pragmaCaller = new PragmaCaller(pragmaOracleAddress);

        console2.log("PragmaCaller deployed at:", address(pragmaCaller));

        vm.stopBroadcast();
    }
}
