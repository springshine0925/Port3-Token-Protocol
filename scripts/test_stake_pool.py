#!/usr/bin/python
# -*- coding: utf-8 -*-

import click
from brownie import accounts, network, Port3StakePoolAdmin, Port3StakePoolUpgradeableProxy, Port3StakePool, Port3Vault, AirdropToken, interface
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

     stake = Port3StakePool.at('0x41036096120B086e05A1572A029fb82835e9B3f4')
     p3_vault = Port3Vault.at('0x8e4E73B8976F7c01aFc8f2CBb3c95ad3C548A7Cb')
     p3_token = AirdropToken.at(p3_vault.token())

     # fork simulated account
     #gov = accounts.at(stake.owner(), True)
     #p3_account = accounts.at('0xA75b66dC806AA1EeddC28Bd92c476769c118caED', True)
     p3_account = gov

     #Authorization
     p3_vault.grantRole(p3_vault.DEPOSIT_ROLE(), p3_account.address, {'from': gov})
     p3_vault.grantRole(p3_vault.TRANSFER_ROLE(), stake.address, {'from': gov})

     # Pledge reward tokens to enter
     p3_token.approve(p3_vault.address, p3_token.balanceOf(p3_account), {'from': p3_account})
     p3_vault.deposit(50000 * (10 ** 18), {'from': p3_account})

     #Add pool
     pid = 0
     try:
         stake.poolInfo(pid)
     except Exception as e:
         stake.addPool(p3_vault.token(), {'from': gov})

     # Set pool configuration
     daily_reward = '1000 ether'
     is_reward_eth = False
     is_open_reward = True

     lock_period = 3 * 86400
     unlock_period = 0

     start_time = 1704700500
     end_time = 1704700500 + (86400 * 365 * 2)
     stake.setPoolReward(pid, daily_reward, is_open_reward, is_reward_eth, start_time, end_time, {'from': gov})
     stake.setPoolLockTime(pid, lock_period, unlock_period, {'from': gov})

     # deposit_account = accounts[1]
     # deposit_account2 = accounts[2]

     # p3_token.transfer(deposit_account, 1000 * (10 ** 18), {'from': p3_account})
     # p3_token.approve(stake, p3_token.balanceOf(deposit_account), {'from': deposit_account})
     # stake.deposit(0, 500 * (10 ** 18), {'from': deposit_account})

     # p3_token.transfer(deposit_account2, 1000 * (10 ** 18), {'from': p3_account})
     # p3_token.approve(stake, p3_token.balanceOf(deposit_account2), {'from': deposit_account2})
     # stake.depositTo(0, 500 * (10 ** 18), deposit_account, {'from': deposit_account2})

     res = stake.poolInfo(pid)

     click.echo(f"lpToken: [{res[0]}]")
     click.echo(f"amount: [{res[1]/(10 ** 18)}]")
     click.echo(f"lockPeriod: [{res[2]}]")
     click.echo(f"unlockPeriod: [{res[3]}]")
     click.echo(f"tokenPerDaily: [{res[4]/(10 ** 18)}]")
     click.echo(f"startTime: [{res[5]}]")
     click.echo(f"endTime: [{res[6]}]\n\n\n")

     # res = stake.userInfo(pid, deposit_account)
     # click.echo(f"amount: [{res[0]/(10 ** 18)}]")
     # click.echo(f"rewardClaimed: [{res[1]/(10 ** 18)}]")
     # click.echo(f"depositTime: [{res[2]}]")
     # click.echo(f"lastHarvestTime: [{res[3]}]")