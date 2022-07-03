//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PeerPredictor {
    struct Rater {
        address id;
        string name; // short name
        int8 reputation;
        uint lastUpdate;
    }

    // TODO: consider creating Task struct for each Job to support more complex case.
    struct Job {
        uint id;
        string title;
        string description;
        address raterId;
        address referenceRaterId;
        bool isRated;
        bool isReferenceRated;
    }

    struct Rate {
        address raterId; // not nessesary?
        uint8 value; // 0 or 1
    }

    uint public ratingEndTime;

    mapping(address => Rater) public raters;
    mapping(address => Rate) public rates;
    mapping(address => Rate) public referenceRates;
    mapping(address => Job[]) public assignedJobs;
    Job[] public jobs;

    error YouAreNotRaterOfThisJob();
    error RatingAlreadyEnded();
    error NotEnoughRating();

    constructor(
        uint ratingTime,
        address[] memory raterAddresses,
        string[] memory raterNames
    ) {
        ratingEndTime = block.timestamp + ratingTime;
        for (uint i = 0; i < raterAddresses.length; i++) {
            Rater memory rater;
            rater.id = raterAddresses[i];
            rater.name = raterNames[i];
            rater.reputation = 0;
            rater.lastUpdate = block.timestamp;
            raters[rater.id] = rater;
        }
        console.log("Added raters:", raterAddresses.length);

        createAndAssignJobs(raterAddresses);

        console.log("PeerPredictor contract deployed");
    }

    // Create jobs and assign them to raters
    // e.g) createAndAssignJobs([0xA, 0xB, 0xC, 0xD])
    // case1:
    // job0: target: 0xA, rater: 0xB, referenceRater: 0xC
    // job1: target: 0xB, rater: 0xC, referenceRater: 0xD
    // job2: target: 0xC, rater: 0xD, referenceRater: 0xA
    // job3: target: 0xD, rater: 0xA, referenceRater: 0xB
    //
    // case2:
    // job0: target: 0xA, rater: 0xC, referenceRater: 0xD
    // job1: target: 0xB, rater: 0xD, referenceRater: 0xA
    // job2: target: 0xC, rater: 0xA, referenceRater: 0xB
    // job3: target: 0xD, rater: 0xB, referenceRater: 0xC
    //
    // case3:
    // job0: target: 0xA, rater: 0xD, referenceRater: 0xB
    // job1: target: 0xB, rater: 0xA, referenceRater: 0xC
    // job2: target: 0xC, rater: 0xB, referenceRater: 0xD
    // job3: target: 0xD, rater: 0xC, referenceRater: 0xA
    //
    // case4:
    // job0: target: 0xA, rater: 0xB, referenceRater: 0xC
    // job1: target: 0xB, rater: 0xC, referenceRater: 0xD
    // job2: target: 0xC, rater: 0xD, referenceRater: 0xA
    // job3: target: 0xD, rater: 0xA, referenceRater: 0xB
    function createAndAssignJobs(address[] memory raterAddresses) internal {
        console.log("Creating jobs");
        uint raterCount = raterAddresses.length;
        uint caseNumber = random(1, raterCount); // 1 <= caseNumber <= raterCount
        console.log("caseNumber: ", caseNumber);
        for (uint i = 0; i < raterAddresses.length; i++) {
            Rater memory target = raters[raterAddresses[i]];

            Rater memory rater = raters[
                raterAddresses[(i + caseNumber) % raterCount]
            ];
            Rater memory referenceRater = raters[
                raterAddresses[(i + caseNumber + 1) % raterCount]
            ];

            Job memory job;
            job.id = i;
            job.title = string.concat(
                "Until ",
                Strings.toString(ratingEndTime),
                "(epoch time), you(",
                rater.name,
                " and ",
                referenceRater.name,
                ") will observe ",
                target.name,
                "'s work and give him/her a '0' if he/she does not fit the culture of this organization, or a '1' if he/she is fine."
            );
            job.description = string.concat(
                "Job ",
                Strings.toString(job.id),
                ": target: ",
                Strings.toHexString(target.id),
                ", rater: ",
                Strings.toHexString(rater.id),
                ", referenceRater: ",
                Strings.toHexString(referenceRater.id)
            );
            job.raterId = rater.id;
            job.referenceRaterId = referenceRater.id;
            job.isRated = false;
            jobs.push(job);
            assignedJobs[rater.id].push(job);
            assignedJobs[referenceRater.id].push(job);
        }
        console.log(jobs.length, " jobs created");
    }

    function getJobCount() public view returns (uint) {
        return jobs.length;
    }

    function getJobs() public view returns (Job[] memory) {
        return jobs;
    }

    function jobsOf(address raterId) public view returns (Job[] memory) {
        return assignedJobs[raterId];
    }

    function reputationOf(address raterId) public view returns (int8) {
        return raters[raterId].reputation;
    }

    // rater should rate assigned job until [ratingEndTime].
    function rate(uint jobId, uint8 value) external {
        if (block.timestamp > ratingEndTime) {
            revert RatingAlreadyEnded();
        }
        console.log("rating jobId: ", jobId, " value: ", value);

        address raterId = msg.sender;
        Job memory job = jobs[jobId];
        console.log("job raterId: ", job.raterId);
        console.log("job refereanceRaterId: ", job.referenceRaterId);
        if (job.raterId == raterId) {
            require(!job.isRated, "You have already rated this job");
            job.isRated = true;
            rates[raterId] = Rate(raterId, value);
        } else if (job.referenceRaterId == raterId) {
            require(!job.isReferenceRated, "You have already rated this job");
            referenceRates[raterId] = Rate(raterId, value);
            job.isReferenceRated = true;
        } else {
            console.log("msg.sender: ", msg.sender);
            revert YouAreNotRaterOfThisJob();
        }

        jobs[jobId] = job;

        if (canFinish()) {
            finalize();
        }
    }

    // Check whether all raters finished there rating or not
    function canFinish() public view returns (bool finished) {
        for (uint i = 0; i < jobs.length; i++) {
            if (jobs[i].isRated == false || jobs[i].isReferenceRated == false) {
                return false;
            }
        }
        return true;
    }

    function finalize() public {
        if (!canFinish()) {
            revert NotEnoughRating();
        }
        calculateReputationOfAllAndSet();
    }

    function calculateReputationOfAllAndSet() private {
        for (uint i = 0; i < jobs.length; i++) {
            Job memory job = jobs[i];
            require(job.isRated, "The Job is not rated");

            uint8 mainValue = rates[job.raterId].value;
            uint8 mainReferenceValue = referenceRates[job.referenceRaterId]
                .value;

            // calculate aggreement score
            // 1 or 0
            uint8 aggreementScore = mainValue *
                mainReferenceValue +
                (1 - mainValue) *
                (1 - mainReferenceValue);

            // calculate staistic score
            // 1 or 0
            // retrieving non-overwrapping the other job of the same rater.
            // very simplified version in case of d = 1;
            uint8 averageOfTheOtherValue = referenceRates[job.raterId].value;
            uint8 averageOfTheOtherReferenceValue = rates[job.referenceRaterId]
                .value;

            uint8 statisticScore = averageOfTheOtherValue *
                averageOfTheOtherReferenceValue +
                (1 - averageOfTheOtherValue) *
                (1 - averageOfTheOtherReferenceValue);

            // reputation can be 1, 0 or -1
            Rater memory rater = raters[job.raterId];
            rater.reputation = int8(aggreementScore) - int8(statisticScore);
            rater.lastUpdate = block.timestamp;
            raters[rater.id] = rater;
            // console.log("Reputation of", rater.name, "is", rater.reputation);
        }
    }

    function random(uint min, uint max) private view returns (uint) {
        return min + (uint(block.timestamp) % (max - min));
    }
}
