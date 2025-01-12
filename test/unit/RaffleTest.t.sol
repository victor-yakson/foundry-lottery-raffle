// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    Raffle public raffle;
    HelperConfig helperConfig;

    uint256 enteranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address public Player = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        enteranceFee = config.enteranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(Player, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(Player);
        // Act/ Assert
        vm.expectRevert(Raffle.Raffle__SendMoreEthToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(Player);
        // Act/ Assert
        raffle.enterRaffle{value: enteranceFee}();

        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == Player);
    }

    function testEnteringRaffleEmitEvents() public {
        // Arrange
        vm.prank(Player);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(Player);
        // Assert
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testDonotAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(Player);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        // Act /        // Assert

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(Player);
        raffle.enterRaffle{value: enteranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(Player);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // Assert

        assertFalse(upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIftimeHasNotPassed() public {
        // Arrange
        vm.prank(Player);
        raffle.enterRaffle{value: enteranceFee}();
        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assertFalse(upKeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(Player);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // Assert

        assertTrue(upKeepNeeded);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        // Arrange
        vm.prank(Player);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act/ Assert

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayer = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(Player);
        raffle.enterRaffle{value: enteranceFee}();
        currentBalance = currentBalance + enteranceFee;
        numPlayer = 1;

        // Act /Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayer,
                rState
            )
        );

        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(Player);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestID()
        public
        raffleEntered
    {
        // Arrange

        // Act

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Assert

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                          FULLFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public skipFork raffleEntered {
        // Arrange Act Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFullfullRandomWordsPicksAWinnerResetAndSendMoney()
        public
        skipFork
        raffleEntered
    {
        // Arrage
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: enteranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act

        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = enteranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
