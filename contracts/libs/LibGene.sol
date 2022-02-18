//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibGene {
    uint256 private constant _EFF_INDEX = 0;
    uint256 private constant _CUR_INDEX = 1;
    uint256 private constant _LUK_INDEX = 2;
    uint256 private constant _VIT_INDEX = 3;
    uint256 private constant _EFF_W_INDEX = 4;
    uint256 private constant _CUR_W_INDEX = 5;
    uint256 private constant _LUK_W_INDEX = 6;
    uint256 private constant _VIT_W_INDEX = 7;
    bytes32 private constant _GENDER_MASK =
        0x0000000000000000800000000000000000000000000000000000000000000000;

    function gender(bytes32 gene) internal pure returns (bool) {
        return (gene & _GENDER_MASK) != 0;
    }

    function efficiency(bytes32 gene) internal pure returns (uint8) {
        return uint8(gene[_EFF_INDEX]);
    }

    function curiosity(bytes32 gene) internal pure returns (uint8) {
        return uint8(gene[_CUR_INDEX]);
    }

    function luck(bytes32 gene) internal pure returns (uint8) {
        return uint8(gene[_LUK_INDEX]);
    }

    function vitality(bytes32 gene) internal pure returns (uint8) {
        return uint8(gene[_VIT_INDEX]);
    }

    function wEfficiency(bytes32 gene) internal pure returns (uint8) {
        return uint8(gene[_EFF_W_INDEX]);
    }

    function wCuriosity(bytes32 gene) internal pure returns (uint8) {
        return uint8(gene[_CUR_W_INDEX]);
    }

    function wLuck(bytes32 gene) internal pure returns (uint8) {
        return uint8(gene[_LUK_W_INDEX]);
    }

    function wVitality(bytes32 gene) internal pure returns (uint8) {
        return uint8(gene[_VIT_W_INDEX]);
    }
}
