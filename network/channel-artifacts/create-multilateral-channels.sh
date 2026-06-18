#!/bin/bash -e

cd /etc/hyperledger/configtx
export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/crypto/msp/users/Admin@masgsgsg.example.com/msp
export CORE_PEER_LOCALMSPID=masgsgsgMSP
export CORE_PEER_ADDRESS=peer0.masgsgsg.example.com:7051
export CORE_PEER_TLS_ENABLED=false

for channel_tx in funding-channel.tx netting-channel.tx; do
    channel_prefix="${channel_tx%%\-channel\.tx}"
    channel_name="${channel_prefix}channel"
    echo "Creating ${channel_name}..."
    peer channel create -o orderer.example.com:7050 -c "${channel_name}" -f "${channel_tx}"
    echo
done
