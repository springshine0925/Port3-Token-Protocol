// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Port3Vault.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Port3StakePool is Context, Initializable, ReentrancyGuard {
    using SafeMath for uint256;   // for add sub mul div methods
    using SafeERC20 for IERC20;   // for safeTransferFrom, safeTransfer methods 

    struct PoolInfo {
        IERC20 lpToken;                 // Token Contract
        uint256 amount;                 // Amount of token in pool.
        uint256 lockPeriod;             // lock period of  LP pool
        uint256 unlockPeriod;           // unlock period of  LP pool
        uint256 tokenPerDaily;          // reward token by daily
        uint256 startTime;              // reward distribute start time
        uint256 endTime;                // reward distribute end time
        bool isOpenReward;              // Whether to enable reward distribution
        bool isRewardEth;               // Is the reward in ETH
        bool emergencyEnable;           // pool withdraw emergency enable
    }
    
    struct UserInfo {
        uint256 amount;         // How many lpTokens the user has provided.
        uint256 rewardClaimed;  // Reward that user already claimed, preventing repeat calculation
        uint256 depositTime;    // Last time of deposit operation
        uint256 lastHarvestTime;
    }
    
    bool public isPaused;
    address public owner;

    Port3Vault public port3Vault;   

    // Fee
    address public feeAccount;
    uint256 public feePerThousand;
    
    // User and Pool registrations
    PoolInfo[] public poolInfo;

    // poolId => address => UserInfo
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total mint reward.
    uint256 public totalMintReward;
    uint256 public totalEthMintReward;

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event Withdraw(
        address indexed user, 
        uint256 indexed pid, 
        uint256 amount
    );
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid, 
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner is allowed");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Contract has been suspended");
        _;
    }

    function initialize(address _owner, address payable _port3Vault) external initializer {
        owner = _owner;
        isPaused = false;
        port3Vault = Port3Vault(_port3Vault);
        totalMintReward = 0;
        totalEthMintReward = 0;
    }

    function setFee(address _account, uint256 _feePerThousand) external onlyOwner {
        feeAccount = _account;
        feePerThousand = _feePerThousand;
    }

    function setIsPaused(bool _isPaused) external onlyOwner {
        isPaused = _isPaused;
    }
    
    function setVaultContract(Port3Vault _port3Vault) external onlyOwner {
        port3Vault = _port3Vault;
    }

    // === Stake pool operations ===
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new pool. Can only be called by the owner.
    function addPool(IERC20 _lpToken) external onlyOwner {
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                amount: 0,
                lockPeriod: 0,
                unlockPeriod: 0,
                tokenPerDaily: 0,
                startTime: 0,
                endTime: 0,
                isOpenReward: false,
                isRewardEth: false,
                emergencyEnable: false
            })
        );
    }

    // Update the given pool's reward setting
    function setPoolReward(uint256 _pid, uint256 _tokenPerDaily, bool _isOpenReward, bool _isRewardEth, uint256 _startTime, uint256 _endTime) external onlyOwner {
      poolInfo[_pid].tokenPerDaily = _tokenPerDaily;
      poolInfo[_pid].isOpenReward = _isOpenReward;
      poolInfo[_pid].isRewardEth = _isRewardEth;
      poolInfo[_pid].startTime = _startTime;
      poolInfo[_pid].endTime = _endTime;
    }

    // Update the given pool's lock period and unlock period.
    function setPoolLockTime(uint256 _pid, uint256 _lockPeriod, uint256 _unlockPeriod) external onlyOwner {
        poolInfo[_pid].lockPeriod = _lockPeriod;
        poolInfo[_pid].unlockPeriod = _unlockPeriod;
    }

    // Update the given pool's withdraw emergency Enable.
    function setPoolEmergencyEnable(uint256 _pid, bool _emergencyEnable) external onlyOwner {
        poolInfo[_pid].emergencyEnable = _emergencyEnable;
    }

    // View function to see pending tokens on frontend.
    function pendingTokenReward(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        if (user.amount <= 0) {
            return 0;
        }

        uint256 remain = 0;
        uint256 poolReward = tokenRewardPerSecondForPool(_pid).mul(getTimeCount(_pid, user.lastHarvestTime, block.timestamp));
        uint256 userReward = user.amount.mul(1e12).div(pool.amount).mul(poolReward).div(1e12);

        if (userReward <= 0) {
          return 0;
        }

        if (pool.isRewardEth == true) {
          remain = address(port3Vault).balance;
        } else {
          remain = port3Vault.amount();
        }

        if (remain < userReward) {
          userReward = remain;
        }

        return userReward;
    }

    
    // === User operations ===

    // Havest tokenReward when deposit/withdraw
    function _harvest(uint256 _pid, address _user) private {
        uint256 userReward = pendingTokenReward(_pid, _user);

        UserInfo storage user = userInfo[_pid][_user];
        PoolInfo storage pool = poolInfo[_pid];

        if (userReward > 0) {
            user.rewardClaimed = user.rewardClaimed.add(userReward);
            if (pool.isRewardEth) {
                totalEthMintReward = totalEthMintReward.add(userReward);
                port3Vault.withdraw(_user, userReward);
            } else {
                totalMintReward = totalMintReward.add(userReward);
                port3Vault.transferTo(_user, userReward);
            }
        }
        user.lastHarvestTime = block.timestamp;
    }

    function _deposit(uint256 _pid, uint256 _amount, address _to) private {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_to];

        _harvest(_pid, _to);
        
        if (_amount > 0) {
            // Fee
            if (feePerThousand != 0 && feeAccount != address(0)) {
                uint256 fee = _amount.mul(feePerThousand).div(1000); 
                _amount = _amount.sub(fee);
                pool.lpToken.safeTransferFrom(msg.sender, feeAccount, fee);
            }

            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);

            user.amount = user.amount.add(_amount);
            pool.amount = pool.amount.add(_amount);
            user.depositTime = block.timestamp;

            emit Deposit(_to, _pid, _amount);
        }
    }

    function depositTo(uint256 _pid, uint256 _amount, address _to) external whenNotPaused {
        _deposit(_pid, _amount, _to);
    }

    function deposit(uint256 _pid, uint256 _amount) external whenNotPaused {
        _deposit(_pid, _amount, msg.sender);
    }

    function canWithdraw(address _address, uint256 _pid, uint256 _amount) view public returns (uint8) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_address];

        if(user.amount < _amount) {
            return 2; // Don't have enough to withdraw
        }

        if (_amount > 0 && pool.lockPeriod > 0) {
            uint256 timeDelta = block.timestamp - user.depositTime; 
            bool inLockPeriod = timeDelta < pool.lockPeriod;
            bool notInUnlockPeriod = pool.unlockPeriod > 0 && (timeDelta % pool.lockPeriod) > pool.unlockPeriod;
            if (inLockPeriod || notInUnlockPeriod) {
                return 1;
            }
        }

        return 0;
    }

    // Withdraw tokens.
    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(canWithdraw(msg.sender, _pid, _amount) == 0, "Not enough or not in unlockPeriod");

        _harvest(_pid, msg.sender);
        
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.amount = pool.amount.sub(_amount);
            
            pool.lpToken.safeTransfer(msg.sender, _amount);
            emit Withdraw(msg.sender, _pid, _amount);
        }
    }

    function harvest(uint256 _pid, address _user) external {
        _harvest(_pid, _user);
    }

    // Withdraw all tokens without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            pool.lockPeriod == 0 || pool.emergencyEnable == true,
            "Can't emergencyWithdraw if pool have lockPeriod or not emergencyEnabled"
        );
        
        user.amount = 0;
        pool.lpToken.safeTransfer(msg.sender, user.amount);

        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    //  === Utility Methods ===
    
    // Return amount of block over the given _from to _to block.
    function getTimeCount(uint256 _pid, uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 fromFinal = _from > pool.startTime ? _from : pool.startTime;
        uint256 toFinal = _to > pool.endTime ? pool.endTime : _to;
        if (fromFinal >= toFinal) {
            return 0;
        }
        return toFinal.sub(fromFinal);
    }

    // 每秒产出奖励
    function tokenRewardPerSecondForPool(uint256 _pid) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 dailySecond = 86400;

        if (pool.isOpenReward == false) {
          return 0;
        }

        if (pool.tokenPerDaily == 0) {
          return 0;
        }

        uint256 tokenReward = pool.tokenPerDaily.div(dailySecond);
        return tokenReward;
    }

    function GetInitializeData(address _owner, address _port3Vault) public pure returns(bytes memory){
        return abi.encodeWithSignature("initialize(address,address)", _owner,_port3Vault);
    }
    
}
