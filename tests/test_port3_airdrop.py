#!/usr/bin/python
# -*- coding: utf-8 -*-

import pytest
from brownie import accounts, network, Port3AirdropAdmin, Port3AirdropUpgradeableProxy, Port3Airdrop, interface

def owner():
    return accounts[2]

def p3_token():
    return "0xb4357054c3dA8D46eD642383F03139aC7f090343" # P3

def test_deploy():
    gov = owner()
    port3Airdrop = Port3Airdrop.deploy({'from': gov})
