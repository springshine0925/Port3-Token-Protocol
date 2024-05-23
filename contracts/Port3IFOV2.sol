// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Port3IFOV2 is Context, Initializable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public owner;
    address public manager;

    // === EIP 712 ===
    string public constant domainName = "Port3IFO";
    string public constant version = "1";
    // keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"))
    bytes32 public constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // keccak256(bytes("deposit(address to,uint256 pid,uint256 amount,uint256 maxAmount)"))
    bytes32 public constant DEPOSIT_TYPEHASH = 0x19706aadaecdda014dd98eebd8aa34fd47409e027917a4c1e02bf85762ad0e60;

    struct PoolInfo {
        address lpToken;
        IERC20 offeringToken;
        uint256 startTime;
        uint256 endTime;
        uint256 claimTime;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 raisingAmount;
        uint256 offeringAmount;
        uint256 totalAmount;
        bool overfunding;
        bool isRefund; // Seven days refund
    }

    struct PoolUnlockInfo {
        uint256 initialRate; // 1e6
        uint256 tn;
        uint256 cliff;
        uint256 period;
    }

    struct UserInfo {
        uint256 amount;
        uint256 depositTime;
        uint256 claimedAmount;
    }

    PoolInfo[] public poolInfo;
    mapping (uint256 => PoolUnlockInfo) public poolUnlockInfo;
    mapping (uint256 => mapping(address => UserInfo)) public userInfo;
    mapping (uint256 => address[]) public addressList;
    

    event Deposit(address indexed user, uint256 pid, uint256 amount);
    event Harvest(address indexed user, uint256 pid, uint256 offeringAmount, uint256 refundAmount);

    constructor() public {}

    /* solium-disable-next-line */
    receive () external payable {
    }
    
    function initialize(address _owner, address _manager) external initializer {
        owner = _owner;
        manager = _manager;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner, "only admin is allowed");
        _;
    }

    modifier onlySigner(uint256 _pid, uint256 _amount, uint256 _maxAmount, bytes calldata signature) {
        bytes32 digest = _getDigest(msg.sender, _pid, _amount, _maxAmount);
        address signer = ECDSA.recover(digest, signature);
        require(signer == manager, "Port3IFO: invalid signer");
        _;
    }

    function _onlySigner(
        uint256 _pid, 
        uint256 _amount, 
        uint256 _maxAmount, 
        bytes calldata signature
    ) private view returns (bool) {
        bytes32 digest = _getDigest(msg.sender, _pid, _amount, _maxAmount);
        address signer = ECDSA.recover(digest, signature);
        return signer == manager;
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        bytes32 nameHash = keccak256(bytes(domainName));
        bytes32 versionHash = keccak256(bytes(version));
        return keccak256(abi.encode(DOMAIN_TYPEHASH, nameHash, versionHash, block.chainid, address(this)));
    }

    function _hashTypedDataV4(bytes32 structHash) private view returns (bytes32) {
        return ECDSA.toTypedDataHash(_buildDomainSeparator(), structHash);
    }

    function _getDigest(address _user, uint256 _pid, uint256 _amount, uint256 _maxAmount) private view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(DEPOSIT_TYPEHASH, _user, _pid, _amount, _maxAmount)));
    }

    function setOfferingAmount(uint256 _pid, uint256 _offerAmount) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(block.timestamp < pool.startTime, 'Pool has been started');
        pool.offeringAmount = _offerAmount;
    }

    function setIsRefund(uint256 _pid, bool _isRefund) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        pool.isRefund = _isRefund;
    }

    function setRaisingAmount(uint256 _pid, uint256 _raisingAmount) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(block.timestamp < pool.startTime, 'Pool has been started');
        pool.raisingAmount = _raisingAmount;
    }

    function setPoolTime(uint256 _pid, uint256 _startTime, uint256 _endTime, uint256 _claimTime) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(_endTime > _startTime, 'startTime < endTime');
        require(_claimTime >= _endTime, 'claimtime >= endTime');
        pool.startTime = _startTime;
        pool.endTime = _endTime;
        pool.claimTime = _claimTime;
    }

    function setPoolAmount(uint256 _pid, uint256 _minAmount, uint256 _maxAmount) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(block.timestamp < pool.startTime, 'Pool has been started');
        require(pool.minAmount <= pool.maxAmount, 'maxAmount >= minAmount');
        pool.minAmount = _minAmount;
        pool.maxAmount = _maxAmount;
    }

    function deposit(
        uint256 _pid, 
        uint256 _amount, 
        uint256 _maxAmount, 
        bytes calldata _signature
    // ) external payable onlySigner(_pid, _amount, _maxAmount, _signature) {
    ) external payable {
        require(_onlySigner(_pid, _amount, _maxAmount, _signature), "Port3IFO: invalid signer");

        PoolInfo storage pool = poolInfo[_pid];
        if (pool.lpToken == address(0)) {
            require(_amount == msg.value, 'Value fail');
        }

        require(block.timestamp > pool.startTime && block.timestamp < pool.endTime, 'not ifo time');
        require(_amount >= pool.minAmount, 'should be more than the minimum amount.');
        require(userInfo[_pid][msg.sender].amount.add(_amount) <= pool.maxAmount, 'exceeds the maximum amount.');
        require(_amount > 0, 'need _amount > 0');

        if (_maxAmount > 0) {
            require(userInfo[_pid][msg.sender].amount.add(_amount) <= _maxAmount, 'exceeds the maximum amount.');
        }

        if (!pool.overfunding) {
            require(pool.totalAmount.add(_amount) <= pool.raisingAmount, 'Fundraising is overflow');
        }

        if (pool.lpToken != address(0)) {
            IERC20(pool.lpToken).safeTransferFrom(address(msg.sender), address(this), _amount);
        }

        if (userInfo[_pid][msg.sender].amount == 0) {
            addressList[_pid].push(address(msg.sender));
        }

        userInfo[_pid][msg.sender].amount = userInfo[_pid][msg.sender].amount.add(_amount);
        userInfo[_pid][msg.sender].depositTime = block.timestamp;
        pool.totalAmount = pool.totalAmount.add(_amount);

        emit Deposit(msg.sender, _pid, _amount);
    }

    function claim(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];

        require(block.timestamp > pool.claimTime, 'not claim time');
        require(userInfo[_pid][msg.sender].amount > 0, 'nothing to claim');

        uint256 claimAmount = 0;
        uint256 offeringTokenAmount = getOfferingAmount(_pid, msg.sender);
        uint256 refundingTokenAmount = 0;
        if (userInfo[_pid][msg.sender].claimedAmount == 0) {
            refundingTokenAmount = getRefundingAmount(_pid, msg.sender);
        }
        
        claimAmount = getClaimAmount(_pid, offeringTokenAmount, msg.sender);
        userInfo[_pid][msg.sender].claimedAmount = userInfo[_pid][msg.sender].claimedAmount.add(claimAmount);

        require(userInfo[_pid][msg.sender].claimedAmount <= offeringTokenAmount, 'Already claimed');
        if (claimAmount > 0) {
            pool.offeringToken.safeTransfer(address(msg.sender), claimAmount);
        }

        if (refundingTokenAmount > 0) {
            if (pool.lpToken != address(0)) {
                IERC20(pool.lpToken).safeTransfer(address(msg.sender), refundingTokenAmount);
            } else {
                payable(address(msg.sender)).transfer(refundingTokenAmount);
            }
        }
        emit Harvest(msg.sender, _pid, claimAmount, refundingTokenAmount);
    }

    function getClaimAmount(uint256 _pid, uint256 _offeringAmount, address _user) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        PoolUnlockInfo storage poolUnlock = poolUnlockInfo[_pid];

        if (poolUnlock.tn == 0 && poolUnlock.initialRate == 0) {
            return 0;
        }

        if (poolUnlock.tn == 0) {
            return _offeringAmount;
        }

        uint256 claimAmount = 0;
        if (poolUnlock.initialRate > 0 && userInfo[_pid][_user].claimedAmount == 0) {
            claimAmount = _offeringAmount.mul(poolUnlock.initialRate).div(1e6);
        } else {
            if (block.timestamp.sub(pool.claimTime) < poolUnlock.cliff) {
                return 0;
            }

            claimAmount = _offeringAmount.mul(1e6 - poolUnlock.initialRate).div(poolUnlock.tn);
            claimAmount = claimAmount.mul(block.timestamp.sub(pool.claimTime).sub(poolUnlock.cliff).div(poolUnlock.period)).div(1e6);
            claimAmount = claimAmount.add(_offeringAmount.mul(poolUnlock.initialRate).div(1e6));
        }

        if (claimAmount > userInfo[_pid][_user].claimedAmount) {
            claimAmount = claimAmount.sub(userInfo[_pid][_user].claimedAmount);
        } else {
            claimAmount = 0;
        }

        if (claimAmount > _offeringAmount.sub(userInfo[_pid][_user].claimedAmount)) {
            claimAmount = _offeringAmount.sub(userInfo[_pid][_user].claimedAmount);
        }

        return claimAmount;
    }

    // allocation 100000 means 0.1(10%), 1 meanss 0.000001(0.0001%), 1000000 means 1(100%)
    function getUserAllocation(uint256 _pid, address _user) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return userInfo[_pid][_user].amount.mul(1e12).div(pool.totalAmount).div(1e6);
    }

    // get the amount of IFO token you will get
    function getOfferingAmount(uint256 _pid, address _user) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.totalAmount > pool.raisingAmount) {
            uint256 allocation = getUserAllocation(_pid, _user);
            return pool.offeringAmount.mul(allocation).div(1e6);
        } else {
            return userInfo[_pid][_user].amount.mul(pool.offeringAmount).div(pool.raisingAmount);
        }
    }

    // get the amount of lp token you will be refunded
    function getRefundingAmount(uint256 _pid, address _user) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.totalAmount <= pool.raisingAmount) {
            return 0;
        }
        uint256 allocation = getUserAllocation(_pid, _user);
        uint256 payAmount = pool.raisingAmount.mul(allocation).div(1e6);
        return userInfo[_pid][_user].amount.sub(payAmount);
    }

    function refundingAmount(uint256 _pid) external payable returns(uint256 amount) {
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.isRefund, 'Refund are not supported in this pool');
        require(userInfo[_pid][msg.sender].claimedAmount == 0, 'Refund are not supported once tokens have been claimed.');
        require(pool.endTime < block.timestamp, 'The project is not over yet');
        require(block.timestamp.sub(pool.endTime) < 7 * 86400, 'Refund should be processed within 7 days.');

        amount = userInfo[_pid][msg.sender].amount;
        userInfo[_pid][msg.sender].amount = 0;
        if (pool.lpToken != address(0)) {
            IERC20(pool.lpToken).safeTransfer(msg.sender, amount);
        } else {
            payable(msg.sender).transfer(amount);
        }
    }

    function getAddressListLength(uint256 _pid) external view returns(uint256) {
        return addressList[_pid].length;
    }

    function finalWithdraw(address _to, uint256 _pid, uint256 _lpAmount, uint256 _offerAmount) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];

        if (pool.lpToken != address(0)) {
            require(_lpAmount <= IERC20(pool.lpToken).balanceOf(address(this)), 'wrong amount for funding token');
        } else {
            require(_lpAmount <= address(this).balance, 'wrong amount for funding token');
        }

        require(_offerAmount <= pool.offeringToken.balanceOf(address(this)), 'Insufficient offering token');

        if(_offerAmount > 0) {
            pool.offeringToken.safeTransfer(_to, _offerAmount);
        }
        if(_lpAmount > 0) {
            if (pool.lpToken != address(0)) {
                IERC20(pool.lpToken).safeTransfer(_to, _lpAmount);
            } else {
                payable(_to).transfer(_lpAmount);
            }
        }
    }

    function addPool(
        address _lpToken, 
        IERC20 _offeringToken, 
        uint256[] calldata times, 
        uint256[] calldata amounts, 
        bool _overfunding) external onlyAdmin {
            require(times[1] > times[0], 'startTime < endTime');
            require(times[2] >= times[1], 'claimtime >= endTime');

            poolInfo.push(
                PoolInfo({
                    lpToken: _lpToken,
                    offeringToken: _offeringToken,
                    startTime: times[0],
                    endTime: times[1],
                    claimTime: times[2],
                    minAmount: amounts[0],
                    maxAmount: amounts[1],
                    raisingAmount: amounts[2],
                    offeringAmount: amounts[3],
                    totalAmount: 0,
                    overfunding: _overfunding,
                    isRefund: true
                })
            );
    }

    function setPoolUnlockInfo(uint256 _pid, uint256 _initialRate, uint256 _tn, uint256 _cliff, uint256 _period) external onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.raisingAmount > 0, "Pool not found");

        PoolUnlockInfo storage poolUnlock = poolUnlockInfo[_pid];
        poolUnlock.tn = _tn;
        poolUnlock.cliff = _cliff;
        poolUnlock.period = _period;
        poolUnlock.initialRate = _initialRate;
    }

    function setOwner(address _owner) external onlyAdmin {
        require(_owner != address(0), "Owner can't be zero address");
        owner = _owner;
    }

    function setManager(address _manager) external onlyAdmin {
        require(_manager != address(0), "Manager can't be zero address");
        manager = _manager;
    }

    function GetInitializeData(address _owner, address _manager) public pure returns(bytes memory){
        return abi.encodeWithSignature("initialize(address,address)", _owner,_manager);
    }
}
