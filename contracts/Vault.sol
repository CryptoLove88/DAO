// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vault is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address private immutable ETH;

    // address to Execution contract
    address private _executionAddress;

    modifier onlyExecutor() {
        require(msg.sender == _executionAddress, "Only executor can call");
        _;
    }

    event Deposit(
        address indexed holder,
        address token,
        uint256 amount
    );

    event Transfer(
        address to,
        address token,
        uint256 amount
    );

    constructor() {
        ETH = address(0);
    }

    function setExecutionAddress(address _addr) external onlyOwner {
        _executionAddress = _addr;
    }
    
    /**
     * @notice Deposit ERC20 token, transferable ETH or ERC20 token
     * @param _token token address
     * @param _amount token amount
     */
    function deposit(ERC20 _token, uint256 _amount) external payable nonReentrant {
        if (address(_token) == ETH) {
            require(msg.value == _amount, "Invalid amount");
        } else {
           _token.safeTransferFrom(msg.sender, address(this), _amount);
        }

        emit Deposit(msg.sender, address(_token), _amount);
    }

    /**
     * @notice Transfer ERC20 token to given wallet address
     * @param _token token address
     * @param _to destination wallet address
     * @param _amount token amount to transfer
     */
    function transfer(ERC20 _token, address _to, uint256 _amount) external onlyExecutor nonReentrant {
        require(_amount > 0, "Over zero");

        if (address(_token) == ETH) {
            require(payable(_to).send(_amount), "Reverted ETH transfer");
        } else {
            _token.safeTransfer(_to, _amount);
        }

        emit Transfer(_to, address(_token), _amount);
    }

    /**
     * @notice Get balance of this contract
     * @param _token token address
     */
    function balanceOf(ERC20 _token) external view returns (uint256) {
        if (address(_token) == ETH) {
            return address(this).balance;
        } else {
            return _token.balanceOf(address(this));
        }
    }
}