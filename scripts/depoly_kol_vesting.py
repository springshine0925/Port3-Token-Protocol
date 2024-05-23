#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, KOLVestingAdmin, KOLVestingUpgradeableProxy, KOLVesting, interface
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

    click.echo("部署KOLVesting合约中...")

    kolVesting = KOLVesting.deploy({'from': gov})
    kolVestingAdmin = KOLVestingAdmin.deploy({'from': gov})

    manager = "0xfE98DCA05A280d20CbB03d9B9936e2863Bcfe5b3" # 用来签名
    airdrop_time = 1704693600 # 2024-01-08 14:00 UTC+8
    airdrop_token = "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3
    init_data = kolVesting.GetInitializeData(gov.address, manager, airdrop_token, airdrop_time)

    kolVestingProxy = KOLVestingUpgradeableProxy.deploy(kolVesting.address, kolVestingAdmin.address, init_data, {'from': gov})
    kolVestingAdmin.upgrade(kolVestingProxy, kolVesting.address, {'from': gov})


    click.echo(f"kolVesting: [{kolVesting.address}]")
    click.echo(f"KOLVestingAdmin: [{kolVestingAdmin.address}]")
    click.echo(f"KOLVestingProxy: [{kolVestingProxy.address}]")

    click.echo("部署kolVesting合约完成\n\n\n")

    # 合约更新
    # kolVestingAdmin = KOLVestingAdmin.at('0x176d72FdF188119A375eACf01EC82605a5B3C0fF')
    # kolVestingProxy = '0x95dEB8F818f0f01805451fa6bf391B0F97B4d033'

    # kolVesting = KOLVesting.deploy({'from': gov})
    # kolVestingAdmin.upgrade(kolVestingProxy, kolVesting.address, {'from': gov})

    # click.echo("升级kolVesting合约完成\n\n\n")



