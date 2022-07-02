//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract PeerPredictor {
    struct Rater {
        address id;
        bytes32 name;   // short name (up to 32 bytes)
        uint reputation;
        uint last_update;
    }

    struct Job {
        uint id;
        string description;
        address rater_id;
        address reference_rater_id;
        bool is_rated;
    }

    struct Rate {
        address rater_id;
        uint8 value;   // 0 or 1
    }

    uint public ratingEndTime;

    mapping(address => Rater) public raters;
    mapping(address => Rate) public rates;
    Job[] public jobs;

    error RatingAlreadyEnded();

    constructor(
        uint ratingTime,
        address[] memory rater_addresses,
        bytes32[] memory rater_names
    ) {
        ratingEndTime = block.timestamp + ratingTime;
        for (uint i = 0; i < rater_addresses.length; i++) {
            Rater memory rater;
            rater.id = rater_addresses[i];
            rater.name = rater_names[i];
            rater.reputation = 0;
            rater.last_update = block.timestamp;
            raters[rater.id] = rater;
        }
        console.log("Added raters:",  rater_addresses.length);
        console.log("PeerPredictor contract deployed");
    }

    // Create jobs and assign them to raters
    function setupJobs() internal {

    }

    function getMyJobs() external returns (Job[] memory myJobs) {

    }

    // 
    function rate(uint job_id, uint value) external view {
        if (block.timestamp > ratingEndTime) {
            revert RatingAlreadyEnded();
        }
    }

    // Check whether all raters finished there rating or not
    function canFinish() external view returns (bool finished) {
        for (uint i = 0; i < jobs.length; i++) {
            if (jobs[i].is_rated == false) {
                return false;
            }
        }
        return true;
    }

    function calculateScoresOfAll() internal {
        
    }
}
