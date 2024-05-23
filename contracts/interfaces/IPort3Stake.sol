// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPort3Stake {
    function depositTo(uint256 _pid, uint256 _amount, address _to) external;
}
