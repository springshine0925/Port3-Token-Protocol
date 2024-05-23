// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AirdropToken is ERC20, Ownable {
    uint256 public airdropAmount = 0;
    mapping(address => uint256) airdropClaimed;

    constructor(string memory _name, string memory _symbol, uint256 _total_supply) ERC20(_name, _symbol) {
        _mint(msg.sender, _total_supply);
    }

    function setAirdropAmount(uint256 _amount) external onlyOwner {
        airdropAmount = _amount;
    }

    function claimAirdrop() external returns (uint256 amount) {
        require(airdropAmount > 0, "Airdrop has ended");
        require(airdropClaimed[msg.sender] == 0, "Airdrop has been claimed");

        airdropClaimed[msg.sender] = airdropClaimed[msg.sender] + airdropAmount;
        _mint(msg.sender, airdropAmount);
    }
}
