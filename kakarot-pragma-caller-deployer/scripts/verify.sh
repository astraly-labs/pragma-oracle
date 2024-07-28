forge verify-contract $PRAGMA_CALLER_DEPLOYED_ADDRESS src/PragmaCaller.sol:PragmaCaller \
--rpc-url $RPC_URL \
--verifier-url $ETHERSCAN_VERIFY_URL \
--etherscan-api-key "verifyContract" \
--num-of-optimizations 200 \
--compiler-version v0.8.26+commit.8a97fa7a \
--constructor-args $(cast abi-encode "constructor(uint256 pragmaOracleAddress)" $PRAGMA_ORACLE_DEPLOYED_CAIRO_ADDRESS)
