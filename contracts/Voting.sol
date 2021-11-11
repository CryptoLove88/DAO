// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./DAO.sol";
import "./Execution.sol";

contract Voting is Ownable {
    using SafeMath for uint256;

    // address to DAO contract
    DAO public daoAddress;
    
    // address to Execution Contract
    Execution private _execution;

    enum VoterState {
        Absent,
        Yes,
        No
    }

    struct Vote {
        address creator; // address created by
        bool executed;
        uint256 startDate; // start date timestamp in UTC
        uint256 endDate; // end date timestamp in UTC
        uint256 supportRequiredPercent; // support required precentage
        uint256 yesAmount; // total amount share for yes proposal
        uint256 noAmount; // total amount share for no proposal
        bool requireExecutor;
        mapping (address => VoterState) voters;
        mapping (address => uint256) voterAmount;
    }

    uint256 constant MAX_ACTION_COUNT = 5;

    uint256 public currentVoteId;
    mapping(uint256 => Vote) internal votes;

    // ERC20 govenance token to vote
    ERC20 public voteToken;

    // Minimum duration from start to end date per every vote
    uint256 public minimumDuration;

    // Minimum support percentage
    uint256 public minimumSupport;

    // Minimum token holding amount
    uint256 public minimumTokenHolds;

    event AddVote(
        uint256 indexed voteId,
        uint256 startDate,
        uint256 endDate,
        uint256 supportRequiredPercent,
        bool requireExecutor
    );

    event ParticipateVote(
        uint256 indexed voteId,
        address holder,
        uint256 prevStakeAmount,
        uint256 newStakeAmount,
        VoterState voterState
    );

    modifier onlyHolder() {
        require(voteToken.balanceOf(msg.sender) >= minimumTokenHolds, "At least more than minimum amount");
        _;
    }

    modifier voteExist(uint256 _voteId) {
        require(_voteId > 0 && _voteId <= currentVoteId, "Not exist vote");
        _;
    }

    modifier voteExpired(uint256 _voteId) {
        require(votes[_voteId].endDate >= block.timestamp &&
            block.timestamp >= votes[_voteId].startDate, "Active voting");
        _;
    }

    constructor(DAO _dao) {
        daoAddress = _dao;

        voteToken = daoAddress.viewVoteToken();
        minimumDuration = daoAddress.viewMinimumDuration();
        minimumSupport = daoAddress.viewMinimumSupport();
        minimumTokenHolds = daoAddress.viewMinimumTokenHolds();
    }

    function setExecutionAddress(address _executionAddress) external onlyOwner {
        _execution = Execution(_executionAddress);
    }

    /**
     * @notice Add new vote
     * @param _duration duration from start to end date in a second
     * @dev Callable by Token Holder
     */
    function addVote(
        uint256 _duration
    ) external onlyHolder {
        require(_duration >= minimumDuration, "At least larger than minimum duration");

        _newVote(_duration, false);
        Vote storage vote = votes[currentVoteId];

        emit AddVote(
            currentVoteId,
            vote.startDate,
            vote.endDate,
            vote.supportRequiredPercent,
            false
        );
    }

    /**
     * @notice Add new vote with multiple actions
     * @param _duration duration from start to end date in a second
     * @param _kind kind
     * @param _recipient recipient
     * @param _token token
     * @param _amount amount
     */
    function forward(
        uint256 _duration,
        uint256[] memory _kind,
        address[] memory _recipient,
        address[] memory _token,
        uint256[] memory _amount
    ) external onlyHolder {
        require(_duration >= minimumDuration, "At least larger than minimum duration");
        require(_kind.length < MAX_ACTION_COUNT, "Overflow maximum action count");
        require(
            _kind.length == _recipient.length &&
            _kind.length == _token.length &&
            _kind.length == _amount.length,
            "Require same array length"
        );

        uint256 voteId = _newVote(_duration, true);

        for (uint256 i = 0; i < _kind.length; i++) {
            _execution.addAction(
                voteId,
                _kind[i],
                msg.sender,
                _recipient[i],
                _token[i],
                _amount[i]
            );
        }

        Vote storage vote = votes[currentVoteId];

        emit AddVote(
            currentVoteId,
            vote.startDate,
            vote.endDate,
            vote.supportRequiredPercent,
            true
        );
    }

    function _newVote(uint256 _duration, bool _requireExecutor) internal returns (uint256) {
        currentVoteId++;

        Vote storage vote = votes[currentVoteId];
        vote.creator = msg.sender;
        vote.startDate = block.timestamp; // current timestamp
        vote.endDate = block.timestamp + _duration;
        vote.supportRequiredPercent = minimumSupport;
        vote.requireExecutor = _requireExecutor;

        return currentVoteId;
    }

    /**
     * @notice View given vote
     * @param _voteId vote id
     */
    function viewVote(uint256 _voteId) external view voteExist(_voteId) returns (
        address creator,
        bool executed,
        uint256 startDate,
        uint256 endDate,
        uint256 supportRequiredPercent,
        uint256 yesAmount,
        uint256 noAmount,
        bool requireExecutor
    ) {
        Vote storage vote = votes[_voteId];

        return (
            vote.creator,
            vote.executed,
            vote.startDate,
            vote.endDate,
            vote.supportRequiredPercent,
            vote.yesAmount,
            vote.noAmount,
            vote.requireExecutor
        );
    }

    function _canExecute(uint256 _voteId) internal view returns (bool) {
        Vote storage vote = votes[_voteId];
        if (block.timestamp < vote.endDate) {
            return false;
        }

        if (vote.executed) {
            return false;
        }

        if (
            vote.yesAmount.mul(100).div(
                vote.yesAmount.add(vote.noAmount)
            ) < vote.supportRequiredPercent
        ) {
            return false;
        }
        return true;
    }

    /**
     * @notice Execute the vote
     * @param _voteId vote id
     */
    function executeVote(uint256 _voteId) external voteExist(_voteId) {
        require(_canExecute(_voteId), "Can not execute");
        Vote storage vote = votes[_voteId];
        if (vote.requireExecutor) {
            _execution.trigger(_voteId);
        }
        vote.executed = true;

    }

    /**
     * @notice Participate vote, if `proposal` is true, Yes, else, No
     * @param _voteId vote id
     * @param _proposal yes or no
     */
    function participateVote(uint256 _voteId, bool _proposal) external voteExist(_voteId) voteExpired(_voteId) {
        uint256 tokenAmount = voteToken.balanceOf(msg.sender);
        require(tokenAmount >= minimumTokenHolds, "Over minimum holds");

        Vote storage vote = votes[_voteId];
        VoterState voterState = vote.voters[msg.sender];

        uint256 prevBalance = vote.voterAmount[msg.sender];
        uint256 balance = voteToken.balanceOf(msg.sender);
        // if already participated and new balance has changed, it means that he has transfered, reject voting
        require(prevBalance == 0 || prevBalance == balance, "Moved token before");

        // if already submited proposal, substract previous stake
        if (voterState == VoterState.Yes) {
            vote.yesAmount = vote.yesAmount.sub(prevBalance);
        } else if (voterState == VoterState.No) {
            vote.noAmount = vote.noAmount.sub(prevBalance);
        }

        if (_proposal) {
            vote.yesAmount = vote.yesAmount.add(balance);
            vote.voters[msg.sender] = VoterState.Yes;
        } else {
            vote.noAmount = vote.noAmount.add(balance);
            vote.voters[msg.sender] = VoterState.No;
        }

        vote.voterAmount[msg.sender] = balance;

        emit ParticipateVote(
            _voteId,
            msg.sender,
            prevBalance,
            balance,
            vote.voters[msg.sender]
        );
    }
}