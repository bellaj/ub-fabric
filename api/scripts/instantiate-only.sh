#!/bin/bash
# Re-run Fabric 2 lifecycle deploy (after channel re-join if needed).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

. "${SCRIPT_DIR}/script_functions.sh"
VERSION=`cat cc_version.txt 2>/dev/null || echo 3`

echo "Vendoring chaincode dependencies..."
VendorChaincodes "${REPO_ROOT}"

echo "Re-joining channels..."
"${REPO_ROOT}/network/channels.sh"

echo "Waiting 30s for peers..."
sleep 30

LifecycleDeployFunding
sleep 10
LifecycleDeployNetting
sleep 10
InitNettingLedger
sleep 10
LifecycleDeployBilateral bofasg2xchassgsgchannel
sleep 10
InitChannelAccounts bofasg2xchassgsgchannel
