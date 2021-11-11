// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Vault.sol";

contract Execution is Ownable {
    using SafeERC20 for ERC20;

    address private immutable ETH;

    // address to Vault contract
    Vault private _vault;

    // address to Voting contract
    address private _votingAddress;

    enum ActionKind {
        Transfer
    }
    
    struct Action {
        ActionKind kind;
        address creator;
        address recipient;
        ERC20 token;
        uint256 amount;
    }

    uint256 public currentActionId;
    mapping(uint256 => Action) private _actions;
    mapping(uint256 => uint256[]) private _voteIdToActionId;

    modifier onlyVoting() {
        require(msg.sender == _votingAddress, "Only voting contract can call");
        _;
    }

    event AddAction(
        uint256 indexed voteId,
        uint256 indexed actionId,
        ActionKind kind,
        address creator,
        address recipient,
        ERC20 token,
        uint256 amount
    );

    event TriggerAction(
        uint256 indexed voteId
    );

    constructor() {
        ETH = address(0);
    }

    function setVotingAddress(address _addr) external onlyOwner {
        _votingAddress = _addr;
    }

    function setVaultAddress(address _addr) external onlyOwner {
        _vault = Vault(_addr);
    }

    /**
     * @notice Add action added on vote
     * @param _voteId vote id
     * @param _kind kind
     * @param _creator creator
     * @param _recipient recipient
     * @param _token token
     * @param _amount amount
     */
    function addAction(
        uint256 _voteId,
        uint256 _kind,
        address _creator,
        address _recipient,
        address _token,
        uint256 _amount
    ) external onlyVoting {
        require(_voteId > 0, "Over zero");
        require(_kind == uint256(ActionKind.Transfer), "Wrong action type");
        require(_amount > 0, "Invalid token amount");

        currentActionId++;
        Action storage action = _actions[currentActionId];
        action.kind = ActionKind(_kind);
        action.creator = _creator;
        action.recipient = _recipient;
        action.token = ERC20(_token);
        action.amount = _amount;

        _voteIdToActionId[_voteId].push(currentActionId);

        emit AddAction(
            _voteId,
            currentActionId,
            ActionKind(_kind),
            _creator,
            _recipient,
            ERC20(_token),
            _amount
        );
    }

    /**
     * @notice Execute action for given vote
     * @param _voteId vote id
     */
    function trigger(uint256 _voteId) external onlyVoting {
        require(_voteId > 0, "Over zero");

        for (uint256 i = 0; i < _voteIdToActionId[_voteId].length; i++) {
            Action storage action = _actions[_voteIdToActionId[_voteId][i]];

            if (action.kind == ActionKind.Transfer) {
                _vault.transfer(
                    action.token,
                    action.recipient,
                    action.amount
                );
            }
        }

        emit TriggerAction(_voteId);
    }

    /**
     * @notice Get array of actions
     */
    function viewAction(uint256 _voteId) external view returns (
        uint256[] memory, // kind
        address[] memory, // creator
        address[] memory, // recipient
        address[] memory, // token
        uint256[] memory // amount
    ) {
        require(_voteId > 0, "Over zero");
        uint256 actionCount = _voteIdToActionId[_voteId].length;
        require(actionCount > 0, "Empty actions");

        uint256[] memory kind = new uint256[](actionCount);
        address[] memory creator = new address[](actionCount);
        address[] memory recipient = new address[](actionCount);
        address[] memory token = new address[](actionCount);
        uint256[] memory amount = new uint256[](actionCount);

        for (uint256 i = 0; i < _voteIdToActionId[_voteId].length; i++) {
            uint256 actionId = _voteIdToActionId[_voteId][i];
            Action storage action = _actions[actionId];

            kind[i] = uint256(action.kind);
            creator[i] = action.creator;
            recipient[i] = action.recipient;
            token[i] = address(action.token);
            amount[i] = action.amount;
        }
        return (kind, creator, recipient, token, amount);
    }
}