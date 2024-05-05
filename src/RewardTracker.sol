// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "./libraries/SafeMath.sol";
import "./libraries/IERC20.sol";
import "./libraries/ReentrancyGuard.sol";
import "./libraries/Ownable.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IERC20Permit.sol";


contract RewardTracker is IERC20, ReentrancyGuard, IRewardTracker, Ownable {
    using SafeMath for uint256;
   

    address public depositToken;
    address public rewardToken;

    bool public isInitialized;
    bool public inPrivateTransferMode;
    bool public inPrivateStakingMode;
    bool public stableRewardSystem;

    mapping(address => uint256) public totalDepositSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => uint256) public override stakedAmounts;
    mapping(address => uint256) public claimableReward;
    mapping(address => uint256) public previousCumulatedRewardPerToken;
    mapping(address => uint256) public override cumulativeRewards;
    mapping(address => bool) public isHandler;

    string public name;
    string public symbol;

    uint256 public constant PRECISION = 1e30;
    uint256 public tokensPerInterval;
    uint256 public lastDistributionTime;
    uint256 public override totalSupply;
    uint256 public cumulativeRewardPerToken;

    event Claim(address receiver, uint256 amount);
    event TokensPerIntervalChange(uint256 amount);

    constructor(address _initialOwner, string memory _name, string memory _symbol, address _handler) Ownable(_initialOwner) {
        name = _name;
        symbol = _symbol;
        isHandler[_handler] = true;
    }

    function initialize(
        address _depositToken,
        address _rewardToken
    ) external onlyOwner {
        require(!isInitialized, "RewardTracker: already initialized");
        isInitialized = true;
        depositToken = _depositToken;
        rewardToken = _rewardToken;
        inPrivateTransferMode = true;
    }

    function setInPrivateModes(
        bool _inPrivateTransferMode
    ) external onlyOwner {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyOwner {
        isHandler[_handler] = _isActive;
    }

    function balanceOf(
        address _account
    ) external view override returns (uint256) {
        return balances[_account];
    }

    function stakeWithPermit(
        address _depositToken,
        uint256 _permitAmount,
        uint256 _amount,
        uint deadline,
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external nonReentrant {
        IERC20Permit(depositToken).permit(msg.sender, address(this), _permitAmount, deadline, v, r, s); //update to maxUint
        _stake(msg.sender, msg.sender, _depositToken, _amount);
    }

    function stakeForAccount(
        address _fundingAccount,
        address _account,
        address _depositToken,
        uint256 _amount
    ) external override nonReentrant {
        _validateHandler();
        _stake(_fundingAccount, _account, _depositToken, _amount);
    }

    function unstakeForAccount(
        address _account,
        address _depositToken,
        uint256 _amount,
        address _receiver
    ) external override nonReentrant {
        _validateHandler();
        _unstake(_account, _depositToken, _amount, _receiver);
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(
        address _spender,
        uint256 _amount
    ) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        if (isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }

        uint256 nextAllowance = allowances[_sender][msg.sender].sub(
            _amount,
            "RewardTracker: transfer amount exceeds allowance"
        );
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function setTokensPerInterval(uint256 _amount) external onlyOwner {
        require(
            lastDistributionTime != 0,
            "RewardTracker: invalid lastDistributionTime"
        );
       _updateRewards(address(0));
        tokensPerInterval = _amount;
        emit TokensPerIntervalChange(_amount);
    }

    function updateRewards() external override nonReentrant {
        _updateRewards(address(0));
    }

    function updateLastDistributionTime() external onlyOwner {
        lastDistributionTime = block.timestamp;
    }

    function claimForAccount(
        address _account,
        address _receiver
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _claim(_account, _receiver);
    }

    function claimable(
        address _account
    ) public view override returns (uint256) {
        uint256 stakedAmount = stakedAmounts[_account];
        if (stakedAmount == 0) {
            return claimableReward[_account];
        }
        uint256 supply = totalSupply;
        uint256 _pendingRewards = pendingRewards().mul(PRECISION);
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken.add(
            _pendingRewards.div(supply)
        );
        return
            claimableReward[_account].add(
                stakedAmount
                    .mul(
                        nextCumulativeRewardPerToken.sub(
                            previousCumulatedRewardPerToken[_account]
                        )
                    )
                    .div(PRECISION)
            );
    }

    function _claim(
        address _account,
        address _receiver
    ) private returns (uint256) {
        if (stableRewardSystem) {
        _updateRewards(_account);
        }

        uint256 tokenAmount = claimableReward[_account];
        claimableReward[_account] = 0;

        if (tokenAmount > 0) {
            IERC20(rewardToken).transfer(_receiver, tokenAmount);
            emit Claim(_account, tokenAmount);
        }

        return tokenAmount;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(
            _account != address(0),
            "RewardTracker: mint to the zero address"
        );

        totalSupply = totalSupply.add(_amount);
        balances[_account] = balances[_account].add(_amount);

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(
            _account != address(0),
            "RewardTracker: burn from the zero address"
        );

        balances[_account] = balances[_account].sub(
            _amount,
            "RewardTracker: burn amount exceeds balance"
        );
        totalSupply = totalSupply.sub(_amount);

        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) private {
        require(
            _sender != address(0),
            "RewardTracker: transfer from the zero address"
        );
        require(
            _recipient != address(0),
            "RewardTracker: transfer to the zero address"
        );

        if (inPrivateTransferMode) {
            _validateHandler();
        }

        balances[_sender] = balances[_sender].sub(
            _amount,
            "RewardTracker: transfer amount exceeds balance"
        );
        balances[_recipient] = balances[_recipient].add(_amount);

        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) private {
        require(
            _owner != address(0),
            "RewardTracker: approve from the zero address"
        );
        require(
            _spender != address(0),
            "RewardTracker: approve to the zero address"
        );

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "RewardTracker: forbidden");
    }

    function _stake(
        address _fundingAccount,
        address _account,
        address _depositToken,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardTracker: invalid _amount");
        

        IERC20(_depositToken).transferFrom(
            _fundingAccount,
            address(this),
            _amount
        );

        if (stableRewardSystem) {
        _updateRewards(_account);
        }

        stakedAmounts[_account] = stakedAmounts[_account].add(_amount);
        totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken]
            .add(_amount);

        _mint(_account, _amount);
    }

    function _unstake(
        address _account,
        address _depositToken,
        uint256 _amount,
        address _receiver
    ) private {
        require(_amount > 0, "RewardTracker: invalid _amount");

        if (stableRewardSystem) {
        _updateRewards(_account);
        }

        uint256 stakedAmount = stakedAmounts[_account];
        require(
            stakedAmounts[_account] >= _amount,
            "RewardTracker: _amount exceeds stakedAmount"
        );

        stakedAmounts[_account] = stakedAmount.sub(_amount);
        totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken].sub(_amount);

        _burn(_account, _amount);
        IERC20(_depositToken).transfer(_receiver, _amount);
    }

    function pendingRewards() public view returns (uint256) {
        if (block.timestamp == lastDistributionTime) {
            return 0;
        }

        uint256 timeDiff = block.timestamp.sub(lastDistributionTime);
        return tokensPerInterval.mul(timeDiff);
    }

    function _updateRewards(address _account) private {
        uint256 blockReward = pendingRewards();
        lastDistributionTime = block.timestamp;
        uint256 supply = totalSupply;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        if (supply > 0 && blockReward > 0) {
            _cumulativeRewardPerToken = _cumulativeRewardPerToken.add(
                blockReward.mul(PRECISION).div(supply)
            );
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }

        // cumulativeRewardPerToken can only increase
        // so if cumulativeRewardPerToken is zero, it means there are no rewards yet
        if (_cumulativeRewardPerToken == 0) {
            return;
        }

        if (_account != address(0)) {
            uint256 stakedAmount = stakedAmounts[_account];
            uint256 accountReward = stakedAmount
                .mul(
                    _cumulativeRewardPerToken.sub(
                        previousCumulatedRewardPerToken[_account]
                    )
                )
                .div(PRECISION);
            uint256 _claimableReward = claimableReward[_account].add(
                accountReward
            );

            claimableReward[_account] = _claimableReward;
            previousCumulatedRewardPerToken[
                _account
            ] = _cumulativeRewardPerToken;

            if (_claimableReward > 0 && stakedAmounts[_account] > 0) {
                uint256 nextCumulativeReward = cumulativeRewards[_account].add(
                    accountReward
                );

                cumulativeRewards[_account] = nextCumulativeReward;
            }
        }
    }
}
