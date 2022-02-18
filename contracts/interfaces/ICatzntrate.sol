//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICatzntrate {
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

    function catzInfos(uint256) external view returns (CatzInfo memory);
}
