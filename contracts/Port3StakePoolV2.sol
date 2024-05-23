// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Port3Vault.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Port3StakePoolV2 is Context, Initializable, ReentrancyGuard {
    using SafeMath for uint256;   // for add sub mul div methods
    using SafeERC20 for IERC20;   // for safeTransferFrom, safeTransfer methods 

    struct PoolInfo {
        IERC20 lpToken;                 // Token Contract
        uint256 amount;                 // Amount of token in pool.
        uint256 lockPeriod;             // lock period of  LP pool
        uint256 unlockPeriod;           // unlock period of  LP pool
        uint256 apy;                    // year APY 1e4
        bool isOpenReward;              // Whether to enable reward distribution
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
    uint256 public destroyTokenRate; // 1e6
    
    // User and Pool registrations
    PoolInfo[] public poolInfo;

    // poolId => address => UserInfo
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total mint reward.
    uint256 public totalMintReward;

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

    event AdvanceWithdraw(
        address indexed user,
        uint256 indexed pid, 
        uint256 amount,
        uint256 destroyAmount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner is allowed");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Contract has been suspended");
        _;
    }

    function initialize(address _owner, address payable _port3Vault, uint256 _destroyTokenRate) external initializer {
        owner = _owner;
        isPaused = false;
        port3Vault = Port3Vault(_port3Vault);
        totalMintReward = 0;

        if (_destroyTokenRate <= 1e6) {
            destroyTokenRate = _destroyTokenRate;
        }
    }

    function setFee(address _account, uint256 _feePerThousand) external onlyOwner {
        feeAccount = _account;
        feePerThousand = _feePerThousand;
    }

    function setDestroyTokenRate(uint256 _destroyTokenRate) external onlyOwner {
        require(_destroyTokenRate <= 1e6, "DestroyTokenRate error");
        destroyTokenRate = _destroyTokenRate;
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
    function addPool(IERC20 _lpToken, uint256 _apy, uint256 _lockPeriod, bool _isOpenReward) external onlyOwner {
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                amount: 0,
                lockPeriod: _lockPeriod,
                unlockPeriod: 0,
                apy: _apy,
                isOpenReward: _isOpenReward,
                emergencyEnable: false
            })
        );
    }

    // Update the given pool's reward setting
    function setPoolReward(uint256 _pid, uint256 _apy, bool _isOpenReward) external onlyOwner {
      poolInfo[_pid].apy = _apy;
      poolInfo[_pid].isOpenReward = _isOpenReward;
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
    function pendingTokenReward(uint256 _pid, address _user) public view returns (uint256 userReward) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        if (!pool.isOpenReward || user.amount <= 0) {
            return userReward;
        }

        if (user.lastHarvestTime > 0) {
            userReward = block.timestamp.sub(user.lastHarvestTime).mul(user.amount).mul(pool.apy).div(1e4).div(365 * 86400);
        } else if (user.depositTime > 0) {
            userReward = block.timestamp.sub(user.depositTime).mul(user.amount).mul(pool.apy).div(1e4).div(365 * 86400);
        }

        return userReward;
    }

    
    // === User operations ===

    // Havest tokenReward when deposit/withdraw
    function _harvest(uint256 _pid, address _user) private {
        UserInfo storage user = userInfo[_pid][_user];
        PoolInfo storage pool = poolInfo[_pid];

        uint256 userReward = pendingTokenReward(_pid, _user);
        user.lastHarvestTime = block.timestamp;
        if (userReward > 0) {
            user.rewardClaimed = user.rewardClaimed.add(userReward);
            totalMintReward = totalMintReward.add(userReward);
            port3Vault.transferTo(_user, userReward);
        }
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

        require(_amount > 0, "Amount error");
        require(_amount > user.amount, "Don't have enough to withdraw");
        _harvest(_pid, msg.sender);
        
        uint8 code = canWithdraw(msg.sender, _pid, _amount);
        if (code == 1) { // early release
            uint256 amount = user.amount.mul(1e6 - destroyTokenRate).div(1e6);
            uint256 destroyAmount = user.amount.sub(amount);
            
            pool.amount = pool.amount.sub(user.amount);
            user.amount = 0;

            pool.lpToken.safeTransfer(msg.sender, amount);
            if (destroyAmount > 0) {
                pool.lpToken.safeTransfer(feeAccount, destroyAmount);
            }
            emit AdvanceWithdraw(msg.sender, _pid, amount, destroyAmount);
        } else if(code == 0) {
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
        
        uint256 amount = user.amount;
        user.amount = 0;
        pool.lpToken.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function GetInitializeData(address _owner, address _port3Vault, uint256 _destroyTokenRate) public pure returns(bytes memory){
        return abi.encodeWithSignature("initialize(address,address,uint256)", _owner,_port3Vault,_destroyTokenRate);
    }
    
}
