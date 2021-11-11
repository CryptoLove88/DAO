// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DAO is Ownable {
    using SafeERC20 for ERC20;

    // DAO name
    string public daoName;

    // ERC20 govenance token to vote
    ERC20 public voteToken;
    
    // Minimum duration from start to end date per every vote
    uint256 public minimumDuration;

    // Minimum support percentage
    uint256 public minimumSupport;

    // Minimum token holding amount
    uint256 public minimumTokenHolds;

    constructor(
        string memory _daoName,
        uint256 _minimumDuration,
        uint256 _minimumSupport,
        uint256 _minimumTokenHolds,
        ERC20 _voteToken
    ) {

        daoName = _daoName;

        minimumDuration = _minimumDuration;
        minimumSupport = _minimumSupport;
        minimumTokenHolds = _minimumTokenHolds;
        voteToken = _voteToken;
    }

    function setDAOName(string memory _daoName) external onlyOwner {
        daoName = _daoName;
    }

    function viewVoteToken() external view returns (ERC20) {
        return voteToken;
    }

    function setVoteToken(ERC20 _voteToken) external onlyOwner {
        voteToken = _voteToken;
    }

    function viewMinimumDuration() external view returns(uint256) {
        return minimumDuration;
    }

    function setMinimumDuration(uint256 _minimumDuration) external onlyOwner {
        minimumDuration = _minimumDuration;
    }

    function viewMinimumSupport() external view returns(uint256) {
        return minimumSupport;
    }

    function setMinimumSupport(uint256 _minimumSupport) external onlyOwner {
        minimumSupport = _minimumSupport;
    }

    function viewMinimumTokenHolds() external view returns(uint256){
        return minimumTokenHolds;
    }

    function setMinimumTokenHolds(uint256 _minimumTokenHolds) external onlyOwner {
        minimumTokenHolds = _minimumTokenHolds;
    }

    /**
     * @notice Transfer governance token to holder, before that this contract must be approved
     * @param _holder holder address who will participate
     * @param _amount token amount
     */
    function allocateToken(address _holder, uint256 _amount) external onlyOwner {
        require(_amount >= minimumTokenHolds, "Over minimum tokens");
        voteToken.safeTransfer(_holder, _amount);
    }
}