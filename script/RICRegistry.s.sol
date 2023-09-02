pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import "../src/RICRegistry.sol";

contract RICRegistryScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        RICRegistry registry = new RICRegistry(3600, 1 ether);

        // stake 1 ether for each provider
        registry.stakeAsProvider{value: 1 ether}();

        bytes memory config = abi.encodePacked("config");

        // stake 1 ether for each provider
        registry.requestRollup("first rollup", 69, config);

        vm.stopBroadcast();
    }
}
