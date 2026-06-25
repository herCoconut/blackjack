// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract RandomOneTwo {
    uint256 private nonce;

    event Generated(address indexed caller, uint256 result);

    function random() public returns (uint256) {
        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    msg.sender,
                    nonce
                )
            )
        );

        nonce += 1;
        uint256 result = (rand % 2) + 1;

        emit Generated(msg.sender, result);
        return result;
    }

    function peek(uint256 seed) public view returns (uint256) {
        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    msg.sender,
                    seed
                )
            )
        );

        return (rand % 2) + 1;
    }
}
