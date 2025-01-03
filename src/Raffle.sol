// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/*
 *@title A sample Raffle contract
 *@author web3batman
 *@notice This contract is for creating a sample Raffle contract
 *@dev Implements Chainlink VRFv2.5
 */

contract Raffle {
    /*Errors */
    error Raffle__SendMoreEthToEnterRaffle();

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    //@dev The durations of the lottery in seconds
    uint256 private immutable i_interval;
    // Events

    event RaffleEntered(address indexed player);

    constructor(uint256 enteranceFee, uint256 interval) {
        i_entranceFee = enteranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value >= i_entranceFee) {
            revert Raffle__SendMoreEthToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function pickWinner() external view {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
    }

    /* GETTER FUNCTIONS */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
