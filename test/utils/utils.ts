import { expect } from "chai";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { CatzBornResultSig } from "./constants";
const hre = require("hardhat");

export function expectEqWithinBps(
  actual: BigNumber,
  expected: BigNumber,
  bps: number = 1
) {
  const base = BigNumber.from("10000");
  const upper = expected.mul(base.add(BigNumber.from(bps))).div(base);
  const lower = expected.mul(base.sub(BigNumber.from(bps))).div(base);
  expect(actual).to.be.lte(upper);
  expect(actual).to.be.gte(lower);
}

export function ether(num: any) {
  return ethers.utils.parseUnits(num, "ether");
}

export function szabo(num: any) {
  return ethers.utils.parseUnits(num, 6);
}

export async function impersonateAndInjectEther(address: string) {
  // Impersonate pair
  await hre.network.provider.send("hardhat_impersonateAccount", [address]);

  // Inject 1 ether
  await hre.network.provider.send("hardhat_setBalance", [
    address,
    "0xde0b6b3a7640000",
  ]);
  return await (ethers as any).getSigner(address);
}

export function simpleEncode(_func: string, params: any) {
  const func = "function " + _func;
  const abi = [func];
  const iface = new ethers.utils.Interface(abi);
  const data = iface.encodeFunctionData(_func, params);

  return data;
}

export function asciiToHex32(s: string) {
  // Right Pad
  return ethers.utils.formatBytes32String(s);
}

export async function balanceDelta(addr: string, b: BigNumber) {
  return (await ethers.provider.getBalance(addr)).sub(b);
}

export function getFuncSig(artifact: any, name: string) {
  return artifact.interface.getSighash(name);
}

export async function _impersonateAndInjectEther(address: string) {
  // Impersonate pair
  await hre.network.provider.send("hardhat_impersonateAccount", [address]);

  // Inject 1 ether
  await hre.network.provider.send("hardhat_setBalance", [
    address,
    "0xde0b6b3a7640000",
  ]);
}

export async function sendEther(sender: Signer, to: string, value: BigNumber) {
  await sender.sendTransaction({
    to: to,
    value: value,
  });
}

export function mulPercent(num: any, percentage: any) {
  return BigNumber.from(num)
    .mul(BigNumber.from(percentage))
    .div(BigNumber.from(100));
}

export function padRightZero(s: string, length: any) {
  for (let i = 0; i < length; i++) {
    s = s + "0";
  }
  return s;
}

export function calcSqrt(y: BigNumber) {
  let z = BigNumber.from(0);
  if (y.gt(3)) {
    z = y;
    let x = y.div(BigNumber.from(2)).add(BigNumber.from(1));
    while (x.lt(z)) {
      z = x;
      x = y.div(x).add(x).div(BigNumber.from(2));
    }
  } else if (!y.eq(0)) {
    z = BigNumber.from(1);
  }

  return z;
}

export async function latest() {
  return BigNumber.from(
    (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
      .timestamp
  );
}

export function decimal6(amount: any) {
  return BigNumber.from(amount).mul(BigNumber.from("1000000"));
}

export async function getNewCatId(receipt: any) {
  let bytesData: any;
  const result = await receipt.wait();

  result.events.forEach((element: any) => {
    if (element.topics[0] === CatzBornResultSig) {
      // console.log("element", element);
      bytesData = ethers.utils.defaultAbiCoder.decode(
        ["uint256"],
        element.topics[1]
      );
    }
  });
  return bytesData;
}

export async function increaseNextBlockTimeBy(interval: number) {
  const blockNumber = await ethers.provider.getBlockNumber();
  let block = null;
  for (let i = 0; block == null; i++) {
    block = await ethers.provider.getBlock(blockNumber - i);
  }
  // const jsonRpc = new ethers.providers.JsonRpcProvider();
  // await jsonRpc.send("evm_setNextBlockTimestamp", [block.timestamp + interval]);
  // hre.network.provider;
  await hre.network.provider.send("evm_setNextBlockTimestamp", [
    block.timestamp + interval,
  ]);
  await hre.network.provider.send("evm_mine");
}
