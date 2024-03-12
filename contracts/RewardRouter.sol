// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "./libraries/SafeMath.sol";
import "./libraries/IERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/ReentrancyGuard.sol";
import "./libraries/Address.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IVester.sol";
import "./interfaces/IStableCoinRewardTracker.sol";
import "./interfaces/IRewardRouter.sol";
import "./interfaces/IBalanceOracle.sol";
import "./interfaces/IMintable.sol";
import "./access/Ownable.sol";

contract RewardRouter is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public ff;
    address public fidFF;
    address public bnFF;

    address public usdc;

    address public stakedFFTracker;
    address public bonusFFTracker;
    address public feeFFTracker;

    address public stakedUsdcTracker;
    address public feeUsdcTracker;

    address public ffVester;
    address public usdcVester;

    address private balanceOracle;

    mapping(address => address) public pendingReceivers;
    mapping(uint256 => bool) updateBalanceRequests;

    event StakeFF(address account, address token, uint256 amount);
    event UnstakeFF(address account, address token, uint256 amount);

    event DepositUsdc(address account, uint256 amount);
    event WithdrawUsdc(address account, uint256 amount);

    function initialize(
        address _ff,
        address _fidFF,
        address _bnFF,
        address _usdc,
        address _stakedFFTracker,
        address _bonusFFTracker,
        address _feeFFTracker,
        address _feeUsdcTracker,
        address _stakedUsdcTracker,
        address _ffVester,
        address _usdcVester
    ) external onlyOwner {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        ff = _ff;
        fidFF = _fidFF;
        bnFF = _bnFF;

        usdc = _usdc;

        stakedFFTracker = _stakedFFTracker;
        bonusFFTracker = _bonusFFTracker;
        feeFFTracker = _feeFFTracker;

        feeUsdcTracker = _feeUsdcTracker;
        stakedUsdcTracker = _stakedUsdcTracker;

        ffVester = _ffVester;
        usdcVester = _usdcVester;
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
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function setOracleAddress(address _balanceOracle) public onlyOwner {
        balanceOracle = _balanceOracle;
    }

    function batchStakeFFForAccount(
        address[] memory _accounts,
        uint256[] memory _amounts
    ) external nonReentrant onlyOwner {
        address _ff = ff;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeFF(msg.sender, _accounts[i], _ff, _amounts[i]);
        }
    }

    function stakeFFForAccount(
        address _account,
        uint256 _amount
    ) external nonReentrant onlyOwner {
        _stakeFF(msg.sender, _account, ff, _amount);
    }

    function stakeFF(uint256 _amount) external nonReentrant {
        _stakeFF(msg.sender, msg.sender, ff, _amount);
    }

    function stakeFidFF(uint256 _amount) external nonReentrant {
        _stakeFF(msg.sender, msg.sender, fidFF, _amount);
    }

    function depositUsdc(uint256 _amount) external nonReentrant {
        _depositUsdc(msg.sender, msg.sender, _amount);
    }

    function unstakeFF(uint256 _amount) external nonReentrant {
        _unstakeFF(msg.sender, ff, _amount, true);
    }

    function unstakeFidFF(uint256 _amount) external nonReentrant {
        _unstakeFF(msg.sender, fidFF, _amount, true);
    }

    function withdrawUsdc(uint256 _amount) external nonReentrant {
        _initiateWithdrawUsdc(msg.sender, _amount);
    }

    function oracleCallback(
        address _account,
        uint _id,
        uint _amount
    ) external onlyOracle {
        require(
            updateBalanceRequests[_id],
            "This request is not in my pending list."
        );
        _withdrawUsdc(_account, _amount);
        delete updateBalanceRequests[_id];
    }

    function handleRewards(
        bool _shouldClaimFF,
        bool _shouldStakeFF,
        bool _shouldClaimFidFF,
        bool _shouldStakeFidFF,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimUsdc,
        bool _shouldDepositUsdc
    ) external nonReentrant {
        address account = msg.sender;

        uint256 ffAmount = 0;
        if (_shouldClaimFF) {
            uint256 ffAmount0 = IVester(ffVester).claimForAccount(
                account,
                account
            );
            uint256 ffAmount1 = IVester(usdcVester).claimForAccount(
                account,
                account
            );
            ffAmount = ffAmount0.add(ffAmount1);
        }

        if (_shouldStakeFF && ffAmount > 0) {
            _stakeFF(account, account, ff, ffAmount);
        }

        uint256 fidFFAmount = 0;
        if (_shouldClaimFidFF) {
            uint256 fidFFAmount0 = IRewardTracker(stakedFFTracker)
                .claimForAccount(account, account);
            uint256 fidFFAmount1 = IRewardTracker(stakedUsdcTracker)
                .claimForAccount(account, account);
            fidFFAmount = fidFFAmount0.add(fidFFAmount1);
        }

        if (_shouldStakeFidFF && fidFFAmount > 0) {
            _stakeFF(account, account, fidFF, fidFFAmount);
        }

        if (_shouldStakeMultiplierPoints) {
            uint256 bnFFAmount = IRewardTracker(bonusFFTracker).claimForAccount(
                account,
                account
            );
            if (bnFFAmount > 0) {
                IRewardTracker(feeFFTracker).stakeForAccount(
                    account,
                    account,
                    bnFF,
                    bnFFAmount
                );
            }
        }
        uint256 usdcAmount = 0;
        if (_shouldClaimUsdc) {
            uint256 usdcAmount0 = IRewardTracker(feeFFTracker).claimForAccount(
                account,
                account
            );
            uint256 usdcAmount1 = IRewardTracker(feeUsdcTracker)
                .claimForAccount(account, account);
            usdcAmount = usdcAmount0.add(usdcAmount1);
        }
        if (_shouldDepositUsdc && usdcAmount > 0) {
            _depositUsdc(account, account, usdcAmount);
        }
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeFFTracker).claimForAccount(account, account);
        IRewardTracker(feeUsdcTracker).claimForAccount(account, account);

        IRewardTracker(stakedFFTracker).claimForAccount(account, account);
        IRewardTracker(stakedUsdcTracker).claimForAccount(account, account);
    }

    function claimFidFF() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedFFTracker).claimForAccount(account, account);
        IRewardTracker(stakedUsdcTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(
        address _account
    ) external nonReentrant onlyOwner {
        _compound(_account);
    }

    function batchCompoundForAccounts(
        address[] memory _accounts
    ) external nonReentrant onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function _compound(address _account) private {
        _compoundFF(_account);
        _compoundUsdc(_account);
    }

    function _compoundFF(address _account) private {
        uint256 fidFFAmount = IRewardTracker(stakedFFTracker).claimForAccount(
            _account,
            _account
        );
        if (fidFFAmount > 0) {
            _stakeFF(_account, _account, fidFF, fidFFAmount);
        }

        uint256 bnFFAmount = IRewardTracker(bonusFFTracker).claimForAccount(
            _account,
            _account
        );
        if (bnFFAmount > 0) {
            IRewardTracker(feeFFTracker).stakeForAccount(
                _account,
                _account,
                bnFF,
                bnFFAmount
            );
        }
    }

    function _compoundUsdc(address _account) private {
        uint256 fidFFAmount = IStableCoinRewardTracker(stakedUsdcTracker)
            .claimForAccount(_account, _account);
        if (fidFFAmount > 0) {
            _stakeFF(_account, _account, fidFF, fidFFAmount);
        }

        uint256 usdcFeeAmount = IStableCoinRewardTracker(feeUsdcTracker)
            .claimForAccount(_account, _account);
        if (usdcFeeAmount > 0) {
            _depositUsdc(_account, _account, usdcFeeAmount);
        }
    }

    function _depositUsdc(
        address _fundingAccount,
        address _account,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 postFeeAmount = IStableCoinRewardTracker(feeUsdcTracker)
            .stakeForAccount(_account, _account, usdc, _amount);
        IStableCoinRewardTracker(stakedUsdcTracker).stakeForAccount(
            _fundingAccount,
            _account,
            feeUsdcTracker,
            postFeeAmount
        );

        emit DepositUsdc(_account, _amount);
    }

    function _initiateWithdrawUsdc(address _account, uint256 _amount) private {
        uint256 id = IBalanceOracle(balanceOracle).updateUserBalance(
            _account,
            _amount
        );
        updateBalanceRequests[id] = true;
    }

    function _withdrawUsdc(address _account, uint256 _amount) private {
        IStableCoinRewardTracker(stakedUsdcTracker).unstakeForAccount(
            _account,
            feeUsdcTracker,
            _amount,
            _account
        );
        IStableCoinRewardTracker(feeUsdcTracker).unstakeForAccount(
            _account,
            usdc,
            _amount,
            _account
        );

        emit WithdrawUsdc(_account, _amount);
    }

    function _stakeFF(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedFFTracker).stakeForAccount(
            _fundingAccount,
            _account,
            _token,
            _amount
        );
        IRewardTracker(bonusFFTracker).stakeForAccount(
            _account,
            _account,
            stakedFFTracker,
            _amount
        );
        IRewardTracker(feeFFTracker).stakeForAccount(
            _account,
            _account,
            bonusFFTracker,
            _amount
        );

        emit StakeFF(_account, _token, _amount);
    }

    function _unstakeFF(
        address _account,
        address _token,
        uint256 _amount,
        bool _shouldReduceBnFF
    ) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedFFTracker).stakedAmounts(
            _account
        );

        IRewardTracker(feeFFTracker).unstakeForAccount(
            _account,
            bonusFFTracker,
            _amount,
            _account
        );
        IRewardTracker(bonusFFTracker).unstakeForAccount(
            _account,
            stakedFFTracker,
            _amount,
            _account
        );
        IRewardTracker(stakedFFTracker).unstakeForAccount(
            _account,
            _token,
            _amount,
            _account
        );

        if (_shouldReduceBnFF) {
            uint256 bnFFAmount = IRewardTracker(bonusFFTracker).claimForAccount(
                _account,
                _account
            );
            if (bnFFAmount > 0) {
                IRewardTracker(feeFFTracker).stakeForAccount(
                    _account,
                    _account,
                    bnFF,
                    bnFFAmount
                );
            }

            uint256 stakedBnFF = IRewardTracker(feeFFTracker).depositBalances(
                _account,
                bnFF
            );
            if (stakedBnFF > 0) {
                uint256 reductionAmount = stakedBnFF.mul(_amount).div(balance);
                IRewardTracker(feeFFTracker).unstakeForAccount(
                    _account,
                    bnFF,
                    reductionAmount,
                    _account
                );
                IMintable(bnFF).burn(_account, reductionAmount);
            }
        }

        emit UnstakeFF(_account, _token, _amount);
    }
}
