//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CatzFood is ERC20, Ownable {
    // Storage
    mapping(address => bool) public minters;
    IERC20 public cft;
    uint256 public price;

    // Event
    event MinterAdded(address minter);
    event MinterRemoved(address minter);

    modifier onlyMinter() {
        require(minters[msg.sender], "Not minter");
        _;
    }

    constructor(IERC20 _cft, uint256 _price) ERC20("Catz Food", "CF") {
        cft = _cft;
        price = _price;
    }

    function buy(address to, uint256 amount) external {
        uint256 cost = amount * price;
        cft.transferFrom(msg.sender, address(this), cost);
        _mint(to, amount);
    }
}
