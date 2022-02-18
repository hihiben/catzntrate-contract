//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ICatz is IERC721 {
    struct CatzInfo {
        // 0000000000000000 0000000000000000 0000000000000000 00 00 00 00 00 00 00 00
        bytes32 gene;
    }

    function breeders(address breeder) external view returns (bool);

    function getCatz(uint256 id)
        external
        view
        returns (bytes32 gene, uint256 birthday);

    function addBreeder(address breeder) external;

    function removeBreeder(address breeder) external;

    function isValidCatz(uint256 id) external view returns (bool);

    function catzs(uint256) external view returns (CatzInfo memory);

    function breedCatz(bytes32 gene, address to) external returns (uint256);
}
