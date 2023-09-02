// SPDX-License-Identifier: UNLICENSED
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/RICRegistry.sol";
import "./utils/UserFactory.sol";

pragma solidity ^0.8.13;

contract RICRegistryTest is Test {
    address public deployer;

    address userOne;
    address userTwo;
    address providerOne;
    address providerTwo;

    uint256 timeout;
    uint256 providerStakeAmount;

    bytes config;
    bytes err;

    UserFactory public userFactory;
    RICRegistry public registry;

    function setUp() public {
        userFactory = new UserFactory();
        address[] memory users = userFactory.create(5);
        deployer = users[0];
        userOne = users[1];
        userTwo = users[2];
        providerOne = users[3];
        providerTwo = users[4];

        timeout = 3600;
        providerStakeAmount = 1 ether;

        config = abi.encodePacked("config");

        // distribute eth to each user
        for (uint i = 0; i < users.length; i++) {
            vm.deal(users[i], 10 ether);
        }

        // deploy RICRegistry
        vm.prank(deployer);
        registry = new RICRegistry(timeout, providerStakeAmount);

        // stake 1 ether for each provider
        vm.prank(providerOne);
        registry.stakeAsProvider{value: providerStakeAmount}();

        vm.prank(providerTwo);
        registry.stakeAsProvider{value: providerStakeAmount}();
    }

    function test_RollupRequested() public {
        uint chainid = 69;

        _requestRollup(userOne, chainid);

        RICRegistry.Status memory status = registry.getRollupStatus(chainid);

        assertEq(uint(status.status), uint(RICRegistry.RollupStatus.REQUESTED));
        assertEq(status.provider, address(0));
        assertEq(status.queuedTimestamp, block.timestamp);
        assertEq(status.chainID, chainid);
        assertEq(status.config, config);

        err = bytes("RICRegistry: chainID already exists");
        vm.expectRevert(err);
        _requestRollup(userTwo, chainid);
    }

    function test_RollupQueued() public {
        uint chainid = 69;

        _requestRollup(userOne, chainid);

        // cannot claim rollup if not staked

        err = bytes("RICRegistry: provider does not have enough stake");
        vm.expectRevert(err);
        _queueRollup(userTwo, chainid);

        // cannot claim rollup if not requested

        err = bytes("RICRegistry: chainID does not exist");
        vm.expectRevert(err);
        _queueRollup(providerTwo, 70);

        // can claim rollup if staked and requested

        _queueRollup(providerOne, chainid);

        RICRegistry.Status memory status = registry.getRollupStatus(chainid);

        assertEq(uint(status.status), uint(RICRegistry.RollupStatus.QUEUED));
        assertEq(status.provider, providerOne);
        assertEq(status.queuedTimestamp, block.timestamp);
        assertEq(status.chainID, chainid);
        assertEq(status.config, config);

        // cannot claim rollup if already claimed
        err = bytes("RICRegistry: rollup not in REQUESTED status or timeout not reached");
        vm.expectRevert(err);
        _queueRollup(providerOne, chainid);
    }

    function test_RollupQueuedAndExpired() public {
        uint chainid = 69;

        _requestRollup(userOne, chainid);

        // providerOne queues rollup
        _queueRollup(providerOne, chainid);

        // try to queue rollup again before timeout
        err = bytes("RICRegistry: rollup not in REQUESTED status or timeout not reached");
        vm.expectRevert(err);
        _queueRollup(providerTwo, chainid);

        RICRegistry.Status memory status = registry.getRollupStatus(chainid);

        // warp to timeout
        vm.warp(status.queuedTimestamp + timeout + 1);

        // providerTwo queues rollup after timeout
        _queueRollup(providerTwo, chainid);

        // assert new values
        status = registry.getRollupStatus(chainid);

        assertEq(uint(status.status), uint(RICRegistry.RollupStatus.QUEUED));
        assertEq(status.provider, providerTwo);
        assertEq(status.queuedTimestamp, block.timestamp);
        assertEq(status.chainID, chainid);
        assertEq(status.config, config);

        // assert providerOne slashed
        assertEq(registry.providerStake(providerOne), 0);
        assertEq(providerTwo.balance, 10 ether);
    }

    function test_RollupActivated() public {
        uint chainid = 69;

        // userOne requests rollup
        _requestRollup(userOne, chainid);

        // providerOne queues rollup
        _queueRollup(providerOne, chainid);


        bytes memory l1Addresses = abi.encodePacked("l1Addresses");

        // // providerOne activates rollup
        // registry._activateRollup(providerOne, chainid, l1Addresses);

        // RICRegistry.Status memory status = registry.getRollupStatus(chainid);

        // assertEq(uint(status.status), uint(RICRegistry.RollupStatus.ACTIVATED));
        // assertEq(status.provider, providerOne);
        // assertEq(status.queuedTimestamp, block.timestamp);
        // assertEq(status.chainID, chainid);
        // assertEq(status.config, config);

        // // cannot activate rollup if not queued
        // err = bytes("RICRegistry: rollup not in QUEUED status");
        // vm.expectRevert(err);
        // registry.activateRollup(chainid);

        // // cannot activate rollup if already activated
        // err = bytes("RICRegistry: rollup not in QUEUED status");
        // vm.expectRevert(err);
        // registry.activateRollup(chainid);
    }

    function _requestRollup(address _user,uint _chainid) internal {
        vm.prank(_user);
        registry.requestRollup(_chainid, config);
    }

    function _queueRollup(address _provider,uint _chainid) internal {
        vm.prank(_provider);
        registry.queueRollup(_chainid);
    }

    function _activateRollup(address _provider,uint _chainid, bytes memory _l1Addresses) internal {
        vm.prank(_provider);
        registry.deployRollup(_chainid, _l1Addresses);
    }

}

