// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Port3Bridge is Context, Initializable, ReentrancyGuard {
    using SafeMath for uint256;   // for add sub mul div methods
    using SafeERC20 for IERC20;   // for safeTransferFrom, safeTransfer methods 

    enum ChainType {
        SolanaType
    }

    // struct UserInfo {
    //     uint256 depositAmount;
    //     uint256 withdrawAmount;
    // }

    bool public isPaused;
    address public owner;
    address public gasReceiver;
    uint256 public maxAmount;

    // mapping(address => UserInfo) public userInfo;
    mapping(ChainType => uint256) public gasInfo;

    event Deposit(
        address indexed _user,
        address _token,
        uint256 _amount,
        string _receiver,
        ChainType _type
    );
    event Withdraw(
        address indexed _to, 
        address _token,
        uint256 _amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner is allowed");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Contract has been suspended");
        _;
    }

    function initialize(address _owner, address _gasReceiver, uint256 _maxAmount) external initializer {
        owner = _owner;
        maxAmount = _maxAmount;
        gasReceiver = _gasReceiver;
        isPaused = false;
    }

    function setGasFee(ChainType _type, uint256 _gasFee) external onlyOwner {
        gasInfo[_type] = _gasFee;
    }

    function setGasReceiver(address _gasReceiver) external onlyOwner {
        gasReceiver = _gasReceiver;
    }

    function setIsPaused(bool _isPaused) external onlyOwner {
        isPaused = _isPaused;
    }

    function setMaxAmount(uint256 _maxAmount) external onlyOwner {
        maxAmount = _maxAmount;
    }
    
    function deposit(address _token, uint256 _amount, string calldata _receiver, ChainType _type) external payable whenNotPaused {
        require(_amount <= maxAmount, 'add amount limit for each order');
        require(IERC20(_token).balanceOf(address(msg.sender)) >= _amount, 'Insufficient token balance');
        require(gasInfo[ChainType.SolanaType] == msg.value, 'Insufficient handling fee');

        IERC20(_token).safeTransferFrom(address(msg.sender), address(this), _amount);

        if (msg.value > 0 && gasReceiver != address(0)) {
            payable(gasReceiver).transfer(msg.value);
        }

        emit Deposit(msg.sender, _token, _amount, _receiver, _type);
    }

    function withdraw(address _token, address _to, uint256 _amount) external onlyOwner {
        require(IERC20(_token).balanceOf(address(this)) >= _amount, 'Insufficient token balance');
        IERC20(_token).safeTransfer(_to, _amount);
        emit Withdraw(_to, _token, _amount);
    }

    function GetInitializeData(address _owner, address _gasReceiver, uint256 _maxAmount) public pure returns(bytes memory){
        return abi.encodeWithSignature("initialize(address,address,uint256)", _owner, _gasReceiver, _maxAmount);
    }
    
}
