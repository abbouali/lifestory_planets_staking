// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IRewardToken.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// @author: Abderrahmane Bouali for Lifestory


/**
 * @title LifestoryPlanetStaking
 * LifestoryPlanetStaking - a contract for Lifestory to stake planets.
 */
contract LifestoryPlanetStaking is Ownable {
    // LifestoryPlanets contract
    IERC721 public planetContract;

    // LifestoryReward contract to be implemented in the future
    IRewardToken public rewardTokenContract;

    // allow or disable new staking
    bool public allowStaking = true;

    // number of LIFC to be allocated
    uint256 public totalRewardSupply = 0;

    // Constant define one year in timestamp
    uint256 constant YEARTIME = 365 days;
    
    struct Staker {
        // Array of planet ID staked
        uint256[] planetIds;

        // Mapping of planet ID to release date of staking
        mapping(uint256 => uint256) planetStakingReleaseDate;

        // Mapping of planet ID to period of staking
        mapping(uint256 => uint8) planetPeriods;
    }

    /**
     * @dev constructor of LifestoryPlanetStaking 
     * @param _planet address of ERC721 contract of LIFV Planets
     */
    constructor(IERC721 _planet) {
        planetContract = _planet;
    }

    // Mapping from staker address to Staker structure
    mapping(address => Staker) private stakers;

    // Mapping from planet ID to owner address
    mapping(uint256 => address) public planetOwner;

    /**
     * @dev Emitted when `user` stake `planetId`
     */
    event Staked(address user, uint256 planetId);

    /**
     * @dev Emitted when `user` unstake `planetId`
     */
    event Unstaked(address user, uint256 planetId);

    /**
     * @dev pure function to get number of LIFC depending on staking periode 
     * @param _nbYears number of year of staking
     */
    function getRewarding(uint8 _nbYears)
        public
        pure
        returns (uint16)
    {
        if(_nbYears == 1) return 1800;
        if(_nbYears == 2) return 4800;
        if(_nbYears == 3) return 10800;
        return 0;
    }

    /**
     * @dev view function to get planets staked by user 
     * @param _user address of user
     */
    function getStakedPlanets(address _user)
        public
        view
        returns (uint256[] memory planetIds)
    {
        return stakers[_user].planetIds;
    }

    /**
     * @dev view function to get planet staked period in years 
     * @param _user address of user
     * @param _planetId id of planet
     */
    function getPlanetStakedPeriod(address _user, uint256 _planetId)
        public
        view
        returns (uint256)
    {
        return stakers[_user].planetPeriods[_planetId];
    }

    /**
     * @dev view function to get release date in timestamp 
     * @param _user address of user
     * @param _planetId id of planet
     */
    function getStakedPlanetReleaseDate(address _user, uint256 _planetId)
        public
        view
        returns (uint256)
    {
        return stakers[_user].planetStakingReleaseDate[_planetId];
    }

    /**
     * @dev public function to stake planet 
     * @dev this contract needs to have access to transfer your Planets from your wallet to staking contract 
     * @param _planetId id of planet
     * @param _nbYears period of staking in years
     */
    function stake(uint256 _planetId, uint8 _nbYears) public {
        _stake(msg.sender, _planetId, _nbYears);
    }

    /**
     * @dev public function to stake multiple planets 
     * @dev this contract needs to have access to transfer your Planets from your wallet to staking contract 
     * @param _planetIds array of planets id 
     * @param _nbYears period of staking in years
     */
    function stakeBatch(uint256[] memory _planetIds, uint8 _nbYears) public {
        for (uint256 i = 0; i < _planetIds.length; i++) {
            stake(_planetIds[i], _nbYears);
        }
    }

    /**
     * @dev internal function to stake planet
     * @dev this contract needs to have access to transfer your Planets from your wallet to staking contract 
     * @param _user array of planets id 
     * @param _planetId id of planet
     * @param _nbYears period of staking in years
     */
    function _stake(address _user, uint256 _planetId, uint8 _nbYears) internal {
        require(allowStaking, "LIFPS: the new stake is blocked by the admin");
        require(
            planetContract.ownerOf(_planetId) == _user,
            "LIFPS: user must be the owner of the planet"
        );
        require(
            getRewarding(_nbYears) > 0,
            "LIFPS: you can not stake under one year or above 3 years"
        );
        Staker storage staker = stakers[_user];

        staker.planetIds.push(_planetId);
        staker.planetStakingReleaseDate[_planetId] = block.timestamp + (_nbYears * YEARTIME);
        staker.planetPeriods[_planetId] = _nbYears;
        planetOwner[_planetId] = _user;
        planetContract.transferFrom(_user, address(this), _planetId);
        totalRewardSupply += getRewarding(_nbYears);

        emit Staked(_user, _planetId);
    }

    /**
     * @dev public function to unstake planet and claim rewards
     * @param _planetId id of planet
     */
    function unstake(uint256 _planetId) public {
        require(
            planetOwner[_planetId] == msg.sender,
            "LIFPS: user must be the owner of the staked planet"
        );
        _unstake(planetOwner[_planetId], planetOwner[_planetId], _planetId);
    }

    /**
     * @dev public function to unstake mutiple planets and claim rewards
     * @param _planetIds array of planets id 
     */
    function unstakeBatch(uint256[] memory _planetIds) public {
        for (uint256 i = 0; i < _planetIds.length; i++) {
            if (planetOwner[_planetIds[i]] == msg.sender) {
                unstake(_planetIds[i]);
            }
        }
    }

    /**
     * @dev internal function to unstake planet and give rewards
     * @dev internal function can be called only by this contract
     * @dev user ownership is check in calling function (public function unstake)
     * @param _user address of user 
     * @param _transferTo address to transfer planet and rewards  
     * @param _planetId id of planet to unstake 
     */
    function _unstake(address _user, address _transferTo, uint256 _planetId) internal {
        Staker storage staker = stakers[_user];
        require(
            block.timestamp > staker.planetStakingReleaseDate[_planetId],
            "LIFPS: cooldown not complete"
        );

        for (uint256 i; i<staker.planetIds.length; i++) {
            if (staker.planetIds[i] == _planetId) {
                staker.planetIds[i] = staker.planetIds[staker.planetIds.length - 1];
                staker.planetIds.pop();
                break;
            }
        }
        delete planetOwner[_planetId];
        totalRewardSupply -= getRewarding(staker.planetPeriods[_planetId]);

        planetContract.safeTransferFrom(address(this), _transferTo, _planetId);
        
        if (rewardTokenContract != IRewardToken(address(0)) ) {
            rewardTokenContract.sendRewards(_transferTo, getRewarding(staker.planetPeriods[_planetId]));
        }
        emit Unstaked(_transferTo, _planetId);
    }

    /**
     * @dev onlyOwner function to unstake lost planet
     * @dev planet not claimed within one year after release date
     * @param _planetId id of planet lost  
     */
    function unstakeLost(uint256 _planetId) public onlyOwner {
        address user = planetOwner[_planetId];
        Staker storage staker = stakers[user];
        require(
            block.timestamp > staker.planetStakingReleaseDate[_planetId] + 365 days,
            "LIFPS: this Planet is not yet considered lost"
        );
        _unstake(user, msg.sender, _planetId);
    }

    /**
     * @dev onlyOwner function to disable new Staker
     * @param _allow boolean true to enable and false to disable 
     */
    function setAllowStaking(bool _allow) public onlyOwner {
        allowStaking = _allow;
    }

    /**
     * @dev onlyOwner function to set address of reward contract
     * @dev when LIFC is listed and reward contract is implemented
     * @param _rewardContractAddress address of reward contract  
     */
    function setRewardContract(IRewardToken _rewardContractAddress) public onlyOwner {
        rewardTokenContract = _rewardContractAddress;
    }
}