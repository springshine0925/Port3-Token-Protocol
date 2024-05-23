#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3StakePoolV2Admin, Port3StakePoolV2UpgradeableProxy, Port3StakePoolV2, Port3Vault, interface
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

    # click.echo("部署Port3StakePoolV2合约中...")

    # reward_token = "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3
    # port3Vault = Port3Vault.deploy(reward_token, {'from': gov})

    # port3StakePool = Port3StakePoolV2.deploy({'from': gov})
    # port3StakePoolAdmin = Port3StakePoolV2Admin.deploy({'from': gov})

    # destroy_token_rate = int(0.3 * (10 ** 6))
    # init_data = port3StakePool.GetInitializeData(gov.address, port3Vault, destroy_token_rate)
    # port3StakePoolProxy = Port3StakePoolV2UpgradeableProxy.deploy(
    #         port3StakePool.address,
    #         port3StakePoolAdmin.address,
    #         init_data, {'from': gov})
    # port3StakePoolAdmin.upgrade(port3StakePoolProxy, port3StakePool.address, {'from': gov})

    # click.echo(f"port3Vault: [{port3Vault.address}]")
    # click.echo(f"port3StakePool: [{port3StakePool.address}]")
    # click.echo(f"Port3StakePoolV2Admin: [{port3StakePoolAdmin.address}]")
    # click.echo(f"Port3StakePoolV2Proxy: [{port3StakePoolProxy.address}]")

    # click.echo("部署port3StakePool合约完成\n\n\n")

    # # 合约更新
    # port3Vault: [0xA95916C3D979400C7443961330b3092510a229Ba]
    # port3StakePool: [0x42E8D004c84E6B5Bad559D3b5CE7947AADb9E0bc]
    # Port3StakePoolV2Admin: [0xF06D5f5BfFFCB6a52c84cfebc03AD35637728E73]
    # Port3StakePoolV2Proxy: [0x82c83b7f88aef2eD99d4869D547b6ED28e69C8df]

    port3StakePoolAdmin = Port3StakePoolV2Admin.at('0xF06D5f5BfFFCB6a52c84cfebc03AD35637728E73')
    port3StakePoolProxy = '0x82c83b7f88aef2eD99d4869D547b6ED28e69C8df'

    port3StakePool = Port3StakePoolV2.deploy({'from': gov})
    port3StakePoolAdmin.upgrade(port3StakePoolProxy, port3StakePool.address, {'from': gov})

    click.echo("升级port3StakePool合约完成\n\n\n")



