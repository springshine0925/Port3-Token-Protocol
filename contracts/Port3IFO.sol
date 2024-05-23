// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Port3IFO is Context, Initializable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public owner;
    address public manager;

    // === EIP 712 ===
    string public constant domainName = "Port3IFO";
    string public constant version = "1";
    // keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"))
    bytes32 public constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // keccak256(bytes("deposit(address to,uint8 pid,uint256 amount)"))
    bytes32 public constant CLAIM_TYPEHASH = 0xbcafe8bbe25ab283106ee866a24fe445bf8341c04dfa429ecbf7dc067286fc33;

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
        bool isBeyond;
    }

    struct UserInfo {
        uint256 amount;
        uint256 depositTime;
        bool claimed;
    }

    PoolInfo[] public poolInfo;
    mapping (uint8 => mapping(address => UserInfo)) public userInfo;
    mapping (uint8 => address[]) public addressList;
    

    event Deposit(address indexed user, uint8 pid, uint256 amount);
    event Harvest(address indexed user, uint8 pid, uint256 offeringAmount, uint256 excessAmount);

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

    modifier onlySigner(uint8 _pid, uint256 _amount, bytes calldata signature) {
        bytes32 digest = _getDigest(msg.sender, _pid, _amount);
        address signer = ECDSA.recover(digest, signature);
        require(signer == manager, "Port3IFO: invalid signer");
        _;
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        bytes32 nameHash = keccak256(bytes(domainName));
        bytes32 versionHash = keccak256(bytes(version));
        return keccak256(abi.encode(DOMAIN_TYPEHASH, nameHash, versionHash, block.chainid, address(this)));
    }

    function _hashTypedDataV4(bytes32 structHash) private view returns (bytes32) {
        return ECDSA.toTypedDataHash(_buildDomainSeparator(), structHash);
    }

    function _getDigest(address _user, uint8 _pid, uint256 _amount) private view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(CLAIM_TYPEHASH, _user, _pid, _amount)));
    }

    function setOfferingAmount(uint8 _pid, uint256 _offerAmount) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(block.timestamp < pool.startTime, 'Pool has been started');
        pool.offeringAmount = _offerAmount;
    }

    function setRaisingAmount(uint8 _pid, uint256 _raisingAmount) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(block.timestamp < pool.startTime, 'Pool has been started');
        pool.raisingAmount = _raisingAmount;
    }

    function setPoolTime(uint8 _pid, uint256 _startTime, uint256 _endTime, uint256 _claimTime) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(_endTime > _startTime, 'startTime < endTime');
        require(_claimTime >= _endTime, 'claimtime >= endTime');
        pool.startTime = _startTime;
        pool.endTime = _endTime;
        pool.claimTime = _claimTime;
    }

    function setPoolAmount(uint8 _pid, uint256 _minAmount, uint256 _maxAmount) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];
        require(block.timestamp < pool.startTime, 'Pool has been started');
        require(pool.minAmount <= pool.maxAmount, 'maxAmount >= minAmount');
        pool.minAmount = _minAmount;
        pool.maxAmount = _maxAmount;
    }

    function deposit(uint8 _pid, uint256 _amount, bytes calldata _signature) external payable onlySigner(_pid, _amount, _signature) {
        PoolInfo storage pool = poolInfo[_pid];

        if (pool.lpToken == address(0)) {
            require(_amount == msg.value, 'Value fail');
        }

        require(block.timestamp > pool.startTime && block.timestamp < pool.endTime, 'not ifo time');
        require(_amount >= pool.minAmount, 'should be more than the minimum amount.');
        require(userInfo[_pid][msg.sender].amount.add(_amount) <= pool.maxAmount, 'exceeds the maximum amount.');
        require(_amount > 0, 'need _amount > 0');

        if (!pool.isBeyond) {
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

    function claim(uint8 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];

        require(block.timestamp > pool.claimTime, 'not harvest time');
        require(userInfo[_pid][msg.sender].amount > 0, 'nothing to claim');
        require(!userInfo[_pid][msg.sender].claimed, 'already claimed');

        userInfo[_pid][msg.sender].claimed = true;

        uint256 offeringTokenAmount = getOfferingAmount(_pid, msg.sender);
        uint256 refundingTokenAmount = getRefundingAmount(_pid, msg.sender);

        if (offeringTokenAmount > 0) {
            pool.offeringToken.safeTransfer(address(msg.sender), offeringTokenAmount);
        }

        if (refundingTokenAmount > 0) {
            if (pool.lpToken != address(0)) {
                IERC20(pool.lpToken).safeTransfer(address(msg.sender), refundingTokenAmount);
            } else {
                payable(address(msg.sender)).transfer(refundingTokenAmount);
            }
        }
        emit Harvest(msg.sender, _pid, offeringTokenAmount, refundingTokenAmount);
    }

    function isClaimed(uint8 _pid, address _user) external view returns(bool) {
        return userInfo[_pid][_user].claimed;
    }

    // allocation 100000 means 0.1(10%), 1 meanss 0.000001(0.0001%), 1000000 means 1(100%)
    function getUserAllocation(uint8 _pid, address _user) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return userInfo[_pid][_user].amount.mul(1e12).div(pool.totalAmount).div(1e6);
    }

    // get the amount of IFO token you will get
    function getOfferingAmount(uint8 _pid, address _user) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.totalAmount > pool.raisingAmount) {
            uint256 allocation = getUserAllocation(_pid, _user);
            return pool.offeringAmount.mul(allocation).div(1e6);
        }
        else {
            return userInfo[_pid][_user].amount.mul(pool.offeringAmount).div(pool.raisingAmount);
        }
    }

    // get the amount of lp token you will be refunded
    function getRefundingAmount(uint8 _pid, address _user) public view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.totalAmount <= pool.raisingAmount) {
            return 0;
        }
        uint256 allocation = getUserAllocation(_pid, _user);
        uint256 payAmount = pool.raisingAmount.mul(allocation).div(1e6);
        return userInfo[_pid][_user].amount.sub(payAmount);
    }

    function getAddressListLength(uint8 _pid) external view returns(uint256) {
      return addressList[_pid].length;
    }

    function finalWithdraw(address _to, uint8 _pid, uint256 _lpAmount, uint256 _offerAmount) public onlyAdmin {
        PoolInfo storage pool = poolInfo[_pid];

        if (pool.lpToken != address(0)) {
            require(_lpAmount <= IERC20(pool.lpToken).balanceOf(address(this)), 'wrong amount for funding token');
        } else {
            require(_lpAmount <= address(this).balance, 'wrong amount for funding token');
        }

        require(_offerAmount < pool.offeringToken.balanceOf(address(this)), 'Insufficient offering token');

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
        bool _isBeyond) external onlyAdmin {
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
                    isBeyond: _isBeyond
                })
            );
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
