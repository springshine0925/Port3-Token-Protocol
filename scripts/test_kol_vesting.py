#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3AirdropAdmin, Port3AirdropUpgradeableProxy, Port3Airdrop, AirdropToken, interface
from brownie.network import gas_price
from brownie.network.gas.strategies import LinearScalingStrategy

def main():
     fork_mode = False
     if click.confirm("Running on Fork network?", default="N"):
         fork_mode = True

     if not click.confirm(f"Current network {network.show_active()}, do you want to confirm testing on this network?", default="Y"):
         return

     gas_price("auto")
     if fork_mode:
         gov = accounts[0]
     else:
         gov = accounts.load(click.prompt("Governance administrator/deployer, please select the local account to be selected in brackets", type=click.Choice(accounts.load())))

     airdrop = Port3Airdrop.at('0xBb37F0CbAd70dAa697605F9828A44F2073ED38b3')
     p3_token = AirdropToken.at("0xb4357054c3dA8D46eD642383F03139aC7f090343")

     addresses = [
             "0x660e3dAEd6B12C07a2F94831b26F7f57D1999297",
             "0xc2Ad644D5B252B64A89B8B2EE95CdEC47980045A",
             "0xeC56f708097287cc8F545A485B02E1cB756d8131",
             "0x138a1Bff82561c4797378d11CDa887107EDed006",
             "0xd3a1AD4f432bda630dC4D7C48D0A13c1bCabDb91",
             "0xE6901A12ECBA1f95a69b2a46D0B2DF786D20aD5d",
             "0xfE95c8Ac4ce2870c56a010118CB660990D7decE7",
             "0x10530C770e507B2223695a7b205eD85132AFB24d",
             ]
     amount_list = [
             52288 * (10 ** 18),
             39216 * (10 ** 18),
             32680 * (10 ** 18),
             26144 * (10 ** 18),
             24510 * (10 ** 18),
             24510 * (10 ** 18),
             22876 * (10 ** 18),
             6536 * (10 ** 18)
             ]

     airdrop.setKolDonationList(addresses, amount_list, {'from': gov})