import { Wallet, BigNumber, Signer } from "ethers";
import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import {
  IERC20,
  Catzntrate,
  Catz,
  CatzBreed,
  CFT,
  CatzFood,
} from "../typechain";
import {} from "./utils/constants";
import { ether, getNewCatId } from "./utils/utils";

describe("CatzBreed", function () {
  const monGene =
    "0x0203040500000000000000000000000000000000000000000000000000000000";
  const dadGene =
    "0x0A0B0C0D00000000800000000000000000000000000000000000000000000000";

  let owner: Wallet;
  let user: Wallet;

  let cft: CFT;
  let cgt: IERC20;
  let cf: CatzFood;
  let catzntrate: Catzntrate;
  let catz: Catz;
  let catzBreed: CatzBreed;
  let dadCatId: number;
  let monCatId: number;

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }, options) => {
      await deployments.fixture(); // ensure you start from a fresh deployments
      [owner, user] = await (ethers as any).getSigners();

      cft = await (await ethers.getContractFactory("CFT")).deploy();
      await cft.deployed();

      cgt = await (await ethers.getContractFactory("CGT")).deploy();
      await cgt.deployed();

      const foodPrice = 2;
      cf = await (
        await ethers.getContractFactory("CatzFood")
      ).deploy(cft.address, foodPrice);
      await cf.deployed();

      catz = await (await ethers.getContractFactory("Catz")).deploy();
      await catz.deployed();

      catzntrate = await (
        await ethers.getContractFactory("Catzntrate")
      ).deploy(catz.address, cft.address, cgt.address, cf.address);
      await catzntrate.deployed();

      catzBreed = await (
        await ethers.getContractFactory("CatzBreed")
      ).deploy(cft.address, catz.address, catzntrate.address, 7, 0);
      await catzBreed.deployed();

      await cft.addMinter(owner.address);
      await cft.mint(user.address, ether("5000"));

      // birth mon/dad cat
      await catz.addBreeder(owner.address);
      await catz.addBreeder(catzBreed.address);

      let tx = await catz.breedCatz(monGene, user.address);
      monCatId = await getNewCatId(tx);

      tx = await catz.breedCatz(dadGene, user.address);
      dadCatId = await getNewCatId(tx);
    }
  );

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // setupTest will use the evm_snapshot to reset environment for speed up testing
    await setupTest();
  });

  describe("breed cat", function () {
    it("breed", async function () {
      const balanceUserBefore = await cft.balanceOf(user.address);
      const monBreedingInfoBefore = await catzBreed.catzBreedingInfo(
        monCatId.toString()
      );
      const dadBreedingInfoBefore = await catzBreed.catzBreedingInfo(
        dadCatId.toString()
      );

      const cost = await catzBreed.calcBreedingCost(
        monCatId.toString(),
        dadCatId.toString()
      );

      await cft.connect(user).approve(catzBreed.address, ether("10000"));
      const tx = await catzBreed
        .connect(user)
        .breedNewCatz(monCatId.toString(), dadCatId.toString());
      const newCatzId = await getNewCatId(tx);
      expect(await catz.ownerOf(newCatzId.toString())).to.be.eq(user.address);
      const info = await catz.getCatz(newCatzId.toString());
      const kidAbility = getAbility(info.gene);
      const monAbility = getAbility(monGene);
      const dadAbility = getAbility(dadGene);

      for (let i = 0; i < kidAbility.length; i++) {
        expect(kidAbility[i]).to.be.gte(monAbility[i]);
        expect(kidAbility[i]).to.be.lte(dadAbility[i]);
      }

      const kidBreedingInfo = await catzBreed.catzBreedingInfo(
        newCatzId.toString()
      );
      expect(kidBreedingInfo.monId).to.be.eq(monCatId.toString());
      expect(kidBreedingInfo.dadId).to.be.eq(dadCatId.toString());

      const monBreedingInfoAfter = await catzBreed.catzBreedingInfo(
        monCatId.toString()
      );

      expect(monBreedingInfoAfter.breedingCount).to.be.eq(
        monBreedingInfoBefore.breedingCount + 1
      );

      expect(monBreedingInfoAfter.lastBreeding).to.be.gt(
        monBreedingInfoBefore.lastBreeding
      );

      const dadBreedingInfoAfter = await catzBreed.catzBreedingInfo(
        dadCatId.toString()
      );

      expect(dadBreedingInfoAfter.breedingCount).to.be.eq(
        dadBreedingInfoBefore.breedingCount + 1
      );
      expect(dadBreedingInfoAfter.lastBreeding).to.be.gt(
        dadBreedingInfoBefore.lastBreeding
      );

      expect(await cft.balanceOf(user.address)).to.be.eq(
        balanceUserBefore.sub(cost)
      );
    });
  });
});

export function getAbility(gene: any) {
  const efficiency = BigNumber.from(parseInt(gene.substr(2, 2), 16));
  const curiosity = BigNumber.from(parseInt(gene.substr(4, 2), 16));
  const luck = BigNumber.from(parseInt(gene.substr(6, 2), 16));
  const vitality = BigNumber.from(parseInt(gene.substr(8, 2), 16));
  return [efficiency, curiosity, luck, vitality];
}
