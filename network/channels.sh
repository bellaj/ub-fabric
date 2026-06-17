#!/usr/bin/env bash
# MAS + 2 banks: funding, netting, and BOFA–CHASSGSG bilateral channel.
set -euo pipefail

REGULATOR=masgsgsg
BANKS=( bofasg2x chassgsg )
BILATERAL=bofasg2xchassgsgchannel
MULTILATERAL=( fundingchannel nettingchannel )
CHANNEL_SCRIPT_DIR=/etc/hyperledger/configtx

find_peer_container() {
    docker ps --format '{{.ID}} {{.Names}}' | grep "peer0-${1}" | head -1 | awk '{print $1}'
}

mas_container="$(find_peer_container "${REGULATOR}")"
bofa_container="$(find_peer_container "bofasg2x")"
chase_container="$(find_peer_container "chassgsg")"

echo
echo "---------- peer containers ----------"
echo " MAS      : ${mas_container:-not found}"
echo " BOFA     : ${bofa_container:-not found}"
echo " CHASSGSG : ${chase_container:-not found}"
echo "-------------------------------------"
echo

if [ -z "${mas_container}" ]; then
    echo "MAS peer container not running."
    exit 1
fi

echo "Creating channels on MAS peer..."
docker exec "${mas_container}" bash "${CHANNEL_SCRIPT_DIR}/create-channel.sh"
echo

echo "Joining MAS to ${MULTILATERAL[*]}..."
docker exec "${mas_container}" bash "${CHANNEL_SCRIPT_DIR}/join-channel.sh" \
    "${REGULATOR}" "${MULTILATERAL[@]}"

if [ -n "${bofa_container}" ]; then
    echo "Joining BOFA to ${BILATERAL} ${MULTILATERAL[1]}..."
    docker exec "${bofa_container}" bash "${CHANNEL_SCRIPT_DIR}/join-channel.sh" \
        bofasg2x "${BILATERAL}" "${MULTILATERAL[1]}"
fi

if [ -n "${chase_container}" ]; then
    echo "Joining CHASSGSG to ${BILATERAL} ${MULTILATERAL[1]}..."
    docker exec "${chase_container}" bash "${CHANNEL_SCRIPT_DIR}/join-channel.sh" \
        chassgsg "${BILATERAL}" "${MULTILATERAL[1]}"
fi

echo "Channel setup complete."
