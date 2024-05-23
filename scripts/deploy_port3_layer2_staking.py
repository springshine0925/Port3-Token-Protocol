#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3Layer2StakingAdmin, Port3Layer2StakingUpgradeableProxy, Port3Layer2Staking, Port3Vault, interface
from brownie.network import gas_price
from brownie.network.gas.strategies import LinearScalingStrategy

def main():
    fork_mode = False
    if click.confirm("正在 Fork 网运行?", default="N"):
        fork_mode = True

    if not click.confirm(f"当前网络 {network.show_active()}，是否确认在此网络部署？", default="Y"):
        return

    click.echo("提示：请确认部署参数是否已完成调整？")
    gas_price("auto")

    if fork_mode:
        gov = accounts[0]
    else:
        gov = accounts.load(click.prompt("Governance 管理员/部署者，请选择括号中待选的本地账号", type=click.Choice(accounts.load())))

    click.echo(f"正在使用: 'gov' [{gov.address}]")
    click.echo(f"当前账户 ETH 余额: {gov.balance()}")

    click.echo("正在部署Port3Layer2Staking...")

    reward_token = "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3
    port3Vault = Port3Vault.deploy(reward_token, {'from': gov})

    port3Layer2Staking = Port3Layer2Staking.deploy({'from': gov})
    port3Layer2StakingAdmin = Port3Layer2StakingAdmin.deploy({'from': gov})
    init_data = port3Layer2Staking.GetInitializeData(gov.address, port3Vault)
    port3Layer2StakingProxy = Port3Layer2StakingUpgradeableProxy.deploy(port3Layer2Staking.address, port3Layer2StakingAdmin.address, init_data, {'from': gov})
    port3Layer2StakingAdmin.upgrade(port3Layer2StakingProxy, port3Layer2Staking.address, {'from': gov})

    click.echo(f"port3Vault: [{port3Vault.address}]")
    click.echo(f"port3Layer2Staking: [{port3Layer2Staking.address}]")
    click.echo(f"Port3Layer2StakingAdmin: [{port3Layer2StakingAdmin.address}]")
    click.echo(f"Port3Layer2StakingProxy: [{port3Layer2StakingProxy.address}]")

    click.echo("部署port3Layer2Staking合约完成\n\n\n")

    # # 合约更新
    #port3Layer2StakingAdmin = Port3Layer2StakingAdmin.at('0xa58bc3D96b25CFcA568BA58cecC2CcBCcfa47A8d')
    #port3Layer2StakingProxy = '0x41036096120B086e05A1572A029fb82835e9B3f4'

    ##gov = accounts.at('0x9f089F9f1e1874f0873b35Aa6883d6d8164d66C8', True)

    #port3Layer2Staking = Port3Layer2Staking.deploy({'from': gov})
    #port3Layer2StakingAdmin.upgrade(port3Layer2StakingProxy, port3Layer2Staking.address, {'from': gov})

    #click.echo("升级port3Layer2Staking合约完成\n\n\n")




