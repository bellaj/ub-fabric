#!/usr/bin/env bash
# Create and join channels for the 2-org network (MAS + BOFA).
set -euo pipefail

REGULATOR=masgsgsg
BANK=bofasg2x
MULTILATERAL_CHANNELS=( fundingchannel nettingchannel )
CHANNEL_SCRIPT_DIR=/etc/hyperledger/configtx

find_peer_container() {
    docker ps --format '{{.ID}} {{.Names}}' | grep "peer0-${1}" | head -1 | awk '{print $1}'
}

mas_container="$(find_peer_container "${REGULATOR}")"
bofa_container="$(find_peer_container "${BANK}")"

echo
echo "---------- 2-org peer containers ----------"
echo " MAS (${REGULATOR}) : ${mas_container:-not found}"
echo " BOFA (${BANK})     : ${bofa_container:-not found}"
echo "-------------------------------------------"
echo

if [ -z "${mas_container}" ]; then
    echo "MAS peer container not running."
    exit 1
fi

echo "Creating multilateral channels on MAS peer..."
docker exec "${mas_container}" bash "${CHANNEL_SCRIPT_DIR}/create-channel.sh"
echo

echo "Joining MAS to ${MULTILATERAL_CHANNELS[*]}..."
docker exec "${mas_container}" bash "${CHANNEL_SCRIPT_DIR}/join-channel.sh" \
    "${REGULATOR}" "${MULTILATERAL_CHANNELS[@]}"

if [ -n "${bofa_container}" ]; then
    echo "Joining BOFA to ${MULTILATERAL_CHANNELS[*]}..."
    docker exec "${bofa_container}" bash "${CHANNEL_SCRIPT_DIR}/join-channel.sh" \
        "${BANK}" "${MULTILATERAL_CHANNELS[@]}"
else
    echo "BOFA peer not found; skipping BOFA channel join."
fi

echo "Channel setup complete."
