import { Wallet, constants, BigNumber } from "ethers";
import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { IERC20, Catzntrate, Catz, CFT, CatzFood } from "../typechain";
import { ether, getNewCatId, increaseNextBlockTimeBy } from "./utils/utils";

describe("Catzntrate", function () {
  let owner: Wallet;
  let user: Wallet;

  let cft: CFT;
  let cgt: IERC20;
  let cf: CatzFood;
  let catzntrate: Catzntrate;
  let catz: Catz;
  let catId: number;

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }, options) => {
      await deployments.fixture(); // ensure you start from a fresh deployments
      [owner, user] = await (ethers as any).getSigners();

      cft = await (await ethers.getContractFactory("CFT")).deploy();
      await cft.deployed();

      cgt = await (await ethers.getContractFactory("CGT")).deploy();
      await cgt.deployed();

      cf = await (
        await ethers.getContractFactory("CatzFood")
      ).deploy(cft.address, 2);
      await cf.deployed();

      catz = await (await ethers.getContractFactory("Catz")).deploy();
      await catz.deployed();

      catzntrate = await (
        await ethers.getContractFactory("Catzntrate")
      ).deploy(catz.address, cft.address, cgt.address, cf.address);
      await catzntrate.deployed();

      await cf.addMinter(catzntrate.address);
      await cft.addMinter(catzntrate.address);
      await cft.addMinter(owner.address);
      await cft.mint(user.address, ether("5000"));

      // birth mon/dad cat
      await catz.addBreeder(owner.address);

      const gene =
        "0x0203040500000000000000000000000000000000000000000000000000000000";
      const tx = await catz.breedCatz(gene, user.address);
      catId = await getNewCatId(tx);
    }
  );

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // setupTest will use the evm_snapshot to reset environment for speed up testing
    await setupTest();
  });

  describe("pet", function () {
    it("pet and get reward", async function () {
      const catzFoodUserBefore = await cf.balanceOf(user.address);

      await cf.connect(user).approve(catzntrate.address, constants.MaxUint256);
      let now = BigNumber.from(
        (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
          .timestamp
      );

      await catzntrate.connect(user).workStart(catId.toString(), now);
      await increaseNextBlockTimeBy(1 * 60 * 60);

      now = BigNumber.from(
        (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
          .timestamp
      );

      await catzntrate.connect(user).pet(catId.toString(), now, true);
      const catzFoodUserAfter = await cf.balanceOf(user.address);
      expect(catzFoodUserAfter.sub(catzFoodUserBefore)).to.be.eq(ether("1"));
    });
    it("pet without reward", async function () {
      const catzFoodUserBefore = await cf.balanceOf(user.address);

      await cf.connect(user).approve(catzntrate.address, constants.MaxUint256);
      let now = BigNumber.from(
        (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
          .timestamp
      );

      await catzntrate.connect(user).workStart(catId.toString(), now);
      await increaseNextBlockTimeBy(1 * 60 * 60);

      now = BigNumber.from(
        (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
          .timestamp
      );

      await catzntrate.connect(user).pet(catId.toString(), now, false);
      const catzFoodUserAfter = await cf.balanceOf(user.address);
      expect(catzFoodUserAfter).to.be.eq(catzFoodUserBefore);
    });
  });
});
