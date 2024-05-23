#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3IFOAdmin, Port3IFOUUpgradeableProxy, Port3IFO, interface
from brownie.network import gas_price
from brownie.network.gas.strategies import LinearScalingStrategy

def main():
     fork_mode = False
     if click.confirm("Running on Fork network?", default="N"):
         fork_mode = True

     if not click.confirm(f"Current network {network.show_active()}, do you want to confirm deployment on this network?", default="Y"):
         return

     click.echo("Tip: Please confirm whether the deployment parameters have been adjusted?")
     gas_price("auto")

     if fork_mode:
         gov = accounts[0]
     else:
         gov = accounts.load(click.prompt("Governance administrator/deployer, please select the local account to be selected in brackets", type=click.Choice(accounts.load())))

     click.echo(f"Using: 'gov' [{gov.address}]")
     click.echo(f"Current account ETH balance: {gov.balance()}")

     click.echo("Deploying Port3IFO contract...")

     p3_token = "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3

     port3IFO = Port3IFO.deploy({'from': gov})
     port3IFOAdmin = Port3IFOAdmin.deploy({'from': gov})

     manage = gov.address
     init_data = port3IFO.GetInitializeData(gov.address, manage)
     port3IFOProxy = Port3IFOUUpgradeableProxy.deploy(port3IFO.address, port3IFOAdmin.address, init_data, {'from': gov})
     port3IFOAdmin.upgrade(port3IFOProxy, port3IFO.address, {'from': gov})

     click.echo(f"port3IFO: [{port3IFO.address}]")
     click.echo(f"Port3IFOAdmin: [{port3IFOAdmin.address}]")
     click.echo(f"Port3IFOProxy: [{port3IFOProxy.address}]")

     click.echo("Deployment of port3IFO contract completed\n\n\n")

     #sepolianetwork
     # port3IFO: [0x493e37dA1D76635aa7ba44EaCfb90E369DaB2222]
     # Port3IFOAdmin: [0xa78C5bb7ef3BDba98091D27E8512A1775bd8c210]
     # Port3IFOProxy: [0x3E479e7D1D6412F2a74aee607548144a8f4D29F5]

     # bsc test network
     # port3IFO: [0x525Cb05Cc9E8e085542457c6Bba34833759929Ab]
     # Port3IFOAdmin: [0x9aE66b6434931e9388D1B79033CfB024b7Da8cDD]
     # Port3IFOProxy: [0xe84F31B8EC34Dc7CE13B1a1992839CFfd2A38204]

     #Contract update
     # port3IFOAdmin = Port3IFOAdmin.at('0xa58bc3D96b25CFcA568BA58cecC2CcBCcfa47A8d')
     # port3IFOProxy = '0x41036096120B086e05A1572A029fb82835e9B3f4'

     # gov = accounts.at('0x9f089F9f1e1874f0873b35Aa6883d6d8164d66C8', True)

     # port3IFO = Port3IFO.deploy({'from': gov})
     # port3IFOAdmin.upgrade(port3IFOProxy, port3IFO.address, {'from': gov})

     # click.echo("Upgrade port3IFO contract completed\n\n\n")