// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IRewardToken
 * IRewardToken - define for future use when LIFC reward token is listed
 */
interface IRewardToken {
    /**
     * @dev this function called to send tokens rewards after unstake
     * @dev only LifestoryPlanetStaking Contract can called this function
     * @param to address to send reward
     * @param amount number of LIFC to send
     */
    function sendRewards(address to, uint256 amount) external;
}