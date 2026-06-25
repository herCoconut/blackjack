// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RandomOneTwo.sol";

contract RandomOneTwoTest is Test {
    RandomOneTwo randomOneTwo;

    function setUp() public {
        randomOneTwo = new RandomOneTwo();
    }

    function testRandomReturnsOneOrTwo() public {
        uint256 value = randomOneTwo.random();
        assertTrue(value == 1 || value == 2, "Value must be 1 or 2");
    }

    function testPeekReturnsOneOrTwo() public {
        uint256 value = randomOneTwo.peek(123);
        assertTrue(value == 1 || value == 2, "Value must be 1 or 2");
    }

    function testRandomDistribution() public {
        uint256 ones;
        uint256 twos;

        for (uint256 i = 0; i < 20; i++) {
            uint256 value = randomOneTwo.random();
            if (value == 1) {
                ones++;
            } else {
                twos++;
            }
        }

        assertTrue(ones + twos == 20, "Should generate 20 values");
        assertTrue(ones > 0, "Should generate at least one 1");
        assertTrue(twos > 0, "Should generate at least one 2");
    }
}
