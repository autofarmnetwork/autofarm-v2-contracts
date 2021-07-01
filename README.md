# System Description

Autofarm is a Decentralized Application (DApp) running on Binance Smart Chain (BSC), Huobi ECO Chain (HECO) & Polygon (previously Matic network). AUTO is Binance-listed and has gone through several rounds of auditing by CertiK and SlowMist.


# Code

## AUTOv2 Token
Upgraded version of the AUTO token was committed on 22nd January 2021.

## Timelock
Timelock contract of all function calls set to 24 hours & functions that interact with the main contract and/or vaults that do not require a timelock include:

add() — Add a new pool with 0 AUTO allocation.  
set() — Increase/decrease AUTO Allocation (12h timelock). 
earn()  
farm()  
pause()  
unpause()

## Rewards Distributor

Code is used for the distribution of AUTOv2 tokens on non-BSC chains (do not have direct AUTOv2 emissions).

## AutoFarmV2

Main Autofarm contract which handles AUTO emissions and all deposits and withdrawals.

## AutoSwap

DEX Aggregator function of Autofarm ecosystem.
