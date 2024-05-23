// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IPort3Stake.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract KOLVesting is Context, Initializable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public airdropToken;
    IPort3Stake public port3Stake;

    address public owner;
    address public manager;

    uint8 public port3StakePid;
    uint256 public airdropTime;

    // === EIP 712 ===
    string public constant domainName = "KOLVesting";
    string public constant version = "1";
    // keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"))
    bytes32 public constant DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // keccak256(bytes("claimToken(address to,uint8 listType,uint256 amount)"))
    bytes32 public constant CLAIM_TYPEHASH = 0x850f4d483fdb056e5b90a6178dc09e2762b5c2b390bca3ab54e4dee5122b7e53;

    struct AirdropInfo {
        uint256 t; // last claimed time
        uint256 totalAmount;
        uint256 claimedAmount;
    }
    mapping (address => AirdropInfo) public kolDonationList;

    enum ListType {
        KolDonationList
    }

    event ClaimToken(
        address indexed _user,
        uint256 _amount,
        ListType _listType
    );

    constructor() public {}

    /* solium-disable-next-line */
    receive () external payable {
    }

    modifier onlyAdmin() {
        require(msg.sender == owner, "only admin is allowed");
        _;
    }

    modifier onlySigner(uint8 _listType, uint256 _amount, bytes calldata signature) {
        bytes32 digest = _getDigest(msg.sender, _listType, _amount);
        address signer = ECDSA.recover(digest, signature);
        require(signer == manager, "KOLVesting: invalid signer");
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

    function _getDigest(address _user, uint8 _listType, uint256 _amount) private view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(CLAIM_TYPEHASH, _user, _listType, _amount)));
    }

    function initialize(address _owner, address _manager, address _airdropToken, uint256 _airdropTime) external initializer {
        owner = _owner;
        manager = _manager;
        airdropTime = _airdropTime;
        airdropToken = IERC20(_airdropToken);
    }

    function _claimAmount(address _user, ListType _listType) private view returns (uint256 claimAmount) {
        AirdropInfo storage userInfo;

        if (_listType == ListType.KolDonationList) {
            userInfo = kolDonationList[_user];
        } else {
            return claimAmount;
        }

        uint256 leftAmount = userInfo.totalAmount.sub(userInfo.claimedAmount);
        if (userInfo.totalAmount == 0 || leftAmount == 0) {
            return claimAmount;
        }

        uint256 t = 86400;
        if (_listType == ListType.KolDonationList) {
            // 25% advance , 1 week cliff , the rest in 25% every 3 weeks
            if (userInfo.claimedAmount == 0) {
                claimAmount = userInfo.totalAmount.mul(250000).div(1e6); // 25%
            } else {
                // claimAmount = [totalAmount * (1 - 0.25) / 10 * ((block_time - airdrop_time) / 3Week)] + (tatalAmount * 0.025) - claimedAmount
                if (block.timestamp.sub(airdropTime) <= 7 * t) {
                    return claimAmount; // 0
                }
                claimAmount = userInfo.totalAmount.mul(1e6 - 250000).div(3).mul(block.timestamp.sub(airdropTime).sub(7 * t).div(3 * 7 * t)).div(1e6);
                // claimAmount = userInfo.totalAmount.mul(1e6 - 250000).div(3).mul(block.timestamp.sub(airdropTime).div(3 * 7 * t)).div(1e6);
                claimAmount = claimAmount.add(userInfo.totalAmount.mul(250000).div(1e6));
            }
        }

        if (claimAmount > userInfo.claimedAmount) {
            claimAmount = claimAmount.sub(userInfo.claimedAmount);
        } else {
            claimAmount = 0;
        }

        if (claimAmount > userInfo.totalAmount.sub(userInfo.claimedAmount)) {
            claimAmount = userInfo.totalAmount.sub(userInfo.claimedAmount);
        }
        return claimAmount;
    }

    function claimToken(ListType _listType, uint256 _amount, bytes calldata _signature) external onlySigner(uint8(_listType), _amount, _signature) returns (uint256 claimAmount) {
        AirdropInfo storage userInfo;

        if (_listType == ListType.KolDonationList) {
            userInfo = kolDonationList[msg.sender];
        } else {
            return claimAmount;
        }

        if (userInfo.totalAmount == 0) {
            userInfo.totalAmount = _amount;
        }

        claimAmount = _claimAmount(msg.sender, _listType);
        require(claimAmount > 0, "Invalid claim amount");

        userInfo.t = block.timestamp;
        userInfo.claimedAmount = userInfo.claimedAmount.add(claimAmount);

        emit ClaimToken(msg.sender, claimAmount, _listType);

        require(airdropToken.balanceOf(address(this)) >= claimAmount, "Insufficient pool balance");
        airdropToken.safeTransfer(msg.sender, claimAmount);
    }

    function getClaimAmount(address _user, ListType _listType) public view returns (uint256 claimAmount) {
        claimAmount = _claimAmount(_user, _listType);
    }

    function transferToStake(ListType _listType, uint256 _amount, bytes calldata _signature) external onlySigner(uint8(_listType), _amount, _signature) returns (uint256 claimAmount) {
        require(address(port3Stake) != address(0), "Port3 Stake address is empty");

        AirdropInfo storage userInfo;
        if (_listType == ListType.KolDonationList) {
            userInfo = kolDonationList[msg.sender];
        } else {
            return claimAmount;
        }

        if (userInfo.totalAmount == 0) {
            userInfo.totalAmount = _amount;
        }

        claimAmount = _claimAmount(msg.sender, _listType);
        require(claimAmount > 0, "Invalid claim amount");

        userInfo.t = block.timestamp;
        userInfo.claimedAmount = userInfo.claimedAmount.add(claimAmount);

        emit ClaimToken(msg.sender, claimAmount, _listType);

        require(airdropToken.balanceOf(address(this)) >= claimAmount, "Insufficient pool balance");
        airdropToken.safeApprove(address(port3Stake), claimAmount);
        port3Stake.depositTo(port3StakePid, claimAmount, msg.sender);

    }

    // ========= Admin functions =========
    function withdraw(address _to, uint256 _amount) external onlyAdmin {
        require(airdropToken.balanceOf(address(this)) >= _amount, "Insufficient balance");
        airdropToken.safeTransfer(_to, _amount);
    }

    function setOwner(address _owner) external onlyAdmin {
        require(_owner != address(0), "Owner can't be zero address");
        owner = _owner;
    }

    function setManager(address _manager) external onlyAdmin {
        require(_manager != address(0), "Manager can't be zero address");
        manager = _manager;
    }

    function setPort3Stake(IPort3Stake _port3Stake, uint8 _port3StakePid) external onlyAdmin {
        port3Stake = _port3Stake;
        port3StakePid = _port3StakePid;
    }

    function setAirdropTime(uint256 _airdropTime) external onlyAdmin {
        airdropTime = _airdropTime;
    }

    function setKolDonationList(address[] memory _users, uint256[] memory _amounts) external onlyAdmin {
        require(_users.length == _amounts.length, "Parameter is wrong");

        for (uint256 i = 0; i < _users.length; i++) {
            AirdropInfo storage userInfo = kolDonationList[_users[i]];
            userInfo.totalAmount = _amounts[i];
        }
    }

    function GetInitializeData(address _owner, address _manager, address _airdropToken, uint256 _airdropTime) public pure returns(bytes memory){
        return abi.encodeWithSignature("initialize(address,address,address,uint256)", _owner,_manager,_airdropToken,_airdropTime);
    }
}
