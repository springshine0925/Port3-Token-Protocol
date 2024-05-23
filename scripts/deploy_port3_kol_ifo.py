#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3KolIFOAdmin, Port3KolIFOUpgradeableProxy, Port3KolIFO, interface
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

    click.echo("部署Port3KolIFO合约中...")

    p3_token = "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3

    port3IFO = Port3KolIFO.deploy({'from': gov})
    port3IFOAdmin = Port3KolIFOAdmin.deploy({'from': gov})

    manage = gov.address
    init_data = port3IFO.GetInitializeData(gov.address, manage)
    port3IFOProxy = Port3KolIFOUpgradeableProxy.deploy(port3IFO.address, port3IFOAdmin.address, init_data, {'from': gov})
    port3IFOAdmin.upgrade(port3IFOProxy, port3IFO.address, {'from': gov})

    click.echo(f"port3IFO: [{port3IFO.address}]")
    click.echo(f"Port3KolIFOAdmin: [{port3IFOAdmin.address}]")
    click.echo(f"Port3KolIFOProxy: [{port3IFOProxy.address}]")

    click.echo("部署port3IFO合约完成\n\n\n")

    # sepolia network
    # port3IFO: [0x493e37dA1D76635aa7ba44EaCfb90E369DaB2222]
    # Port3KolIFOAdmin: [0xa78C5bb7ef3BDba98091D27E8512A1775bd8c210]
    # Port3KolIFOProxy: [0x3E479e7D1D6412F2a74aee607548144a8f4D29F5]

    # bsc test network
    # port3IFO: [0x525Cb05Cc9E8e085542457c6Bba34833759929Ab]
    # Port3KolIFOAdmin: [0x9aE66b6434931e9388D1B79033CfB024b7Da8cDD]
    # Port3KolIFOProxy: [0xe84F31B8EC34Dc7CE13B1a1992839CFfd2A38204]

    # 合约更新
    # port3IFOAdmin = Port3KolIFOAdmin.at('0xa58bc3D96b25CFcA568BA58cecC2CcBCcfa47A8d')
    # port3IFOProxy = '0x41036096120B086e05A1572A029fb82835e9B3f4'

    # gov = accounts.at('0x9f089F9f1e1874f0873b35Aa6883d6d8164d66C8', True)

    # port3IFO = Port3KolIFO.deploy({'from': gov})
    # port3IFOAdmin.upgrade(port3IFOProxy, port3IFO.address, {'from': gov})

    # click.echo("升级port3IFO合约完成\n\n\n")



