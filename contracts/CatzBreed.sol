//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LibGene} from "./libs/LibGene.sol";
import {ICatzntrate} from "./interfaces/ICatzntrate.sol";
import {ICatz} from "./interfaces/ICatz.sol";

// import {Catzntrate} from "./Catzntrate.sol";

contract CatzBreed is Ownable {
    using LibGene for bytes32;
    // TODO: 紀錄 cat parent
    // TODO: 決定基因
    // TODO: breeding()
    // TODO: mon()
    // TODO: dad()

    // enum State {
    //     Invalid,
    //     Idle,
    //     Working,
    //     Waiting,
    //     Resting,
    //     End
    // }

    struct CatzBreedingInfo {
        uint256 monId;
        uint256 dadId;
        uint256[] kids;
        uint8 breedingCount;
        uint256 lastBreeding;
        uint256 birthTimestamp;
    }

    uint256 constant genderMaleDenominator = 10**4;

    uint8 public breedingLimit;
    uint8 public breedingLevel;
    uint8 public monBreedingCost;
    uint8 public dadBreedingCost;
    uint8 public maleNumerator;
    uint8 public breedingColdDown;

    mapping(uint256 => CatzBreedingInfo) public catzBreedingInfo;
    ICatz public catz;
    ICatzntrate public catzntrate;

    constructor(
        ICatz _catz,
        ICatzntrate _catzntrate,
        uint8 _breedingLimit,
        uint8 _breedingLevel,
        uint8 _monBreedingCost,
        uint8 _dadBreedingCost,
        uint8 _maleNumerator,
        uint8 _breedingColdDown
    ) {
        catz = _catz;
        catzntrate = _catzntrate;
        breedingLimit = _breedingLimit;
        breedingLevel = _breedingLevel;
        monBreedingCost = _monBreedingCost;
        dadBreedingCost = _dadBreedingCost;
        maleNumerator = _maleNumerator;
        breedingColdDown = _breedingColdDown;
    }

    function setBreedingLimit(uint8 _breedingLimit) external onlyOwner {
        breedingLimit = _breedingLimit;
    }

    function setBreedingLevel(uint8 _breedingLevel) external onlyOwner {
        breedingLevel = _breedingLevel;
    }

    function mon(uint256 id) external view returns (uint256) {
        return catzBreedingInfo[id].monId;
    }

    function dad(uint256 id) external view returns (uint256) {
        return catzBreedingInfo[id].dadId;
    }

    function breedingNewCatz(uint256 monId, uint256 dadId) external {
        // check cat existed
        require(catz.isValidCatz(monId), "mon cat doesn't exist");
        require(catz.isValidCatz(dadId), "dad cat doesn't exist");

        // check two cats owner
        require(catz.ownerOf(monId) == msg.sender, "wrong owner of mon cat");
        require(catz.ownerOf(dadId) == msg.sender, "wrong owner of dad cat");

        // get cat from id
        // check gender of parent id
        ICatz.CatzInfo memory monCatzGene = catz.catzs(monId);
        ICatz.CatzInfo memory dadCatzGene = catz.catzs(dadId);
        require(monCatzGene.gene.gender(), "wrong gender of mon");
        require(dadCatzGene.gene.gender(), "wrong gender of dad");

        // check level
        ICatzntrate.CatzInfo memory monCatzInfo = catzntrate.catzInfos(monId);
        ICatzntrate.CatzInfo memory dadCatzInfo = catzntrate.catzInfos(dadId);
        require(monCatzInfo.level >= breedingLevel, "mon level is too low");
        require(dadCatzInfo.level >= breedingLevel, "dad level is too low");

        // mon breeding limit
        CatzBreedingInfo storage monBreedingInfo = catzBreedingInfo[monId];
        CatzBreedingInfo storage dadBreedingInfo = catzBreedingInfo[dadId];
        require(
            monBreedingInfo.breedingCount <= breedingLimit,
            "over breeding limit"
        );

        // check last breeding
        require(
            monBreedingInfo.lastBreeding + breedingColdDown <= block.timestamp,
            "mon cat is in cold downtime"
        );
        require(
            dadBreedingInfo.lastBreeding + breedingColdDown <= block.timestamp,
            "mon cat is in cold downtime"
        );

        // calc token paid
        uint256 consumingTokenAmount = calcBreedingCost(monId, dadId);
        // TODO: transferFrom token from msg.sender account

        // decide factor for new cat
        bytes32 gene = genGeneFactors(monId, dadId, monCatzGene, dadCatzGene);

        // mint new cat for sender
        uint256 kidId = catz.breedCatz(gene, msg.sender);

        // TODO: update breeding info
        monBreedingInfo.lastBreeding = block.timestamp;
        dadBreedingInfo.lastBreeding = block.timestamp;
        monBreedingInfo.breedingCount++;
        dadBreedingInfo.breedingCount++;
        monBreedingInfo.kids.push(kidId);
        dadBreedingInfo.kids.push(kidId);

        // Update kid breeding information
        catzBreedingInfo[kidId].monId = monId;
        catzBreedingInfo[kidId].dadId = dadId;
        catzBreedingInfo[kidId].birthTimestamp = block.timestamp;

        // TODO: design
    }

    function calcBreedingCost(uint256 monId, uint256 dadId)
        public
        view
        returns (uint256)
    {
        CatzBreedingInfo memory monBreedingInfo = catzBreedingInfo[monId];
        CatzBreedingInfo memory dadBreedingInfo = catzBreedingInfo[dadId];

        return
            (monBreedingInfo.breedingCount * monBreedingCost) +
            (dadBreedingInfo.breedingCount * dadBreedingCost);
    }

    function genGeneFactors(
        uint256 monId,
        uint256 dadId,
        ICatz.CatzInfo memory monCatzGene,
        ICatz.CatzInfo memory dadCatzGene
    ) internal view returns (bytes32 gene) {
        // 跟 mon 和 dad 的體質有關
        // 希望跟 level 有關，可以有爆集的機率

        // gender 應該是 male:3 female:7
        bool gender = calcGender(monId, dadId, "gender");

        // efficiency
        uint8 efficiency = calcGeneFactorValue(
            monId,
            dadId,
            monCatzGene.gene.efficiency(),
            dadCatzGene.gene.efficiency(),
            "efficiency"
        );

        // curiosity
        uint8 curiosity = calcGeneFactorValue(
            monId,
            dadId,
            monCatzGene.gene.curiosity(),
            dadCatzGene.gene.curiosity(),
            "curiosity"
        );

        // luck
        uint8 luck = calcGeneFactorValue(
            monId,
            dadId,
            monCatzGene.gene.luck(),
            dadCatzGene.gene.luck(),
            "luck"
        );

        // vitality
        uint8 vitality = calcGeneFactorValue(
            monId,
            dadId,
            monCatzGene.gene.vitality(),
            dadCatzGene.gene.vitality(),
            "vitality"
        );

        return gene.genGene(gender, efficiency, curiosity, luck, vitality);
    }

    function calcGender(
        uint256 monId,
        uint256 dadId,
        string memory prefix
    ) internal view returns (bool) {
        // 0: male
        // 1: female

        uint256 randomNumber = getRandomNumber(
            monId,
            dadId,
            prefix,
            block.timestamp
        );

        if (
            calcRandomValue(randomNumber, genderMaleDenominator) < maleNumerator
        ) {
            return false; // male
        } else {
            return true; // female
        }
    }

    function calcGeneFactorValue(
        uint256 monId,
        uint256 dadId,
        uint8 monValue,
        uint8 dadValue,
        string memory prefix
    ) internal view returns (uint8) {
        uint8 minValue = monValue <= dadValue ? monValue : dadValue;
        uint256 upperLimit = monValue <= dadValue
            ? dadValue - monValue
            : monValue - dadValue;

        uint256 randomNumber = getRandomNumber(
            monId,
            dadId,
            prefix,
            upperLimit
        );
        return minValue + uint8(calcRandomValue(randomNumber, upperLimit));
    }

    function calcRandomValue(uint256 randomNumber, uint256 upperLimit)
        internal
        pure
        returns (uint256)
    {
        return UniformRandomNumber.uniform(randomNumber, upperLimit);
    }

    function getRandomNumber(
        uint256 monId,
        uint256 dadId,
        string memory prefix,
        uint256 upperLimit
    ) internal view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    monId,
                    dadId,
                    prefix,
                    upperLimit,
                    block.timestamp
                )
            )
        );
        return randomNumber;
    }

    function addStats(
        uint256 id,
        uint256 efficiency,
        uint256 curiosity,
        uint256 luck,
        uint256 vitality
    ) external {}
}
