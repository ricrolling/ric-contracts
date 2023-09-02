#!/bin/sh
set -ex

# Usage: ./request.sh <name> <chain_id>

ACC=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
CONTRACT=0x5fbdb2315678afecb367f032d93f642f64180aa3
NAME=$1
CHAIN_ID=$2

cast rpc anvil_setBalance $ACC 0x1000000000
cast rpc anvil_impersonateAccount $ACC
cast rpc eth_getBalance $ACC "latest"
cast rpc anvil_setNextBlockBaseFeePerGas 0
cast send --rpc-url http://localhost:8545 --from $ACC --unlocked $CONTRACT \
  --gas-limit 500000 --gas-price 50 \
  'requestRollup(string memory,uint256,bytes memory)' $NAME $CHAIN_ID 0xb5e2d8b323ec08fcd39b20cbc2090b52c07fecbc
