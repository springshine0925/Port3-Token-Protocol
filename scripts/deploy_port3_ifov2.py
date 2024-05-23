#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3IFOV2Admin, Port3IFOV2UpgradeableProxy, Port3IFOV2, interface
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

     # click.echo("Deploying Port3IFOV2 contract...")

     # p3_token = "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3

     # port3IFO = Port3IFOV2.deploy({'from': gov})
     # port3IFOAdmin = Port3IFOV2Admin.deploy({'from': gov})

     # manage = gov.address
     # init_data = port3IFO.GetInitializeData(gov.address, manage)
     # port3IFOProxy = Port3IFOV2UpgradeableProxy.deploy(port3IFO.address, port3IFOAdmin.address, init_data, {'from': gov})
     # port3IFOAdmin.upgrade(port3IFOProxy, port3IFO.address, {'from': gov})

     # click.echo(f"port3IFO: [{port3IFO.address}]")
     # click.echo(f"Port3IFOV2Admin: [{port3IFOAdmin.address}]")
     # click.echo(f"Port3IFOV2Proxy: [{port3IFOProxy.address}]")

     # click.echo("Deployment of port3IFO contract completed\n\n\n")

     # fork
     # port3IFO: [0xBcb61491F1859f53438918F1A5aFCA542Af9D397]
     # Port3IFOV2Admin: [0xD22363efee93190f82b52FCD62B7Dbcb920eF658]
     # Port3IFOV2Proxy: [0x4D1B781ce59B8C184F63B99D39d6719A522f46B5]

     #Contract update
     port3IFOAdmin = Port3IFOV2Admin.at('0xD22363efee93190f82b52FCD62B7Dbcb920eF658')
     port3IFOProxy = '0x4D1B781ce59B8C184F63B99D39d6719A522f46B5'

     port3IFO = Port3IFOV2.deploy({'from': gov})
     port3IFOAdmin.upgrade(port3IFOProxy, port3IFO.address, {'from': gov})

     click.echo("Upgrade port3IFO contract completed\n\n\n")