#!/bin/bash -e

cd /etc/hyperledger/configtx
export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/crypto/msp/users/Admin@bofasg2x.example.com/msp
export CORE_PEER_LOCALMSPID=bofasg2xMSP
export CORE_PEER_ADDRESS=peer0.bofasg2x.example.com:7051
export CORE_PEER_TLS_ENABLED=false

echo "Creating bofasg2xchassgsgchannel..."
peer channel create -o orderer.example.com:7050 -c bofasg2xchassgsgchannel -f bofasg2xchassgsg-channel.tx
echo
