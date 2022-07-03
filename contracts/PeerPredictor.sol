//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PeerPredictor {
    struct Rater {
        address id;
        string name; // short name
        int8 reputation;
        uint last_update;
    }

    struct Job {
        uint id;
        string title;
        string description;
        address raterId;
        address referenceRaterId;
        bool isRated;
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

    error RatingAlreadyEnded();

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
            rater.last_update = block.timestamp;
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
        for (uint i = 0; i < raterAddresses.length; i++) {
            uint raterCount = raterAddresses.length;
            Rater memory target = raters[raterAddresses[i]];

            uint caseNumber = random(1, raterCount);
            Rater memory rater = raters[
                raterAddresses[caseNumber % raterCount]
            ];
            Rater memory referenceRater = raters[
                raterAddresses[(caseNumber + 1) % raterCount]
            ];

            Job memory job;
            job.id = i;
            job.title = string.concat(
                "Until ",
                Strings.toString(ratingEndTime),
                "(epoch time), you will observe ",
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
            job.referenceRaterId = rater.id;
            job.isRated = false;
            jobs.push(job);
        }
    }

    function getMyJobs() public view returns (Job[] memory myJobs) {
        return assignedJobs[msg.sender];
    }

    //
    function rate(uint jobId, uint8 value) external {
        if (block.timestamp > ratingEndTime) {
            revert RatingAlreadyEnded();
        }

        address raterId = msg.sender;
        Job memory job = jobs[jobId];
        require(job.raterId == raterId, "You are not the rater of this job");
        require(!job.isRated, "You have already rated this job");

        if (job.referenceRaterId == raterId) {
            referenceRates[raterId] = Rate(raterId, value);
        } else {
            rates[raterId] = Rate(raterId, value);
        }
        job.isRated = true;

        if (canFinish()) {
            finalize();
        }
    }

    // Check whether all raters finished there rating or not
    function canFinish() public view returns (bool finished) {
        for (uint i = 0; i < jobs.length; i++) {
            if (jobs[i].isRated == false) {
                return false;
            }
        }
        return true;
    }

    function finalize() public {
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
            rater.last_update = block.timestamp;
            raters[rater.id] = rater;
            console.log("Reputation of", rater.name, "is", rater.reputation);
        }
    }

    function random(uint min, uint max) private view returns (uint) {
        return min + (uint(block.timestamp) % (max - min));
    }
}
