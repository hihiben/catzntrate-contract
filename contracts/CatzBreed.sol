//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LibGene} from "./libs/LibGene.sol";
import {ICatzntrate} from "./interfaces/ICatzntrate.sol";
import {ICatz} from "./interfaces/ICatz.sol";

// import {Catzntrate} from "./Catzntrate.sol";

contract CatzBreed is Ownable {
    using LibGene for bytes32;
    using SafeERC20 for IERC20;

    struct CatzBreedingInfo {
        uint256 monId;
        uint256 dadId;
        uint8 breedingCount;
        uint256 lastBreeding;
        uint256[] kids;
    }

    uint256 constant genderMaleDenominator = 10**4;

    uint8 public breedingLimit;
    uint8 public breedingLevel;
    uint256 public monBreedingCost;
    uint256 public dadBreedingCost;
    uint8 public maleNumerator;
    uint8 public breedingColdDown;

    mapping(uint256 => CatzBreedingInfo) public catzBreedingInfo;
    IERC20 public cft;
    ICatz public catz;
    ICatzntrate public catzntrate;

    constructor(
        IERC20 _cft,
        ICatz _catz,
        ICatzntrate _catzntrate,
        uint8 _breedingLimit,
        uint8 _breedingLevel
    ) {
        catz = _catz;
        catzntrate = _catzntrate;
        cft = _cft;
        breedingLimit = _breedingLimit;
        breedingLevel = _breedingLevel;
        monBreedingCost = 100 * 10**18;
        dadBreedingCost = 50 * 10**18;
        maleNumerator = 30;
        breedingColdDown = 0;
    }

    // update setting
    function setBreedingLimit(uint8 _breedingLimit) external onlyOwner {
        breedingLimit = _breedingLimit;
    }

    function setBreedingLevel(uint8 _breedingLevel) external onlyOwner {
        breedingLevel = _breedingLevel;
    }

    function setMonBreedingCost(uint256 cost) external onlyOwner {
        monBreedingCost = cost;
    }

    function setDadBreedingCost(uint256 cost) external onlyOwner {
        dadBreedingCost = cost;
    }

    function breedNewCatz(uint256 monId, uint256 dadId) external {
        // check cat existed
        require(catz.isValidCatz(monId), "mon cat doesn't exist");
        require(catz.isValidCatz(dadId), "dad cat doesn't exist");

        // check two cats owner
        require(catz.ownerOf(monId) == msg.sender, "wrong owner of mon cat");
        require(catz.ownerOf(dadId) == msg.sender, "wrong owner of dad cat");

        // check gender of parent id
        ICatz.CatzInfo memory monCatzGene = catz.catzs(monId);
        ICatz.CatzInfo memory dadCatzGene = catz.catzs(dadId);
        require(!monCatzGene.gene.gender(), "wrong gender of mon");
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
        uint256 cftCost = calcBreedingCost(monId, dadId);
        cft.safeTransferFrom(msg.sender, address(this), cftCost);

        // decide factor for new cat
        bytes32 gene = genGeneFactors(monId, dadId, monCatzGene, dadCatzGene);

        // mint new cat for sender
        uint256 kidId = catz.breedCatz(gene, msg.sender);

        // update breeding info
        monBreedingInfo.lastBreeding = block.timestamp;
        dadBreedingInfo.lastBreeding = block.timestamp;
        monBreedingInfo.breedingCount++;
        dadBreedingInfo.breedingCount++;
        monBreedingInfo.kids.push(kidId);
        dadBreedingInfo.kids.push(kidId);

        // Update kid breeding information
        catzBreedingInfo[kidId].monId = monId;
        catzBreedingInfo[kidId].dadId = dadId;
    }

    function calcBreedingCost(uint256 monId, uint256 dadId)
        public
        view
        returns (uint256)
    {
        CatzBreedingInfo memory monBreedingInfo = catzBreedingInfo[monId];
        CatzBreedingInfo memory dadBreedingInfo = catzBreedingInfo[dadId];

        return
            (monBreedingInfo.breedingCount + 1 * monBreedingCost) +
            (dadBreedingInfo.breedingCount + 1 * dadBreedingCost);
    }

    function genGeneFactors(
        uint256 monId,
        uint256 dadId,
        ICatz.CatzInfo memory monCatzGene,
        ICatz.CatzInfo memory dadCatzGene
    ) internal view returns (bytes32 gene) {
        // gender
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
        // 0: female
        // 1: male

        uint256 randomNumber = getRandomNumber(
            monId,
            dadId,
            prefix,
            block.timestamp
        );

        if (
            calcRandomValue(randomNumber, genderMaleDenominator) < maleNumerator
        ) {
            return false; // female
        } else {
            return true; // male
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
