// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./libraries/Ownable.sol";
import "./interfaces/IStableRewardTracker.sol";
import "./interfaces/IRewardRouter.sol";


contract BalanceOracle is Ownable {
    address public feeUsdcTracker;
    address public stakedUsdcTracker;
    address public rewardRouter;
    bool private onChain = true;

    event UpdateUserBalanceEvent(address callerAddress, uint amount, bool);
    event SetUserBalanceEvent(
        uint _userBalance,
        address _callerAddress,
        uint _amount
    );

    constructor(
        address _initialOwner,
        address _feeUsdcTracker,
        address _rewardRouter
    ) Ownable(_initialOwner) {
        feeUsdcTracker = _feeUsdcTracker;
        rewardRouter = _rewardRouter;
    }


    function setRewardRouterAddress(address _rewardRouter) public onlyOwner {
        rewardRouter = _rewardRouter;
    }

    function updateUserBalance(
        address _account,
        uint _amount
    ) external  {
        require (msg.sender == rewardRouter);
        emit UpdateUserBalanceEvent(_account, _amount, onChain);
    }

// To update user's balance and unstake 

    function updateAmountsAndUnstake(
        uint _stakedAmount,
        address _account,
        uint _amount
    ) public onlyOwner {
        
        IStableRewardTracker(feeUsdcTracker).oracleCallback(
            _account,
            _stakedAmount,
            _amount
        );

        emit SetUserBalanceEvent(_stakedAmount, _account, _amount);
    }

// To update users' balances which were changed during the day but not withdrawn

    function updateStakedAmountsEndDay(
        uint256[] memory _stakedAmounts,
        address[] memory _accounts
    ) public onlyOwner {
        
        IStableRewardTracker(feeUsdcTracker).oracleCallbackEndDay(
            _accounts,
            _stakedAmounts
        );
        
    }

    function withdrawEth() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
