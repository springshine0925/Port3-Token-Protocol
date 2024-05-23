#!/usr/bin/python
# -*- coding: utf-8 -*-
import click
from brownie import accounts, network, Port3AirdropAdmin, Port3AirdropUpgradeableProxy, Port3Airdrop, interface
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

     click.echo("Deploying Port3Airdrop contract...")

     # Investor: 0x7ce7B45e2F7b7a1bB780f09e590E91C3f10D9AEE

     # port3Airdrop = Port3Airdrop.deploy({'from': gov})
     # port3AirdropAdmin = Port3AirdropAdmin.deploy({'from': gov})

     # manager = "0xfE98DCA05A280d20CbB03d9B9936e2863Bcfe5b3" # Used for signing
     # airdrop_time = 1704693600 # 2024-01-08 14:00 UTC+8
     # airdrop_token = "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3
     # init_data = port3Airdrop.GetInitializeData(gov.address, manager, airdrop_token, airdrop_time)

     # port3AirdropProxy = Port3AirdropUpgradeableProxy.deploy(port3Airdrop.address, port3AirdropAdmin.address, init_data, {'from': gov})
     # port3AirdropAdmin.upgrade(port3AirdropProxy, port3Airdrop.address, {'from': gov})


     # click.echo(f"port3Airdrop: [{port3Airdrop.address}]")
     # click.echo(f"Port3AirdropAdmin: [{port3AirdropAdmin.address}]")
     # click.echo(f"Port3AirdropProxy: [{port3AirdropProxy.address}]")

     # click.echo("Deployment of port3Airdrop contract completed\n\n\n")

     #Contract update
     gov = accounts.at('0x9f089F9f1e1874f0873b35Aa6883d6d8164d66C8', True)
     port3AirdropAdmin = Port3AirdropAdmin.at('0x176d72FdF188119A375eACf01EC82605a5B3C0fF')
     port3AirdropProxy = '0x95dEB8F818f0f01805451fa6bf391B0F97B4d033'

     port3Airdrop = Port3Airdrop.deploy({'from': gov})
     port3AirdropAdmin.upgrade(port3AirdropProxy, port3Airdrop.address, {'from': gov})

     click.echo("Upgrade port3Airdrop contract completed\n\n\n")