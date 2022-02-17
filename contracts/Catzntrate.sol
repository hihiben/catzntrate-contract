//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Catz.sol";

contract Catzntrate {
    enum State {
        Invalid,
        Idle,
        Working,
        Waiting,
        Resting,
        End
    }

    struct CatzInfo {
        State state;
        uint256 level;
        uint256 energy;
        uint256 saturation;
        uint256 skillPoint;
        uint256 efficiency;
        uint256 curiosity;
        uint256 luck;
        uint256 vitality;
    }

    mapping(uint256 => CatzInfo) public catzInfos;
    Catz public catz;

    constructor() {
        catz = new Catz();
    }

    function catzIs(uint256 id) external view returns (uint256) {
        uint256 state = catzInfos[id].state;
        require(state != 0 && state < State.End, "Invalid");

        return state;
    }

    function workStart(uint256 id, uint256 timestamp) external {}

    function workPause(uint256 id, uint256 timestamp) external {}

    function workStop(uint256 id, uint256 timestamp) external {}

    function pet(uint256 id) external {}

    function feed(uint256 id) external {}

    function levelUp(uint256 id) external {}

    function getStats(uint256 id) external returns () {}

    function addStats(
        uint256 id,
        uint256 efficiency,
        uint256 curiosity,
        uint256 luck,
        uint256 vitality
    ) external {}
}
