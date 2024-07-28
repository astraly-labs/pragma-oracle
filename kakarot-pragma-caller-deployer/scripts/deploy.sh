forge create \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY \
src/PragmaCaller.sol:PragmaCaller \
--constructor-args $PRAGMA_ORACLE_DEPLOYED_CAIRO_ADDRESS
