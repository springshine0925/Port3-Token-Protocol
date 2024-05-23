#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3StakePoolAdmin, Port3StakePoolUpgradeableProxy, Port3StakePool, Port3Vault, interface
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

    click.echo("部署Port3StakePool合约中...")

    reward_token = "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3
    port3Vault = Port3Vault.deploy(reward_token, {'from': gov})

    port3StakePool = Port3StakePool.deploy({'from': gov})
    port3StakePoolAdmin = Port3StakePoolAdmin.deploy({'from': gov})
    init_data = port3StakePool.GetInitializeData(gov.address, port3Vault)
    port3StakePoolProxy = Port3StakePoolUpgradeableProxy.deploy(port3StakePool.address, port3StakePoolAdmin.address, init_data, {'from': gov})
    port3StakePoolAdmin.upgrade(port3StakePoolProxy, port3StakePool.address, {'from': gov})

    click.echo(f"port3Vault: [{port3Vault.address}]")
    click.echo(f"port3StakePool: [{port3StakePool.address}]")
    click.echo(f"Port3StakePoolAdmin: [{port3StakePoolAdmin.address}]")
    click.echo(f"Port3StakePoolProxy: [{port3StakePoolProxy.address}]")

    click.echo("部署port3StakePool合约完成\n\n\n")

    # # # 合约更新
    # # value 0x8e4E73B8976F7c01aFc8f2CBb3c95ad3C548A7Cb
    # port3StakePoolAdmin = Port3StakePoolAdmin.at('0xa58bc3D96b25CFcA568BA58cecC2CcBCcfa47A8d')
    # port3StakePoolProxy = '0x41036096120B086e05A1572A029fb82835e9B3f4'

    # port3Vault: [0xc830Ad2FDfCC2f368fE5DeC93b1Dc72ecABb3691]
    # port3StakePool: [0xbc8eCccb89650c3E796e803CB009BF9b898CB359]
    # Port3StakePoolAdmin: [0x741e3E1f81041c62C2A97d0b6E567AcaB09A6232]
    # Port3StakePoolProxy: [0x4B0FccF53589c1F185B35db88bB315a0bBF9a3e0]

    # # gov = accounts.at('0x9f089F9f1e1874f0873b35Aa6883d6d8164d66C8', True)

    # port3StakePool = Port3StakePool.deploy({'from': gov})
    # port3StakePoolAdmin.upgrade(port3StakePoolProxy, port3StakePool.address, {'from': gov})

    # click.echo("升级port3StakePool合约完成\n\n\n")



