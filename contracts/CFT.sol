//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CFT is ERC20, Ownable {
    // Storage
    mapping(address => bool) public minters;

    // Event
    event MinterAdded(address minter);
    event MinterRemoved(address minter);

    modifier onlyMinter() {
        require(minters[msg.sender], "Not minter");
        _;
    }

    constructor() ERC20("Catz Food Token", "CFT") {}

    function addMinter(address minter) external onlyOwner {
        require(!minters[minter], "Already minter");
        minters[minter] = true;

        emit MinterAdded(minter);
    }

    function removeMinter(address minter) external onlyOwner {
        require(minters[minter], "Not minter");
        minters[minter] = false;

        emit MinterRemoved(minter);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }
}
