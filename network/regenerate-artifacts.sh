#!/usr/bin/env bash
# Regenerate genesis + channel TX for Fabric 2.x lifecycle (single-VM 3-org).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

FABRIC_TOOLS="${FABRIC_TOOLS:-hyperledger/fabric-tools:2.5}"

run_configtxgen() {
    docker run --rm \
        -v "${SCRIPT_DIR}:/work" \
        -w /work \
        -e FABRIC_CFG_PATH=/work \
        "${FABRIC_TOOLS}" \
        sh -c 'cp configtx-single-vm.yaml configtx.yaml && configtxgen "$@"' -- "$@"
}

echo "Generating genesis.block..."
run_configtxgen -profile OrdererGenesis -channelID system-channel \
    -outputBlock channel-artifacts/genesis.block

for spec in \
    "fundingChannel:fundingchannel:funding-channel.tx" \
    "nettingChannel:nettingchannel:netting-channel.tx" \
    "bofasg2xchassgsgChannel:bofasg2xchassgsgchannel:bofasg2xchassgsg-channel.tx"
do
    profile="${spec%%:*}"
    rest="${spec#*:}"
    channel_id="${rest%%:*}"
    outfile="${rest##*:}"
    echo "Generating ${outfile} (profile ${profile}, channel ${channel_id})..."
    run_configtxgen -profile "${profile}" -channelID "${channel_id}" \
        -outputCreateChannelTx "channel-artifacts/${outfile}"
done

echo "Done. Redeploy the stack (start-single-vm.sh) to apply new genesis and channels."
