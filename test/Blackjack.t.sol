// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2Mock} from "chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {Blackjack} from "../src/Blackjack.sol";

contract BlackjackTest is Test {
    Blackjack public blackjack;
    VRFCoordinatorV2Mock public vrfCoordinator;
    address public player = address(0x123);
    uint64 public subId;
    bytes32 public keyHash = keccak256("keyhash");
    uint16 public requestConfirmations = 3;
    uint32 public callbackGasLimit = 200000;

    function setUp() public {
        vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 1e9);
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 100 ether);

        blackjack = new Blackjack(
            address(vrfCoordinator),
            subId,
            keyHash,
            requestConfirmations,
            callbackGasLimit
        );

        vrfCoordinator.addConsumer(subId, address(blackjack));
        vm.deal(address(blackjack), 10 ether);
        vm.deal(player, 5 ether);
    }

    function test_PlayAndFulfillRandomWords() public {
        uint256 betAmount = 0.01 ether;
        vm.prank(player);
        uint256 requestId = blackjack.play{value: betAmount}();

        (address gamePlayer, uint256 gameBet, bool exists) = blackjack.games(requestId);
        assertEq(gamePlayer, player);
        assertEq(gameBet, betAmount);
        assertTrue(exists);

        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("blackjack-seed"));

        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(blackjack), words);

        (, , bool existsAfter) = blackjack.games(requestId);
        assertFalse(existsAfter);
    }
}
