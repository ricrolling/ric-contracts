// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract RICRegistry {
    uint256 immutable chainid;
    uint256 public queueTimeout;
    uint256 public providerStakeAmount;

    // struct L1Addresses {
    //     address SystemConfigProxy;
    //     address L1ERC721Bridge;
    //     address L1CrossDomainMessengerProxy;
    //     address OptimismMintableERC20Factory;
    //     address L2OutputOracleProxy;
    //     address L1CrossDomainMessenger;
    //     address ProxyAdmin;
    //     address OptimismPortalProxy;
    //     address L2OutputOracle;
        // address SystemConfig;
        // address L1ERC721BridgeProxy;
        // address DisputeGameFactory;
        // address AddressManager;
        // address L1StandardBridge;
        // address L1StandardBridgeProxy;
        // address OptimismMintableERC20FactoryProxy;
        // address OptimismPortal;
        // address DisputeGameFactoryProxy;
    // }



    struct Status {
        RollupStatus status;
        address provider;
        uint256 queuedTimestamp;
        uint256 chainID;
        bytes config;
    }

    enum RollupStatus {
        REQUESTED,
        QUEUED,
        ACTIVATED
    }

    mapping(uint256 => bytes) public activatedRollupsL1Addresses;
    mapping(uint256 => Status) public rollupStatus;

    mapping(address => uint256) public providerStake;

    event rollupRequested(uint256 chainID, address requester, uint256 timestamp);
    event rollupQueued(uint256 chainID, address provider, uint256 requestedTimestamp, uint256 timeoutTimestamp);
    event rollupActivated(uint256 chainID, address provider);

    event providerStaked(address provider);
    event providerUnstaked(address provider);
    event providerSlashed(address provider, address slasher);

    constructor(uint256 _queueTimeout, uint256 _providerStakeAmount) {
        chainid = block.chainid;
        queueTimeout = _queueTimeout;
        providerStakeAmount = _providerStakeAmount;
    }

    function requestRollup(uint256 chainID_, bytes memory config) public {
        require(rollupStatus[chainID_].chainID == 0, "RICRegistry: chainID already exists");

        // set rollup status
        rollupStatus[chainID_] = Status({
            status: RollupStatus.REQUESTED,
            provider: address(0),
            queuedTimestamp: block.timestamp,
            chainID: chainID_,
            config: config
        });

        // emit event

        emit rollupRequested(chainID_, msg.sender, block.timestamp);
    }

    function queueRollup(uint256 chainID_) public {
        require(providerStake[msg.sender] >= providerStakeAmount, "RICRegistry: provider does not have enough stake");
        require(rollupStatus[chainID_].chainID != 0, "RICRegistry: chainID does not exist");
        require(
            rollupStatus[chainID_].status == RollupStatus.REQUESTED
                || block.timestamp - rollupStatus[chainID_].queuedTimestamp >= queueTimeout,
            "RICRegistry: rollup not in REQUESTED status or timeout not reached"
        );

        if (
            rollupStatus[chainID_].status == RollupStatus.QUEUED
                && block.timestamp - rollupStatus[chainID_].queuedTimestamp >= queueTimeout
        ) {
            // slash previous provider and set new provider as queued
            _slashProvider(rollupStatus[chainID_].provider);
        }

        // set rollup status
        rollupStatus[chainID_].status = RollupStatus.QUEUED;
        rollupStatus[chainID_].provider = msg.sender;
        rollupStatus[chainID_].queuedTimestamp = block.timestamp;

        // emit event
        emit rollupQueued(chainID_, msg.sender, block.timestamp, block.timestamp + queueTimeout);
    }

    function deployRollup(uint256 chainID_, bytes calldata l1Addresses_) public {
        require(rollupStatus[chainID_].chainID != 0, "RICRegistry: chainID does not exist");
        require(rollupStatus[chainID_].status == RollupStatus.QUEUED, "RICRegistry: rollup not in QUEUED state");
        require(rollupStatus[chainID_].provider == msg.sender, "RICRegistry: msg.sender is not the provider");

        // set rollup status
        rollupStatus[chainID_].status = RollupStatus.ACTIVATED;

        // set l1 addresses
        activatedRollupsL1Addresses[chainID_] = l1Addresses_;

        // emit event
        emit rollupActivated(chainID_, msg.sender);
    }

    // provider stuff
    function _slashProvider(address provider) internal {
        // slash provider
        providerStake[provider] -= providerStakeAmount;
        payable(msg.sender).transfer(providerStakeAmount);

        emit providerSlashed(provider, msg.sender);
    }

    function stakeAsProvider() public payable {
        require(msg.value == providerStakeAmount, "RICRegistry: incorrect amount of ETH sent");
        require(providerStake[msg.sender] == 0, "RICRegistry: provider already has stake");

        providerStake[msg.sender] = providerStakeAmount;
        emit providerStaked(msg.sender);
    }

    function providerUnstake() public {
        require(providerStake[msg.sender] == providerStakeAmount, "RICRegistry: provider does not have stake");
        providerStake[msg.sender] = 0;
        payable(msg.sender).transfer(providerStakeAmount);
        emit providerUnstaked(msg.sender);
    }

    function getRollupStatus(uint256 chainID_) public view returns (Status memory) {
        return rollupStatus[chainID_];
    }
}

