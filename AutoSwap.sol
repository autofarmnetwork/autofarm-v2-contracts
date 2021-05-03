// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./libraries/SafeERC20.sol";

import "./helpers/Ownable.sol";

import "./helpers/Pausable.sol";

import "./libraries/UniversalERC20.sol";

import "./helpers/ReentrancyGuard.sol";

import "./helpers/Whitelist.sol";

contract AutoSwap is Ownable, ReentrancyGuard, Pausable, Whitelist {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using UniversalERC20 for IERC20;

    uint256 public feeRate;
    uint256 public referrerFeeRate;

    event FeeRateChanged(
        uint256 indexed oldFeeRate,
        uint256 indexed newFeeRate
    );
    event ReferrerFeeRateChanged(
        uint256 indexed oldReferrerFeeRate,
        uint256 indexed newReferrerFeeRate
    );

    event Order(
        address indexed sender,
        IERC20 indexed inToken,
        IERC20 indexed outToken,
        uint256 inAmount,
        uint256 outAmount
    );

    event Swapped(
        IERC20 indexed inToken,
        IERC20 indexed outToken,
        address indexed referrer,
        uint256 inAmount,
        uint256 outAmount,
        uint256 fee,
        uint256 referrerFee
    );

    struct CallStruct {
        address spenderIfIsApproval;
        address target;
        uint256 value;
        bytes data;
    }

    constructor(
        address _owner,
        uint256 _feeRate,
        uint256 _referrerFeeRate
    ) public {
        transferOwnership(_owner);
        feeRate = _feeRate;
        referrerFeeRate = _referrerFeeRate;
    }

    function swap(
        IERC20 inToken,
        IERC20 outToken,
        uint256 inAmount,
        uint256 minOutAmount,
        uint256 guaranteedAmount,
        address payable referrer,
        CallStruct[] calldata calls
    ) public payable nonReentrant whenNotPaused returns (uint256 outAmount) {
        // Initial checks
        require(minOutAmount > 0, "!(minOutAmount > 0)");
        require(calls.length > 0, "!(calls.length > 0)");
        require(
            (msg.value != 0) == inToken.isETH(),
            "msg.value should be used only for ETH swap"
        );

        // Transfer inToken to address(this)
        if (!inToken.isETH()) {
            inToken.safeTransferFrom(msg.sender, address(this), inAmount);
        }

        // Execute swaps
        for (uint256 i = 0; i < calls.length; i++) {
            if (calls[i].spenderIfIsApproval != address(0)) {
                // If call is to approve spending of a token
                _resetAllowances(calls[i].target, calls[i].spenderIfIsApproval);
            } else {
                // If call is a swap
                require(isMember(calls[i].target), "!whitelisted");
                calls[i].target.call{value: calls[i].value}(calls[i].data);
            }
        }

        // Transfer inToken dust (if any) to user
        inToken.universalTransfer(
            msg.sender,
            inToken.universalBalanceOf(address(this))
        );

        // Handle fees
        outAmount = outToken.universalBalanceOf(address(this));
        uint256 fee;
        uint256 referrerFee;
        (outAmount, fee, referrerFee) = _handleFees(
            outToken,
            outAmount,
            guaranteedAmount,
            referrer
        );

        // Closing checks
        require(
            outAmount >= minOutAmount,
            "Return amount less than the minimum required amount"
        );

        // Transfer outToken to user
        outToken.universalTransfer(msg.sender, outAmount);

        emit Order(msg.sender, inToken, outToken, inAmount, outAmount);
        emit Swapped(
            inToken,
            outToken,
            referrer,
            inAmount,
            outAmount,
            fee,
            referrerFee
        );
    }

    function _handleFees(
        IERC20 toToken,
        uint256 outAmount,
        uint256 guaranteedAmount,
        address referrer
    )
        internal
        returns (
            uint256 realOutAmount,
            uint256 fee,
            uint256 referrerFee
        )
    {
        if (outAmount <= guaranteedAmount || feeRate == 0) {
            return (outAmount, 0, 0);
        }

        fee = outAmount.sub(guaranteedAmount).mul(feeRate).div(10000);

        if (
            referrer != address(0) &&
            referrer != msg.sender &&
            referrer != tx.origin
        ) {
            referrerFee = fee.mul(referrerFeeRate).div(10000);
            if (toToken.universalTransfer(referrer, referrerFee)) {
                outAmount = outAmount.sub(referrerFee);
                fee = fee.sub(referrerFee);
            } else {
                referrerFee = 0;
            }
        }

        if (toToken.universalTransfer(owner(), fee)) {
            outAmount = outAmount.sub(fee);
        }

        return (outAmount, fee, referrerFee);
    }

    function _resetAllowances(address tokenAddress, address spenderAddress)
        internal
    {
        IERC20(tokenAddress).safeApprove(spenderAddress, uint256(0));
        IERC20(tokenAddress).safeIncreaseAllowance(spenderAddress, uint256(-1));
    }

    function changeFeeRate(uint256 _feeRate) public onlyOwner {
        require(_feeRate <= 10000, "!safe - too high");
        uint256 oldFeeRate = feeRate;
        feeRate = _feeRate;
        emit FeeRateChanged(oldFeeRate, _feeRate);
    }

    function changeReferrerFeeRate(uint256 _referrerFeeRate) public onlyOwner {
        require(_referrerFeeRate <= 10000, "!safe - too high");
        uint256 oldReferrerFeeRate = referrerFeeRate;
        referrerFeeRate = _referrerFeeRate;
        emit ReferrerFeeRateChanged(oldReferrerFeeRate, _referrerFeeRate);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    receive() external payable {}
}
