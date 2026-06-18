#!/bin/bash -e

cd /etc/hyperledger/configtx
exec "$(dirname "$0")/create-multilateral-channels.sh"
