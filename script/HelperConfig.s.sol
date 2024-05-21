// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// This fill will be used for:
// 1. Deploy mocks when we are on a local anvil chain
// 2. Keep track of contract address across different chains

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Agreggator.sol";

contract HelperConfig is Script {
    // If we are on a local anvil, we deploy mocks
    // Otherwise, grab the existing address from the live network

    uint8 public constant DECIMALS = 8;
    int256 public constant INTIAL_ANSWER = 2000e8;

    NetworkConfig public activeNetworkingConfig;

    constructor() {
        // 11155111 is Sepolia chain id. Check in https://chainlist.org/
        if (block.chainid == 11155111) {
            activeNetworkingConfig = getSepoliaETHConfig();
        } else if (block.chainid == 1) {
            activeNetworkingConfig = getMainnetETHConfig();
        } else {
            activeNetworkingConfig = getOrCreateAnvilETHConfig();
        }
    }

    struct NetworkConfig {
        address priceFeed;
    }

    function getSepoliaETHConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
            });
    }

    function getMainnetETHConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
            });
    }

    function getOrCreateAnvilETHConfig() public returns (NetworkConfig memory) {

        // If activeNetworkingConfig.priceFeed doesn't have the default value (nothing was assigned yet), return the existing address
        if (activeNetworkingConfig.priceFeed != address(0)) {
            return activeNetworkingConfig;
        }

        // 1. Deploy the mocks
        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INTIAL_ANSWER
        );
        vm.stopBroadcast();

        // 2. Return the address of the mocks
        return NetworkConfig({priceFeed: address(mockPriceFeed)});
    }
}
