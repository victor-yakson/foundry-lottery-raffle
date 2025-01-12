// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, codeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubcription is Script {
    function createSubcriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId, ) = createSubcription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubcription(
        address _vrfCoordinator,
        address _account
    ) public returns (uint256, address) {
        console.log("creating subcription on Chain ID", block.chainid);

        vm.startBroadcast(_account);
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your Subcription Id:", subId);
        return (subId, _vrfCoordinator);
    }

    function run() public {
        createSubcriptionUsingConfig();
    }
}

contract FundSubscription is Script, codeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(
        address _vrfCoordinator,
        uint256 _subscriptionId,
        address _linkToken,
        address _account
    ) public {
        console.log("Funding subcription", _subscriptionId);
        console.log("using vrfcoordinator", _vrfCoordinator);
        console.log("On chainId:", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(_account);
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(
                _subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_account);
            LinkToken(_linkToken).transferAndCall(
                _vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address _mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;

        addConsumer(_mostRecentlyDeployed, vrfCoordinator, subId, account);
    }

    function addConsumer(
        address _contractToAddToVrf,
        address _vrfCoordinator,
        uint256 _subId,
        address _account
    ) public {
        console.log("adding consumer contract:", _contractToAddToVrf);
        console.log("To vrfcoordinator:", _vrfCoordinator);
        console.log("on Chainid:", block.chainid);

        vm.startBroadcast(_account);
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(
            _subId,
            _contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    function run() external {
        address contractAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );

        addConsumerUsingConfig(contractAddress);
    }
}
