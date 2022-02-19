//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ICatz.sol";
import "./interfaces/ICFT.sol";
import "./interfaces/ICGT.sol";
import "./libs/LibGene.sol";

contract Catzntrate {
    using LibGene for bytes32;

    enum State {
        Idle,
        Working,
        Waiting,
        Resting,
        Petting,
        End
    }

    struct CatzInfo {
        State state;
        uint256 level;
        uint256 exp;
        uint256 skillPoint;
        uint256 energy;
        uint256 hunger;
        bool rewardCgt;
        CatzAttr attr;
        uint256 counterStart;
        uint256 counter;
        uint256 rewardDebt;
        uint256 lastEatTime;
    }

    struct CatzAttr {
        uint256 eff;
        uint256 cur;
        uint256 luk;
        uint256 vit;
    }

    // constants
    uint256 private constant _LEVEL_MAX = 30;
    uint256 private constant _EXP_BASE = 50;
    uint256 private constant _EXP_UP = 25;
    uint256 private constant _SKILL_POINTS_UP = 4;
    uint256 private constant _HUNGER_LIMIT = 100;
    uint256 private constant _NORMAL_EAT_TIME = 40 * 60;
    uint256 private constant _WORK_EAT_TIME = 5 * 60;

    // storage
    mapping(uint256 => CatzInfo) public catzInfos;
    ICatz public catz;
    ICFT public cft;
    ICGT public cgt;
    uint256 public workTime;
    uint256 public restTime;
    uint256 public effMultiplier;
    uint256 public curMultiplier;
    uint256 public lukMultiplier;
    uint256 public vitMultiplier;
    uint256 public rewardCftMultiplier;
    uint256 public rewardCgtMultiplier;

    // event
    event WorkStarted(uint256 id, uint256 timestamp);
    event WorkPaused(uint256 id, uint256 timestamp);
    event WorkStopped(uint256 id, uint256 timestamp);
    event Resting(uint256 id, uint256 timestamp);
    event Petting(uint256 id, uint256 timestamp);
    event Feeded(uint256 id, uint256 timestamp);

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

    modifier updateState(uint256 id, uint256 timestamp) {
        _updateState(id, timestamp);
        _;
    }

    constructor(
        ICatz catz_,
        ICFT cft_,
        ICGT cgt_
    ) {
        catz = catz_;
        cft = cft_;
        cgt = cgt_;
        effMultiplier = 1;
        curMultiplier = 1;
        lukMultiplier = 1;
        vitMultiplier = 1;
        rewardCftMultiplier = 100;
        rewardCgtMultiplier = 1;
        workTime = 25 * 60;
        restTime = 5 * 60;
    }

    // Getters
    function getStats(uint256 id)
        public
        view
        returns (
            uint256 efficiency,
            uint256 curiosity,
            uint256 luck,
            uint256 vitality
        )
    {
        (bytes32 gene, ) = catz.getCatz(id);
        CatzAttr memory catzAttr = catzInfos[id].attr;
        efficiency = gene.efficiency() + catzAttr.eff * effMultiplier;
        curiosity = gene.curiosity() + catzAttr.cur * curMultiplier;
        luck = gene.luck() + catzAttr.luk * lukMultiplier;
        vitality = gene.vitality() + catzAttr.vit * vitMultiplier;
    }

    function getStates(uint256 id)
        external
        view
        returns (
            State state,
            uint256 level,
            uint256 skillPoint,
            uint256 energy,
            uint256 hunger,
            bool gender
        )
    {
        CatzInfo memory catzInfo = catzInfos[id];
        (bytes32 gene, ) = catz.getCatz(id);
        return (
            catzInfo.state,
            catzInfo.level,
            catzInfo.skillPoint,
            catzInfo.energy,
            catzInfo.hunger,
            gene.gender()
        );
    }

    function getHungerLimit(uint256 id) internal view returns (uint256) {
        (, , , uint256 vit) = getStats(id);
        return vit + _HUNGER_LIMIT;
    }

    // Actions
    function workStart(uint256 id, uint256 timestamp)
        external
        updateState(id, timestamp)
        whenState(id, State.Idle)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        require(catzInfo.counterStart == 0, "Should be initial work");
        require(catzInfo.rewardDebt == 0, "Should be no reward debt");
        catzInfo.state = State.Working;
        catzInfo.counterStart = timestamp;
        catzInfo.counter = workTime;
    }

    function workPause(uint256 id, uint256 timestamp)
        external
        updateState(id, timestamp)
        whenState(id, State.Working)
        isValidCatz(id)
        isOwner(id)
    {
        (uint256 eff, , , ) = getStats(id);
        uint256 timePassed = timestamp - catzInfos[id].counterStart;
        CatzInfo storage catzInfo = catzInfos[id];
        catzInfo.counter -= timePassed;
        catzInfo.state = State.Waiting;
        catzInfo.rewardDebt = _calReward(
            eff,
            timePassed,
            catzInfo.rewardCgt ? rewardCgtMultiplier : rewardCftMultiplier
        );
    }

    function workUnpause(uint256 id, uint256 timestamp)
        external
        updateState(id, timestamp)
        whenState(id, State.Waiting)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        catzInfo.state = State.Working;
        catzInfo.counterStart = timestamp;
    }

    function workStop(uint256 id, uint256 timestamp)
        external
        updateState(id, timestamp)
        whenStates(id, State.Working, State.Waiting)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        catzInfo.state = State.Idle;
        catzInfo.counterStart = 0;
        catzInfo.counter = 0;
        catzInfo.rewardDebt = 0;
    }

    function pet(uint256 id, uint256 timestamp)
        external
        updateState(id, timestamp)
        whenState(id, State.Resting)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        catzInfo.state = State.Petting;
        uint256 reward = catzInfo.rewardDebt;
        catzInfo.rewardDebt = 0;
        // Send reward
        if (catzInfo.rewardCgt) {
            cgt.mint(msg.sender, reward);
        } else {
            cft.mint(msg.sender, reward);
        }
    }

    function feed(
        uint256 id,
        uint256 timestamp,
        uint256 amount
    )
        external
        updateState(id, timestamp)
        whenNotState(id, State.Working)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        catzInfo.hunger -= amount;
        // feed
    }

    // Stats actions
    function levelUp(uint256 id, uint256 timestamp)
        external
        updateState(id, timestamp)
        whenNotState(id, State.Working)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        require(catzInfo.exp == _getLevelExp(id), "exp insufficient");
        if (catzInfo.level < _LEVEL_MAX) {
            catzInfo.level++;
            catzInfo.exp = 0;
            catzInfo.skillPoint += _SKILL_POINTS_UP;
        }
    }

    function addStats(
        uint256 id,
        uint256 timestamp,
        CatzAttr calldata attr
    )
        external
        updateState(id, timestamp)
        whenNotState(id, State.Working)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        {
            uint256 sum = attr.eff + attr.cur + attr.luk + attr.vit;
            catzInfo.skillPoint -= sum;
        }
        catzInfo.attr.eff += attr.eff;
        catzInfo.attr.cur += attr.cur;
        catzInfo.attr.luk += attr.luk;
        catzInfo.attr.vit += attr.vit;
    }

    function setRewardCgt(
        uint256 id,
        uint256 timestamp,
        bool flag
    )
        external
        updateState(id, timestamp)
        whenState(id, State.Idle)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        if (flag) {
            require(catzInfo.level == 29, "Level too low");
        }
        catzInfo.rewardCgt = flag;
    }

    // Internals
    function _updateState(uint256 id, uint256 timestamp) internal {
        CatzInfo storage catzInfo = catzInfos[id];
        if (catzInfo.state == State.Idle) {
            _dine(id, timestamp, _NORMAL_EAT_TIME);
        } else if (catzInfo.state == State.Working) {
            // Verify going to Resting or not
            uint256 timeInterval = timestamp - catzInfo.counterStart;
            if (timeInterval > catzInfo.counter) {
                (uint256 efficiency, , , ) = getStats(id);
                uint256 workingTime = _dine(
                    id,
                    catzInfo.counterStart + catzInfo.counter,
                    _WORK_EAT_TIME
                );
                catzInfo.rewardDebt = _calReward(
                    efficiency,
                    workingTime,
                    catzInfo.rewardCgt
                        ? rewardCgtMultiplier
                        : rewardCftMultiplier
                );
                catzInfo.counterStart += catzInfo.counter;
                catzInfo.counter = restTime;
                catzInfo.state = State.Resting;
            } else {
                _dine(id, timestamp, _WORK_EAT_TIME);
            }
        } else if (catzInfo.state == State.Waiting) {
            _dine(id, timestamp, _NORMAL_EAT_TIME);
        } else if (catzInfo.state == State.Resting) {
            _dine(id, timestamp, _NORMAL_EAT_TIME);
        } else if (catzInfo.state == State.Petting) {
            _dine(id, timestamp, _NORMAL_EAT_TIME);
            // Verify going to Working or not
            uint256 timeInterval = timestamp - catzInfo.counterStart;
            if (timeInterval > catzInfo.counter) {
                _dine(
                    id,
                    catzInfo.counterStart + catzInfo.counter,
                    _NORMAL_EAT_TIME
                );
                catzInfo.counterStart += catzInfo.counter;
                catzInfo.counter = workTime;
                catzInfo.state = State.Working;
            } else {
                _dine(id, timestamp, _NORMAL_EAT_TIME);
            }
        } else {
            revert("Invalid state");
        }
    }

    function _getLevelExp(uint256 id) internal view returns (uint256) {
        uint256 level = catzInfos[id].level;
        return _EXP_BASE + ((_EXP_UP * level) / 2);
    }

    function _dine(
        uint256 id,
        uint256 timestamp,
        uint256 eatSpeed
    ) internal returns (uint256 eatTime) {
        CatzInfo storage catzInfo = catzInfos[id];
        uint256 limit = getHungerLimit(id);
        uint256 eat = (timestamp - catzInfo.lastEatTime) / eatSpeed;
        uint256 food = limit - catzInfo.hunger;
        if (food > eat) {
            catzInfo.hunger += eat;
            eatTime = eat * eatSpeed;
        } else {
            catzInfo.hunger = limit;
            eatTime = food * eatSpeed;
        }
        catzInfo.lastEatTime = timestamp;
    }

    function _calReward(
        uint256 eff,
        uint256 time,
        uint256 multiplier
    ) internal pure returns (uint256) {
        return eff * time * multiplier;
    }
}
