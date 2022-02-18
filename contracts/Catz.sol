//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Catz is ERC721, Ownable {
    struct CatzInfo {
        // 0000000000000000 0000000000000000 0000000000000000 00 00 00 00 00 00 00 00
        bytes32 gene;
        uint256 birthday;
    }

    // Storage
    CatzInfo[] private catzs;

    mapping(address => bool) public breeders;

    // Event
    event BreederAdded(address breeder);
    event BreederRemoved(address breeder);
    event CatzBorn(uint256 indexed id, address indexed owner, bytes32 gene);

    // Error
    error InvalidBreeder(address current);
    error InvalidCatz(uint256 id);

    modifier onlyBreeder() {
        if (!breeders[msg.sender]) {
            revert InvalidBreeder(msg.sender);
        }
        _;
    }

    modifier shouldBeValid(uint256 id) {
        if (!isValidCatz(id)) {
            revert InvalidCatz(id);
        }
        _;
    }

    constructor() ERC721("Catz", "CATZ") {}

    function getCatz(uint256 id)
        external
        view
        returns (bytes32 gene, uint256 birthday)
    {
        CatzInfo storage info = catzs[id];
        return (info.gene, info.birthday);
    }

    function addBreeder(address breeder) external onlyOwner {
        require(breeders[breeder] == false, "Already breeder");
        breeders[breeder] = true;

        emit BreederAdded(breeder);
    }

    function removeBreeder(address breeder) external onlyOwner {
        require(breeders[breeder] == false, "Not breeder");
        breeders[breeder] = true;

        emit BreederRemoved(breeder);
    }

    function breedCatz(bytes32 gene, address to)
        external
        onlyBreeder
        returns (uint256 id)
    {
        id = catzs.length;
        catzs.push(CatzInfo(gene, block.timestamp));
        _safeMint(to, id);

        emit CatzBorn(id, to, gene);
    }

    function isValidCatz(uint256 id) public view returns (bool) {
        return _exists(id);
    }
}
