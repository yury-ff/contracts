// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "./libraries/IERC20.sol";

import "./libraries/ReentrancyGuard.sol";
import "./libraries/Address.sol";
import "./libraries/Ownable.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IStableRewardTracker.sol";
import "./interfaces/IRewardRouter.sol";
import "./interfaces/IBalanceOracle.sol";


contract RewardRouter is ReentrancyGuard, Ownable {
    using Address for address payable;

    bool public isInitialized;

    address public tuto;
    address public usdc;
    address public feeTutoTracker;
    address public feeUsdcTracker;
    address private balanceOracle;

    event StakeTuto(address account, address token, uint256 amount);
    event UnstakeTuto(address account, address token, uint256 amount);
    event DepositUsdc(address account, uint256 amount);
    event WithdrawUsdc(address account, uint256 amount);

    constructor(
        address _tuto,
        address _usdc,
        address _initialOwner
    ) Ownable(_initialOwner) {
        tuto = _tuto;
        usdc = _usdc;
    }

    function initialize(
        address _feeUsdcTracker,
        address _feeTutoTracker,
        address _balanceOracle
    ) external onlyOwner {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;
        feeUsdcTracker = _feeUsdcTracker;
        feeTutoTracker = _feeTutoTracker;
        balanceOracle = _balanceOracle;
    }

    modifier onlyOracle() {
        require(
            msg.sender == balanceOracle,
            "You are not authorized to call this function."
        );
        _;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).transfer(_account, _amount);
    }

    function setOracleAddress(address _balanceOracle) external onlyOwner {
        balanceOracle = _balanceOracle;
    }

    function stakeTuto(uint256 _amount) external nonReentrant {
        _stakeTuto(msg.sender, _amount);
    }

    function unstakeTuto(uint256 _amount) external nonReentrant {
        _unstakeTuto(msg.sender, _amount);
    }

    function depositUsdc(uint256 _amount) external nonReentrant {
        _depositUsdc(msg.sender, _amount);
    }

    function withdrawUsdc(uint256 _amount) external nonReentrant {
        _withdrawUsdc(msg.sender, _amount);
    }

    function handleRewards(
        bool _shouldClaimUsdc,
        bool _shouldDepositUsdc
    ) external nonReentrant {
        address account = msg.sender;
            
        uint256 usdcAmount = 0;
        if (_shouldClaimUsdc) {
            uint256 usdcAmount0 = IRewardTracker(feeTutoTracker).claimForAccount(
                account,
                account
            );
            uint256 usdcAmount1 = IRewardTracker(feeUsdcTracker)
                .claimForAccount(account, account);
            usdcAmount = usdcAmount0 + usdcAmount1;
        }
        if (_shouldDepositUsdc && usdcAmount > 0) {
            _depositUsdc(account, usdcAmount);
        }
    }

    function claim() external nonReentrant {
        address account = msg.sender;
        IRewardTracker(feeTutoTracker).claimForAccount(account, account);
        IRewardTracker(feeUsdcTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(
        address _account
    ) external nonReentrant onlyOwner {
        _compound(_account);
    }

    function _compound(address _account) private {
        _compoundUsdc(_account);
    }

    function _compoundUsdc(address _account) private {
        uint256 usdcFeeAmount0 = IRewardTracker(feeTutoTracker).claimForAccount(
                _account,
                _account
            );

        uint256 usdcFeeAmount1 = IStableRewardTracker(feeUsdcTracker)
            .claimForAccount(_account, _account);

        uint256 usdcFeeAmount = usdcFeeAmount0 + usdcFeeAmount1;

        if (usdcFeeAmount > 0) {
            _depositUsdc(_account, usdcFeeAmount);
        }
    }

    function _depositUsdc(
        address _account,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IStableRewardTracker(feeUsdcTracker).stakeForAccount(_account, _account, _amount);

        emit DepositUsdc(_account, _amount);
    }

    function _withdrawUsdc(address _account, uint256 _amount) private {
        IBalanceOracle(balanceOracle).updateUserBalance(
            _account,
            _amount
        );
       emit WithdrawUsdc(_account, _amount);
    }

    function _stakeTuto(
        address _account,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardRouter: invalid _tutoAmount");

        IRewardTracker(feeTutoTracker).stakeForAccount(
            _account,
            _account,
            tuto,
            _amount
        );

        emit StakeTuto(_account, tuto, _amount);
    }

    function _unstakeTuto(
        address _account,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardRouter: invalid _tutoAmount");

        IRewardTracker(feeTutoTracker).unstakeForAccount(
            _account,
            tuto,
            _amount,
            _account
        );
        emit UnstakeTuto(_account, tuto, _amount);
    }
}
