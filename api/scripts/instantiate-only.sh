#!/bin/bash
# Re-run instantiate steps (chaincode v3 already installed). Re-joins channels first.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

. "${SCRIPT_DIR}/script_functions.sh"
VERSION=`cat cc_version.txt 2>/dev/null || echo 3`

echo "Re-joining channels after peer restart..."
"${REPO_ROOT}/network/channels.sh"

echo "Waiting 30s for peers..."
sleep 30

InstantiateMultilateralAs "${ORG0_NAME}" "${ORG0_BIC}" "${ORG0_PEER}" fundingchannel
sleep 20
InstantiateMultilateralAs "${ORG0_NAME}" "${ORG0_BIC}" "${ORG0_PEER}" nettingchannel
sleep 20
InitNettingLedger
sleep 10
InstantiateBilateral bofasg2xchassgsgchannel
sleep 10
InitChannelAccounts bofasg2xchassgsgchannel
