### Port3Airdrop Doc
### Port3AirdropProxy: [0x4D1B781ce59B8C184F63B99D39d6719A522f46B5]

##### Airdrop user data
```
contract.airdropList(address _user)

return [
     uint256; #Last collection time
     uint256; # Total amount of airdrop
     uint256; # Amount received
]
```

##### Invest in user data
```
contract.investorList(address_user)

return [
     uint256; #Last collection time
     uint256; # Total amount of airdrop
     uint256; # Amount received
]
```

##### KOL investment user data
```
contract.kolDonationList(address _user)

return [
     uint256; #Last collection time
     uint256; # Total amount of airdrop
     uint256; # Amount received
]
```

#### Get the amount of tokens that can be claimed at the current time
```
contract.getClaimAmount(address _user, ListType _listType) # _listType: <0: Airdrop wallet; 1: Investment wallet>

return uint256 # Amount that can be claimed
```

#### User claims tokens (CALL)
```
contract.claimToken(ListType _listType, uint256 _amount, bytes _signature) # _listType: <0: airdrop wallet; 1: investment wallet>
```

#### The tokens released by users are directly pledged to the contract (CALL)
```
contract.transferToStake(ListType _listType, uint256 _amount, bytes _signature) # _listType: <0: airdrop wallet; 1: investment wallet>
```

### Port3StakePool Doc
### port3Value: [0x654f70d8442EA18904FA1AD79114f7250F7E9336]
### Port3StakePoolProxy: [0xA95916C3D979400C7443961330b3092510a229Ba]

#### Pledge pool data
```
contract.poolInfo(uint8 _pid) # This _pid needs to be placed in the front-end configuration file: [{pid: 0, "pool_name": "xxx"...}]

return [
     address; // Token Contract
     uint256; // Amount of token in pool.
     uint256; // lock time
     uint256; // Unlock period (not needed for now)
     uint256; //Daily reward
     uint256; //Reward distribution start time
     uint256; //Reward distribution end time
     bool; // Whether to enable reward distribution
     bool; // Whether the reward is ETH (no need to use it yet)
     bool; // Whether to enable emergency extraction (no need to use it yet)
]

```

#### User pledge data
```
contract.userInfo(uint8 _pid, address _user)

return [
     uint256; // Pledge amount
     uint256; // Receive amount
     uint256; // Pledge time
     uint256; // Collection time
]
```

#### The user’s current reward token amount
```
contract.pendingTokenReward(uint8 _pid, address _user)

return uint256
```

#### User pledged tokens (CALL)
```
contract.deposit(uint8 _pid, uint256 _amount)
```

#### Check whether the user can withdraw the pledge
```
contract.canWithdraw(address _user, uint8 _pid, uint256 _amount)

return uint8; # <0: Available for withdrawal; 1: Frozen; 2: Insufficient balance>
```

#### User withdraws pledge (CALL)
```
contract.withdraw(uint8 _pid, uint256 _amount)
```

#### Users receive rewards (CALL)
```
contract.harvest(uint8 _pid, address _user)
```

#### The amount of reward tokens produced per second
```
contract.tokenRewardPerSecondForPool(uint8 _pid)

return uint256;
```

### Port3IFO Doc

#### IFO Pool
```
contract.poolInfo(uint8 _pid)
return [
     IERC20; // Raise tokens;
     IERC20; // Token sale;
     uint256; // ifo start time;
     uint256; // ifo end time;
     uint256; // ifo collection time;
     uint256; // Minimum pledge to raise tokens;
     uint256; // Maximum pledge to raise tokens;
     uint256; // Total tokens raised;
     uint256; //Total tokens for sale;
     uint256; // Raised coins;
     bool; // Whether it is excessive fundraising;
]

```

#### Number of participating users
```
contract.getAddressListLength(uint8 _pid)
return uint256

```

#### User participation information
```
contract.userInfo(uint8 _pid, address _user)
return [
     uint256; //Amount raised;
     uint256; //Last collection time;
     bool; // Whether to receive;
]

```

#### User pledge
```
contract.deposit(uint8 _pid, uint256 _amount, bytes _signature)
Note: 
     ((_amount + user.amount) < pool.maxAmount and (_amount >= pool.minAmount))
     If pool.isBeyond == False, it is non-over-raising mode, and the current
     if (pool.isBeyond == False) { // It is non-over-funding mode
         if (pool.totalAmount + _amount >= pool.raisingAmount) {
             # Staking is no longer allowed
         }
     }

```

#### Check whether the user has received it
```
contract.isClaimed(uint8 _pid, address _user)
```

#### Users receive
```
contract.claim(uint8 _pid)
```