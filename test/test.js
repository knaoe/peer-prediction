const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("PeerPredicator", function () {
  it("Deploy and run through.", async function () {
    const [owner, moderatorA, moderatorB, moderatorC, moderatorD] = await ethers.getSigners();
    const PeerPredicator = await ethers.getContractFactory("PeerPredictor");
    const peerPredicator = await PeerPredicator.deploy(1000, [
      moderatorA.address, moderatorB.address, moderatorC.address, moderatorD.address
    ], ["Annie", "Bert", "Charlie", "Diana"]);
    await peerPredicator.deployed();

    const jobCount = await peerPredicator.getJobCount();
    expect(jobCount).to.equal(4);

    const jobs = await peerPredicator.getJobs();
    for (const job of jobs) {
      console.log(job.title);
      console.log(job.description);
    }
    expect(jobs[0].id).to.equal(0);

    const jobsOfA = await peerPredicator.jobsOf(moderatorA.address);
    expect(jobsOfA.length).to.equal(2);

    const jobsOfB = await peerPredicator.jobsOf(moderatorB.address);
    const jobsOfC = await peerPredicator.jobsOf(moderatorC.address);
    const jobsOfD = await peerPredicator.jobsOf(moderatorD.address);

    await peerPredicator.connect(moderatorA).rate(jobsOfA[0].id, 1);
    await peerPredicator.connect(moderatorA).rate(jobsOfA[1].id, 1);
    await peerPredicator.connect(moderatorB).rate(jobsOfB[0].id, 1);
    await peerPredicator.connect(moderatorB).rate(jobsOfB[1].id, 1);
    await peerPredicator.connect(moderatorC).rate(jobsOfC[0].id, 1);
    await peerPredicator.connect(moderatorC).rate(jobsOfC[1].id, 1);
    await peerPredicator.connect(moderatorD).rate(jobsOfD[0].id, 0);
    await peerPredicator.connect(moderatorD).rate(jobsOfD[1].id, 1);

    expect(await peerPredicator.canFinish()).to.equal(true);

    const reputationOfA = await peerPredicator.reputationOf(moderatorA.address);
    expect(reputationOfA).to.equal(0);
    console.log("reputation of A: " + reputationOfA);
    const reputationOfB = await peerPredicator.reputationOf(moderatorB.address);
    expect(reputationOfB).to.equal(0);
    console.log("reputation of B: " + reputationOfB);
    const reputationOfC = await peerPredicator.reputationOf(moderatorC.address);
    // expect(reputationOfC).to.equal(1);
    console.log("reputation of C: " + reputationOfC);
    const reputationOfD = await peerPredicator.reputationOf(moderatorD.address);
    expect(reputationOfD).not.to.equal(reputationOfC);
    console.log("reputation of D: " + reputationOfD);
  });
});
