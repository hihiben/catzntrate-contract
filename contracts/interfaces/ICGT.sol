//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICGT is IERC20 {
    function minters(address minter) external returns (bool);

    function addMinter(address minter) external;

    function removeMinter(address minter) external;

    function mint(address to, uint256 amount) external;
}
