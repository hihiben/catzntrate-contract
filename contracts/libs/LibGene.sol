//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibGene {
    uint256 constant private _EFFICIENCY_OFFSET = 0;
    uint256 constant private _CURIOSITY_OFFSET = 8;
    uint256 constant private _LUCK_OFFSET = 16;
    uint256 constant private _VITALITY_OFFSET = 24;
    bytes32 constant private _GENDER_MASK = 0x0000000000000000000000000000000000000000000000010000000000000000;

    function gender(bytes32 gene) internal returns (bool) {
        return (gene & _GENDER_MASK) != 0;
    }

    function efficiency(bytes32 gene) internal returns (uint8) {
        return uint8(bytes1(gene));
    }

    function curiosity(bytes32 gene) internal returns (uint8) {
        return uint8(bytes1(gene >> _CURIOSITY_OFFSET));
    }

    function luck(bytes32 gene) internal returns (uint8) {
        return uint8(bytes1(gene >> _LUCK_OFFSET));
    }

    function vitality(bytes32 gene) internal returns (uint8) {
        return uint8(bytes1(gene >> _VITALITY_OFFSET));
    }
}
