#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3BridgeAdmin, Port3BridgeUpgradeableProxy, Port3Bridge, interface
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

     # click.echo("Deploying Port3Bridge contract...")

     # port3Bridge = Port3Bridge.deploy({'from': gov})
     # port3BridgeAdmin = Port3BridgeAdmin.deploy({'from': gov})

     # max_amount = '100000 ether'
     # gas_receiver = gov.address

     # init_data = port3Bridge.GetInitializeData(gov.address, gas_receiver, max_amount)
     # port3BridgeProxy = Port3BridgeUpgradeableProxy.deploy(port3Bridge.address, port3BridgeAdmin.address, init_data, {'from': gov})
     # port3BridgeAdmin.upgrade(port3BridgeProxy, port3Bridge.address, {'from': gov})

     # click.echo(f"port3Bridge: [{port3Bridge.address}]")
     # click.echo(f"Port3BridgeAdmin: [{port3BridgeAdmin.address}]")
     # click.echo(f"Port3BridgeProxy: [{port3BridgeProxy.address}]")

     # click.echo("Deployment of port3Bridge contract completed\n\n\n")

     #Contract update
     #polygon
     # port3Bridge: [0x05E517827562dCF0EA82fc78c8a18Da4f94b028B]
     # Port3BridgeAdmin: [0xe83CDE9f2D447895F9A2B047BECF7de6F51DEA3A]
     # Port3BridgeProxy: [0xC867b2f4eD4Afd066850fB63A4BF70835FE8D8AC]

     port3BridgeAdmin = Port3BridgeAdmin.at('0xe83CDE9f2D447895F9A2B047BECF7de6F51DEA3A')
     port3BridgeProxy = '0xC867b2f4eD4Afd066850fB63A4BF70835FE8D8AC'

     port3Bridge = Port3Bridge.deploy({'from': gov})
     port3BridgeAdmin.upgrade(port3BridgeProxy, port3Bridge.address, {'from': gov})

     click.echo("Upgrade port3Bridge contract completed\n\n\n")