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

    // storage
    mapping(uint256 => CatzInfo) public catzInfos;
    Catz public catz;

    // event
    event WorkStarted(uint256 id);

    // error
    error InvalidState(State current);
    error InvalidOwner(address current);
    error InvalidCatz(uint256 id);

    modifier whenState(uint256 id, State expected) {
        State current = catzInfos[id].state;
        if (current != expected) {
            revert InvalidState(current);
        }
        _;
    }

    modifier whenStates(
        uint256 id,
        State expected1,
        State expected2
    ) {
        State current = catzInfos[id].state;
        if (current != expected1 && current != expected2) {
            revert InvalidState(current);
        }
        _;
    }

    modifier whenNotState(uint256 id, State unexpected) {
        State current = catzInfos[id].state;
        if (current == unexpected) {
            revert InvalidState(current);
        }
        _;
    }

    modifier isValidCatz(uint256 id) {
        if (!catz.isValidCatz(id)) {
            revert InvalidCatz(id);
        }
        _;
    }

    modifier isOwner(uint256 id) {
        address owner = catz.ownerOf(id);
        if (msg.sender != owner) {
            revert InvalidOwner(msg.sender);
        }
        _;
    }

    constructor() {
        catz = new Catz();
    }

    function catzIs(uint256 id) external view returns (State) {
        State state = catzInfos[id].state;
        require(state != State.Invalid && state < State.End, "Invalid");

        return state;
    }

    function workStart(uint256 id, uint256 timestamp)
        external
        whenState(id, State.Idle)
        isValidCatz(id)
        isOwner(id)
    {}

    function workPause(uint256 id, uint256 timestamp)
        external
        whenState(id, State.Working)
        isValidCatz(id)
        isOwner(id)
    {}

    function workStop(uint256 id, uint256 timestamp)
        external
        whenStates(id, State.Working, State.Waiting)
        isValidCatz(id)
        isOwner(id)
    {}

    function pet(uint256 id, uint256 timestamp)
        external
        whenState(id, State.Resting)
        isValidCatz(id)
        isOwner(id)
    {}

    function feed(uint256 id)
        external
        whenNotState(id, State.Working)
        isValidCatz(id)
        isOwner(id)
    {}

    function levelUp(uint256 id)
        external
        whenNotState(id, State.Working)
        isValidCatz(id)
        isOwner(id)
    {}

    function getStats(uint256 id)
        external
        returns (
            uint256 efficiency,
            uint256 curiosity,
            uint256 luck,
            uint256 vitality
        )
    {}

    function addStats(
        uint256 id,
        uint256 efficiency,
        uint256 curiosity,
        uint256 luck,
        uint256 vitality
    ) external whenNotState(id, State.Working) {}
}
