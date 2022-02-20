//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ICatz.sol";
import "./interfaces/ICFT.sol";
import "./interfaces/ICGT.sol";
import "./interfaces/ICatzFood.sol";
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
        CatzLevel level;
        uint256 energy;
        uint256 hunger;
        bool rewardCgt;
        CatzAttr attr;
        uint256 counterStart;
        uint256 counter;
        uint256 rewardDebt;
        uint256 lastEatTime;
        uint256 lastRefillTime;
    }

    struct CatzLevel {
        uint256 level;
        uint256 exp;
        uint256 skillPoint;
    }

    struct CatzAttr {
        uint256 eff;
        uint256 cur;
        uint256 luk;
        uint256 vit;
    }

    struct UserInfo {
        uint256 level;
        uint256 earning;
    }

    // constants
    uint256 private constant _TIME_BASE = 1645261200;
    uint256 private constant _LEVEL_MAX = 30;
    uint256 private constant _EXP_BASE = 50;
    uint256 private constant _EXP_UP = 10;
    uint256 private constant _SKILL_POINTS_UP = 4;
    uint256 private constant _HUNGER_LIMIT_BASE = 100;
    uint256 private constant _EARN_LIMIT_BASE = 50;
    uint256 private constant _EARN_LEVEL = 3;
    uint256 private constant _EARN_LIMIT_UP = 10;
    uint256 private constant _ENERGY_MAX = 50;
    uint256 private constant _NORMAL_EAT_TIME = 40 * 60;
    uint256 private constant _WORK_EAT_TIME = 5 * 60;
    uint256 private constant _ENERGY_COST_TIME = 60;
    uint256 private constant _ENERGY_REFILL_TIME = 24 * 60 * 60;
    uint256 private constant _COST_BASE = 3 ether;
    uint256 private constant _COST_UP = 0.1 ether;

    // storage
    mapping(uint256 => CatzInfo) public catzInfos;
    mapping(address => UserInfo) public userInfos;
    ICatz public catz;
    ICFT public cft;
    ICGT public cgt;
    ICatzFood public cf;
    uint256 public workTime;
    uint256 public restTime;
    uint256 public effMultiplier;
    uint256 public curMultiplier;
    uint256 public lukMultiplier;
    uint256 public vitMultiplier;
    uint256 public rewardCftMultiplier;
    uint256 public rewardCgtMultiplier;
    uint256 public speedUp;

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
        require(timestamp <= block.timestamp, "no modifying future");
        if (catzInfos[id].lastRefillTime == 0) {
            _initialize(id, timestamp);
        }
        _refillEnergy(id, timestamp);
        _updateState(id, timestamp);
        _;
    }

    function _initialize(uint256 id, uint256 timestamp) internal {
        uint256 time = timestamp -
            ((timestamp - _TIME_BASE) % _ENERGY_REFILL_TIME);
        catzInfos[id].lastRefillTime = time;
        catzInfos[id].lastEatTime = time;
    }

    function _refillEnergy(uint256 id, uint256 timestamp) internal {
        CatzInfo storage catzInfo = catzInfos[id];
        uint256 timeInterval = timestamp - catzInfo.lastRefillTime;
        if (timeInterval > _ENERGY_REFILL_TIME) {
            catzInfo.energy = 0;
            userInfos[msg.sender].earning = 0;
            uint256 remain = timeInterval % _ENERGY_REFILL_TIME;
            catzInfo.lastRefillTime = timestamp - remain;
        }
    }

    constructor(
        ICatz catz_,
        ICFT cft_,
        ICGT cgt_,
        ICatzFood cf_
    ) {
        catz = catz_;
        cft = cft_;
        cgt = cgt_;
        cf = cf_;
        effMultiplier = 1;
        curMultiplier = 1;
        lukMultiplier = 1;
        vitMultiplier = 1;
        rewardCftMultiplier = 100;
        rewardCgtMultiplier = 1;
        workTime = 25 * 60;
        restTime = 5 * 60;
        speedUp = 1;
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
            catzInfo.level.level,
            catzInfo.level.skillPoint,
            catzInfo.energy,
            catzInfo.hunger,
            gene.gender()
        );
    }

    function getHungerLimit(uint256 id) public view returns (uint256) {
        (, , , uint256 vit) = getStats(id);
        return vit + _HUNGER_LIMIT_BASE;
    }

    function getEarnLimit(address user) public view returns (uint256) {
        uint256 level = userInfos[user].level;
        return ((level / _EARN_LEVEL) * _EARN_LIMIT_UP) + _EARN_LIMIT_BASE;
    }

    // Testing usage
    function setSpeedUp(uint256 rate) external {
        speedUp = rate;
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
        require(catzInfo.energy < _ENERGY_MAX, "No energy");
        require(catzInfo.hunger < getHungerLimit(id), "Hungry");
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

    function workStop(
        uint256 id,
        uint256 timestamp,
        bool isAdventure
    )
        external
        updateState(id, timestamp)
        whenStates(id, State.Working, State.Waiting)
        isValidCatz(id)
        isOwner(id)
    {
        CatzInfo storage catzInfo = catzInfos[id];
        if (catzInfo.state == State.Resting) {
            _pet(id, isAdventure);
        }
        catzInfo.state = State.Idle;
        catzInfo.counterStart = 0;
        catzInfo.counter = 0;
        catzInfo.rewardDebt = 0;
    }

    function pet(
        uint256 id,
        uint256 timestamp,
        bool isAdventure
    )
        external
        updateState(id, timestamp)
        whenState(id, State.Resting)
        isValidCatz(id)
        isOwner(id)
    {
        _pet(id, isAdventure);
    }

    function _pet(uint256 id, bool isAdventure) internal {
        CatzInfo storage catzInfo = catzInfos[id];
        catzInfo.state = State.Petting;
        uint256 reward = catzInfo.rewardDebt;
        uint256 left = getEarnLimit(msg.sender) - userInfos[msg.sender].earning;
        reward = reward < left ? reward : left;

        catzInfo.rewardDebt = 0;
        // Send reward
        if (catzInfo.rewardCgt) {
            cgt.mint(msg.sender, reward);
        } else {
            cft.mint(msg.sender, reward);
        }

        if (isAdventure) {
            // give user 1 cat food as reward
            cf.mint(msg.sender, 1 ether);
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
        // uint256 limit = getHungerLimit(id);
        uint256 point = ((amount / 1 ether)) * 10;
        require(catzInfo.hunger - point >= 0, "over hunger limit");
        cf.transferFrom(msg.sender, address(this), amount);
        // token convert to point
        // 1 food recover 10 point of hunger
        catzInfo.hunger -= point;
    }

    // Stats actions
    function levelUp(uint256 id, uint256 timestamp)
        external
        updateState(id, timestamp)
        whenNotState(id, State.Working)
        isValidCatz(id)
        isOwner(id)
    {
        CatzLevel storage catzLevel = catzInfos[id].level;
        require(catzLevel.exp == _getLevelExp(id), "exp insufficient");
        uint256 level = catzLevel.level;
        if (level < _LEVEL_MAX) {
            catzLevel.level++;
            catzLevel.exp = 0;
            catzLevel.skillPoint += _SKILL_POINTS_UP;
            // Level up user
            userInfos[msg.sender].level++;
            cft.burn(msg.sender, _getLevelUpCost(level));
        }
    }

    function _getLevelUpCost(uint256 level) internal pure returns (uint256) {
        return _COST_BASE + _COST_UP * level;
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
            catzInfo.level.skillPoint -= sum;
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
            require(catzInfo.level.level == 29, "Level too low");
        }
        catzInfo.rewardCgt = flag;
    }

    function poke(uint256 id) external updateState(id, block.timestamp) {
        return;
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
                uint256 energizedTime = (_ENERGY_MAX - catzInfo.energy) *
                    _ENERGY_COST_TIME;
                uint256 workingTime = energizedTime > catzInfo.counter
                    ? catzInfo.counter
                    : energizedTime;
                workingTime = _dine(
                    id,
                    catzInfo.counterStart + workingTime,
                    _WORK_EAT_TIME
                );
                catzInfo.energy += workingTime / _ENERGY_COST_TIME;

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
                uint256 energizedTime = (_ENERGY_MAX - catzInfo.energy) *
                    _ENERGY_COST_TIME;
                uint256 workingTime = energizedTime > timeInterval
                    ? timeInterval
                    : energizedTime;
                workingTime = _dine(
                    id,
                    catzInfo.counterStart + workingTime,
                    _WORK_EAT_TIME
                );
                catzInfo.energy += workingTime / _ENERGY_COST_TIME;
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
        uint256 level = catzInfos[id].level.level;
        return _EXP_BASE + (level * _EXP_UP);
    }

    function _dine(
        uint256 id,
        uint256 timestamp,
        uint256 eatSpeed
    ) internal returns (uint256 eatTime) {
        uint256 finalSpeed = eatSpeed / speedUp;
        CatzInfo storage catzInfo = catzInfos[id];
        uint256 limit = getHungerLimit(id);
        uint256 eat = (timestamp - catzInfo.lastEatTime) / finalSpeed;
        uint256 food = limit - catzInfo.hunger;
        if (food > eat) {
            catzInfo.hunger += eat;
            eatTime = eat * finalSpeed;
        } else {
            catzInfo.hunger = limit;
            eatTime = food * finalSpeed;
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
