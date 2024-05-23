### Port3Airdrop Doc
### Port3AirdropProxy: [0x4D1B781ce59B8C184F63B99D39d6719A522f46B5]

##### 空投用户数据
```
contract.airdropList(address _user)

return [
    uint256; # 最后领取时间
    uint256; # 空投总金额
    uint256; # 已领取金额
]
```

##### 投资用户数据
```
contract.investorList(address _user)

return [
    uint256; # 最后领取时间
    uint256; # 空投总金额
    uint256; # 已领取金额
]
```

##### KOL投资用户数据
```
contract.kolDonationList(address _user)

return [
    uint256; # 最后领取时间
    uint256; # 空投总金额
    uint256; # 已领取金额
]
```

#### 获取当前时间可认领的代币数额
```
contract.getClaimAmount(address _user, ListType _listType) # _listType: <0: 空投钱包; 1: 投资钱包>

return uint256 # 可认领金额
```

#### 用户认领代币 (CALL)
```
contract.claimToken(ListType _listType, uint256 _amount, bytes _signature) # _listType: <0: 空投钱包; 1: 投资钱包>
```

#### 用户释放出的代币直接专质押合约 (CALL)
```
contract.transferToStake(ListType _listType, uint256 _amount, bytes _signature) # _listType: <0: 空投钱包; 1: 投资钱包>
```

### Port3StakePool Doc
### port3Value: [0x654f70d8442EA18904FA1AD79114f7250F7E9336]
### Port3StakePoolProxy: [0xA95916C3D979400C7443961330b3092510a229Ba]

#### 质押池子数据
```
contract.poolInfo(uint8 _pid) # 这个_pid需要放到前端配置文件: [{pid: 0, "pool_name": "xxx"...}]

return [
    address;                 // Token Contract
    uint256;                 // Amount of token in pool.
    uint256;                 // 锁定时间
    uint256;                 // 解锁期限 (暂时无需用到)
    uint256;                 // 每日奖励
    uint256;                 // 奖励派发开始时间
    uint256;                 // 奖励派发结束时间
    bool;                    // 是否开启奖励派发
    bool;                    // 奖励是否为ETH (暂时无需用到)
    bool;                    // 是否开启紧急提取 (暂时无需用到)
]

```

#### 用户质押数据
```
contract.userInfo(uint8 _pid, address _user)

return [
    uint256;         // 质押金额
    uint256;         // 领取金额
    uint256;         // 质押时间
    uint256;         // 领取时间
]
```

#### 用户当前奖励代币数额
```
contract.pendingTokenReward(uint8 _pid, address _user)

return uint256
```

#### 用户质押代币 (CALL)
```
contract.deposit(uint8 _pid, uint256 _amount)
```

#### 检测用户是否可以提取质押
```
contract.canWithdraw(address _user, uint8 _pid, uint256 _amount)

return uint8; # <0: 可以提现; 1: 冻结中; 2: 余额不足>
```

#### 用户提取质押 (CALL)
```
contract.withdraw(uint8 _pid, uint256 _amount)
```

#### 用户领取奖励 (CALL)
```
contract.harvest(uint8 _pid, address _user)
```

#### 每秒产出奖励代币数额
```
contract.tokenRewardPerSecondForPool(uint8 _pid)

return uint256;
```

### Port3IFO Doc

#### IFO 池子
```
contract.poolInfo(uint8 _pid)
return [
    IERC20; // 募集代币;
    IERC20; // 发售代币;
    uint256; // ifo 开始时间;
    uint256; // ifo 结束时间;
    uint256; // ifo 领取时间;
    uint256; // 最小质押募集代币;
    uint256; // 最大质押募集代币;
    uint256; // 募集总代币;
    uint256; // 发售总代币;
    uint256; // 已募集的打币;
    bool; // 是否为超额募资;
]

```

#### 参与用户数
```
contract.getAddressListLength(uint8 _pid)
return uint256

```

#### 用户参与信息
```
contract.userInfo(uint8 _pid, address _user)
return [
    uint256; // 参与募集金额;
    uint256; // 最后募集时间;
    bool; // 是否领取;
]

```

#### 用户质押
```
contract.deposit(uint8 _pid, uint256 _amount, bytes _signature)
注: 
    ((_amount + user.amount) < pool.maxAmount and (_amount >= pool.minAmount))
    如果pool.isBeyond == False 则为非超募模式，则要判断当前
    if (pool.isBeyond == False) { // 为非超募模式
        if (pool.totalAmount + _amount >= pool.raisingAmount) {
            # 不允许进行质押了
        }
    }

```

#### 检测用户是否已经领取
```
contract.isClaimed(uint8 _pid, address _user)
```

#### 用户领取
```
contract.claim(uint8 _pid)
```
