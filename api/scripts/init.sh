#!/bin/bash
# MAS + 2 banks: Fabric 2.x lifecycle deploy (funding, netting, bilateral).

start=`date +%s`
echo "1" > cc_version.txt
VERSION=`cat cc_version.txt`

echo "Disabling ping cron job"
./cron_control.sh --disable fabric_ping 2>/dev/null || true

if [ -e ./script_functions.sh ]; then
    . ./script_functions.sh
else
    . ~/ubin-fabric/api/scripts/script_functions.sh
fi

mkdir -p ../logs
RestartNodeJS

echo
echo "---------------- 3-ORG CONFIGURATION (Fabric 2 lifecycle) ----------------"
echo " NAME: ${ORG_NAME}"
echo " USER: ${ORG_USER}"
echo " PEER: ${ORG_PEER}"
echo " CONFIG FILE: ${NETWORK_CONFIG_FILE}"
echo " CC VERSION / SEQUENCE: ${VERSION}"
echo "-------------------------------------------------------------------------"
echo

echo "Enrolling all org users..."
EnrollOrg "${ORG0_NAME}" "${ORG0_BIC}"
EnrollOrg "${ORG1_NAME}" "${ORG1_BIC}"
EnrollOrg "${ORG2_NAME}" "${ORG2_BIC}"

if [ "${ORG_NAME}" = "${REGULATOR_ORG}" ]; then
    REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
    echo "Vendoring chaincode dependencies..."
    VendorChaincodes "${REPO_ROOT}"

    echo "Waiting 30s before chaincode lifecycle deploy..."
    sleep 30

    echo "Deploying chaincodes (Fabric 2 lifecycle)..."
    LifecycleDeployFunding
    sleep 10
    LifecycleDeployNetting
    sleep 10
    InitNettingLedger
    sleep 10
    LifecycleDeployBilateral bofasg2xchassgsgchannel
    sleep 10
    InitChannelAccounts bofasg2xchassgsgchannel
fi

echo "Enabling ping cron job"
./cron_control.sh --enable fabric_ping 2>/dev/null || true

end=`date +%s`
runtime=$((end-start))
echo "Initialization completed as of $(date)"
echo "Script Execution Time: ${runtime}"
