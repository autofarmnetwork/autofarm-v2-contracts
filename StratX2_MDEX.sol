// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./StratX2.sol";

interface IMDEXSwapMining {
    function takerWithdraw() external;
}

contract StratX2_MDEX is StratX2 {
    address public MDXAddress;
    address public MDEXSwapMiningAddress;
    address[] public MDXToEarnedPath;

    constructor(
        address[] memory _addresses,
        uint256 _pid,
        bool _isCAKEStaking,
        bool _isSameAssetDeposit,
        bool _isAutoComp,
        address[] memory _earnedToAUTOPath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path,
        address[] memory _token0ToEarnedPath,
        address[] memory _token1ToEarnedPath,
        uint256 _controllerFee,
        uint256 _buyBackRate,
        uint256 _entranceFeeFactor,
        uint256 _withdrawFeeFactor,
        address[] memory _MDXToEarnedPath
    ) public {
        wbnbAddress = _addresses[0];
        govAddress = _addresses[1];
        autoFarmAddress = _addresses[2];
        AUTOAddress = _addresses[3];

        wantAddress = _addresses[4];
        token0Address = _addresses[5];
        token1Address = _addresses[6];
        earnedAddress = _addresses[7];

        farmContractAddress = _addresses[8];
        pid = _pid;
        isCAKEStaking = _isCAKEStaking;
        isSameAssetDeposit = _isSameAssetDeposit;
        isAutoComp = _isAutoComp;

        uniRouterAddress = _addresses[9];
        earnedToAUTOPath = _earnedToAUTOPath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        token1ToEarnedPath = _token1ToEarnedPath;

        controllerFee = _controllerFee;
        rewardsAddress = _addresses[10];
        buyBackRate = _buyBackRate;
        buyBackAddress = _addresses[11];
        entranceFeeFactor = _entranceFeeFactor;
        withdrawFeeFactor = _withdrawFeeFactor;

        MDXAddress = _addresses[12];
        MDEXSwapMiningAddress = _addresses[13];
        MDXToEarnedPath = _MDXToEarnedPath;

        transferOwnership(autoFarmAddress);
    }

    // Claim trade mining rewards
    function noTimeLockFunc1() public {
        require(msg.sender == govAddress, "Not authorised");
        IMDEXSwapMining(MDEXSwapMiningAddress).takerWithdraw();
        _convertMDXToEarned();
    }

    function _convertMDXToEarned() internal {
        // Converts MDX (if any) to earned tokens
        uint256 MDXAmt = IERC20(MDXAddress).balanceOf(address(this));
        if (MDXAddress != earnedAddress && MDXAmt > 0) {
            IERC20(MDXAddress).safeIncreaseAllowance(uniRouterAddress, MDXAmt);
            // Swap all dust tokens to earned tokens
            _safeSwap(
                uniRouterAddress,
                MDXAmt,
                slippageFactor,
                MDXToEarnedPath,
                address(this),
                now.add(600)
            );
        }
    }
}
