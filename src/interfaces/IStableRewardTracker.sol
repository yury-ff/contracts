// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IStableRewardTracker {
   
    function stakedAmounts(address _account) external view returns (uint256);

    function updateRewards() external;

     function oracleCallback(
        address _account,
        uint256 _stakedAmount,
        uint256 _amount
    ) external;

    function oracleCallbackEndDay(
        address[] memory _accounts,
        uint256[] memory _stakedAmounts
    ) external;

    function stakeForAccount(
        address _fundingAccount,
        address _account,
        uint256 _amount
    ) external;

    function unstakeForAccount(
        address _account,
        uint256 _amount,
        address _receiver
    ) external;

    function tokensPerInterval() external view returns (uint256);

    function claimForAccount(
        address _account,
        address _receiver
    ) external returns (uint256);

    function claimable(address _account) external view returns (uint256);

    function cumulativeRewards(
        address _account
    ) external view returns (uint256);
}
