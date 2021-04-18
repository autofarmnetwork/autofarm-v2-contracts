// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./StratX2.sol";

contract StratX2_AUTO is StratX2 {
    address[] public users;
    mapping(address => uint256) public userLastDepositedTimestamp;
    uint256 public minTimeToWithdraw; // 604800 = 1 week
    uint256 public minTimeToWithdrawUL = 1209600; // 2 weeks

    event minTimeToWithdrawChanged(
        uint256 oldMinTimeToWithdraw,
        uint256 newMinTimeToWithdraw
    );

    event earned(uint256 oldWantLockedTotal, uint256 newWantLockedTotal);

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
        uint256 _withdrawFeeFactor
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

        transferOwnership(autoFarmAddress);
    }

    function deposit(address _userAddress, uint256 _wantAmt)
        public
        override
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (userLastDepositedTimestamp[_userAddress] == 0) {
            users.push(_userAddress);
        }
        userLastDepositedTimestamp[_userAddress] = block.timestamp;

        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal > 0 && sharesTotal > 0) {
            sharesAdded = _wantAmt
                .mul(sharesTotal)
                .mul(entranceFeeFactor)
                .div(wantLockedTotal)
                .div(entranceFeeFactorMax);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        wantLockedTotal = IERC20(AUTOAddress).balanceOf(address(this));

        return sharesAdded;
    }

    function withdraw(address _userAddress, uint256 _wantAmt)
        public
        override
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        require(
            (userLastDepositedTimestamp[_userAddress].add(minTimeToWithdraw)) <
                block.timestamp,
            "too early!"
        );

        require(_wantAmt > 0, "_wantAmt <= 0");

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal);
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);

        if (withdrawFeeFactor < withdrawFeeFactorMax) {
            _wantAmt = _wantAmt.mul(withdrawFeeFactor).div(
                withdrawFeeFactorMax
            );
        }

        // if (isAutoComp) {
        //     _unfarm(_wantAmt);
        // }

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }

        wantLockedTotal = wantLockedTotal.sub(_wantAmt);

        IERC20(wantAddress).safeTransfer(autoFarmAddress, _wantAmt);

        return sharesRemoved;
    }

    function _farm() internal override {}

    function _unfarm(uint256 _wantAmt) internal override {}

    function earn() public override whenNotPaused {
        // require(isAutoComp, "!isAutoComp");
        if (onlyGov) {
            require(msg.sender == govAddress, "!gov");
        }

        if (earnedAddress == wbnbAddress) {
            _wrapBNB();
        }

        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        // earnedAmt = distributeFees(earnedAmt);   // Not need to distribute fees again. Already done.

        IERC20(earnedAddress).safeApprove(uniRouterAddress, 0);
        IERC20(earnedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            earnedAmt
        );
        _safeSwap(
            uniRouterAddress,
            earnedAmt,
            slippageFactor,
            earnedToAUTOPath,
            address(this),
            block.timestamp.add(600)
        );

        lastEarnBlock = block.number;

        uint256 wantLockedTotalOld = wantLockedTotal;

        wantLockedTotal = IERC20(AUTOAddress).balanceOf(address(this));

        emit earned(wantLockedTotalOld, wantLockedTotal);
    }

    function setMinTimeToWithdraw(uint256 newMinTimeToWithdraw)
        public
        onlyAllowGov
    {
        require(newMinTimeToWithdraw <= minTimeToWithdrawUL, "too high");
        emit minTimeToWithdrawChanged(minTimeToWithdraw, newMinTimeToWithdraw);
        minTimeToWithdraw = newMinTimeToWithdraw;
    }

    function userLength() public view returns (uint256) {
        return users.length;
    }

    receive() external payable {}
}
