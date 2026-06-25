// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {VRFConsumerBaseV2} from "chainlink/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "chainlink/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {ConfirmedOwner} from "chainlink/src/v0.8/shared/access/ConfirmedOwner.sol";

contract Blackjack is VRFConsumerBaseV2, ConfirmedOwner {
    enum Outcome {
        None,
        PlayerWin,
        DealerWin,
        Push
    }

    struct Game {
        address player;
        uint256 bet;
        bool exists;
    }

    VRFCoordinatorV2Interface public immutable COORDINATOR;
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint16 public requestConfirmations;
    uint32 public callbackGasLimit;
    uint256 public minBet;
    uint256 public maxBet;

    mapping(uint256 => Game) public games;

    event GameRequested(address indexed player, uint256 indexed requestId, uint256 bet);
    event GameResult(
        address indexed player,
        uint256 indexed requestId,
        Outcome outcome,
        uint8 playerScore,
        uint8 dealerScore,
        uint256 payout
    );

    error InvalidBet();
    error GameAlreadyExists();
    error UnknownRequest();
    error InsufficientPrizes();

    constructor(
        address vrfCoordinator,
        uint64 vrfSubscriptionId,
        bytes32 vrfKeyHash,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit_
    ) VRFConsumerBaseV2(vrfCoordinator) ConfirmedOwner(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = vrfSubscriptionId;
        keyHash = vrfKeyHash;
        requestConfirmations = minimumRequestConfirmations;
        callbackGasLimit = callbackGasLimit_;
        minBet = 0.01 ether;
        maxBet = 2 ether;
    }

    receive() external payable {}
    fallback() external payable {}

    function play() external payable returns (uint256 requestId) {
        if (msg.value < minBet || msg.value > maxBet) revert InvalidBet();
        if (address(this).balance < msg.value * 2) revert InsufficientPrizes();

        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );

        Game storage game = games[requestId];
        if (game.exists) revert GameAlreadyExists();

        games[requestId] = Game({player: msg.sender, bet: msg.value, exists: true});
        emit GameRequested(msg.sender, requestId, msg.value);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        Game storage game = games[requestId];
        if (!game.exists) revert UnknownRequest();

        uint256 seed = randomWords[0];
        (uint8 playerScore, uint8 dealerScore) = _resolveScores(seed);
        Outcome outcome = _determineOutcome(playerScore, dealerScore);
        uint256 payout = _payout(game.bet, outcome);

        if (payout > 0) {
            if (address(this).balance < payout) revert InsufficientPrizes();
            (bool sent, ) = payable(game.player).call{value: payout}("");
            require(sent, "Payout transfer failed");
        }

        emit GameResult(game.player, requestId, outcome, playerScore, dealerScore, payout);
        delete games[requestId];
    }

    function addConsumer() external onlyOwner {
        COORDINATOR.addConsumer(subscriptionId, address(this));
    }

    function updateSubscription(uint64 newSubscriptionId) external onlyOwner {
        subscriptionId = newSubscriptionId;
    }

    function withdraw(uint256 amount, address payable recipient) external onlyOwner {
        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Withdraw transfer failed");
    }

    function _resolveScores(uint256 seed) internal pure returns (uint8 playerScore, uint8 dealerScore) {
        uint8 playerCard1 = _cardValue(_randomCard(seed, 0));
        uint8 playerCard2 = _cardValue(_randomCard(seed, 1));
        uint8 dealerCard1 = _cardValue(_randomCard(seed, 2));
        uint8 dealerCard2 = _cardValue(_randomCard(seed, 3));

        playerScore = _handValue(playerCard1, playerCard2);
        dealerScore = _handValue(dealerCard1, dealerCard2);

        if (dealerScore < 17) {
            uint8 dealerCard3 = _cardValue(_randomCard(seed, 4));
            dealerScore = _addCard(dealerScore, dealerCard3);
        }
    }

    function _determineOutcome(uint8 playerScore, uint8 dealerScore) internal pure returns (Outcome) {
        if (playerScore > 21) {
            return Outcome.DealerWin;
        }
        if (dealerScore > 21) {
            return Outcome.PlayerWin;
        }
        if (playerScore > dealerScore) {
            return Outcome.PlayerWin;
        }
        if (playerScore == dealerScore) {
            return Outcome.Push;
        }
        return Outcome.DealerWin;
    }

    function _payout(uint256 bet, Outcome outcome) internal pure returns (uint256) {
        if (outcome == Outcome.PlayerWin) {
            return bet * 2;
        }
        if (outcome == Outcome.Push) {
            return bet;
        }
        return 0;
    }

    function _randomCard(uint256 seed, uint256 offset) internal pure returns (uint8) {
        return uint8((seed >> (offset * 8)) & 0xFF) % 13 + 1;
    }

    function _cardValue(uint8 card) internal pure returns (uint8) {
        if (card == 1) {
            return 11;
        }
        return card > 10 ? 10 : card;
    }

    function _handValue(uint8 a, uint8 b) internal pure returns (uint8) {
        uint8 total = a + b;
        if (total > 21 && (a == 11 || b == 11)) {
            total -= 10;
        }
        return total;
    }

    function _addCard(uint8 score, uint8 cardValue) internal pure returns (uint8) {
        uint8 total = score + cardValue;
        if (total > 21 && cardValue == 11) {
            total -= 10;
        }
        return total;
    }
}
