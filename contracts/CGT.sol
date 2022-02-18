//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CGT is ERC20, Ownable {
    // Storage
    mapping(address => bool) public minters;

    // Constant
    uint256 private constant TOKEN_AMOUNT = 1 * 1e6 * 1e18;

    // Event
    event MinterAdded(address minter);
    event MinterRemoved(address minter);

    modifier onlyMinter() {
        require(minters[msg.sender], "Not minter");
        _;
    }

    constructor() ERC20("Catz Governance Token", "CGT") {
        _mint(msg.sender, TOKEN_AMOUNT);
    }

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
