#!/bin/bash -e

# 2-org network: only multilateral channels (matches docker-compose.yaml).
cd /etc/hyperledger/configtx
CHANNEL_TXS=( funding-channel.tx netting-channel.tx )

for channel_tx in "${CHANNEL_TXS[@]}"
do
    channel_prefix="${channel_tx%%\-channel\.tx}"
    channel_name="${channel_prefix}channel"
    echo "Creating $channel_name..."
    peer channel create -o orderer.example.com:7050 -c "$channel_name" -f "$channel_tx"
    echo
done
echo "Channel creation completed..."
