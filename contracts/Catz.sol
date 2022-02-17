//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Catz is ERC721, Ownable {
    struct CatzInfo {
        // 0000000000000000 0000000000000000 0000000000000000 00 00 00 00 00 00 00 00
        bytes32 gene;
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

    modifier onlyBreeder() {
        if (!breeders[msg.sender]) {
            revert InvalidBreeder(msg.sender);
        }
        _;
    }

    constructor() ERC721("Catz", "CATZ") {}

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

    function breedCatz(bytes32 gene, address to) external onlyBreeder {
        uint256 id = catzs.length;
        catzs.push(CatzInfo(gene));
        _safeMint(to, id);

        emit CatzBorn(id, to, gene);
    }

    function isValidCatz(uint256 id) external view returns (bool) {
        return _exists(id);
    }
}
