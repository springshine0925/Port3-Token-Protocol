#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3AirdropAdmin, Port3AirdropUpgradeableProxy, Port3Airdrop, AirdropToken, interface
from brownie.network import gas_price
from brownie.network.gas.strategies import LinearScalingStrategy

def main():
    fork_mode = False
    if click.confirm("正在 Fork 网运行?", default="N"):
        fork_mode = True

    if not click.confirm(f"当前网络 {network.show_active()}，是否确认在此网络测试？", default="Y"):
        return

    gas_price("auto")
    if fork_mode:
        gov = accounts[0]
    else:
        gov = accounts.load(click.prompt("Governance 管理员/部署者，请选择括号中待选的本地账号", type=click.Choice(accounts.load())))

    airdrop = Port3Airdrop.at('0x95dEB8F818f0f01805451fa6bf391B0F97B4d033')
    p3_token = AirdropToken.at("0xb4357054c3dA8D46eD642383F03139aC7f090343")
    #p3_account = accounts.at('0xA75b66dC806AA1EeddC28Bd92c476769c118caED', True)
    #p3_token.transfer(airdrop.address, 1000 * (10 ** 18), {'from': p3_account})

    addresses = [
            "0x2265be90C2bd8F6dd34dbAB1355756555080caC1",
            ]
    amount_list = [
            0 * (10 ** 18),
            ]

    airdrop.setAirdropList(addresses, amount_list, {'from': gov})
    #airdrop.setInvestorList(addresses, amount_list, {'from': gov})

