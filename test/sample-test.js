const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("PeerPredicator", function () {
  it("Should return jobs automatically assigned.", async function () {
    const PeerPredicator = await ethers.getContractFactory("PeerPredicator");
    const peerPredicator = await PeerPredicator.deploy(1000, [
      0xa, 0xb, 0xc, 0xd
    ], ["Annie", "Bert", "Charlie", "Diana"]);
    await peerPredicator.deployed();

    // expect(await greeter.greet()).to.equal("Hello, world!");

    // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    //  wait until the transaction is mined
    // await setGreetingTx.wait();

    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});
