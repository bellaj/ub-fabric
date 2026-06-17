#!/bin/bash
# MAS + 2 banks: funding, netting, and one bilateral channel (BOFA–CHASSGSG).

start=`date +%s`
echo "3" > cc_version.txt
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
echo "---------------- 3-ORG CONFIGURATION ----------------"
echo " NAME: ${ORG_NAME}"
echo " USER: ${ORG_USER}"
echo " PEER: ${ORG_PEER}"
echo " CONFIG FILE: ${NETWORK_CONFIG_FILE}"
echo "-------------------------------------------------------"
echo

echo "Enrolling all org users..."
EnrollOrg "${ORG0_NAME}" "${ORG0_BIC}"
EnrollOrg "${ORG1_NAME}" "${ORG1_BIC}"
EnrollOrg "${ORG2_NAME}" "${ORG2_BIC}"

echo "Installing chaincodes on all required peers..."
InstallOn "${ORG0_NAME}" "${ORG0_PEER}" "${ORG0_BIC}" bilateralchannel
InstallOn "${ORG0_NAME}" "${ORG0_PEER}" "${ORG0_BIC}" fundingchannel
InstallOn "${ORG0_NAME}" "${ORG0_PEER}" "${ORG0_BIC}" nettingchannel
InstallOn "${ORG1_NAME}" "${ORG1_PEER}" "${ORG1_BIC}" bilateralchannel
InstallOn "${ORG1_NAME}" "${ORG1_PEER}" "${ORG1_BIC}" nettingchannel
InstallOn "${ORG2_NAME}" "${ORG2_PEER}" "${ORG2_BIC}" bilateralchannel
InstallOn "${ORG2_NAME}" "${ORG2_PEER}" "${ORG2_BIC}" nettingchannel

if [ "${ORG_NAME}" = "${REGULATOR_ORG}" ]; then
    echo "Waiting 30s before instantiate..."
    sleep 30
    echo "Instantiating chaincodes..."
    InstantiateMultilateralAs "${ORG0_NAME}" "${ORG0_BIC}" "${ORG0_PEER}" fundingchannel
    sleep 20
    InstantiateMultilateralAs "${ORG0_NAME}" "${ORG0_BIC}" "${ORG0_PEER}" nettingchannel
    sleep 20
    InitNettingLedger
    sleep 10
    InstantiateBilateral bofasg2xchassgsgchannel
    sleep 10
    InitChannelAccounts bofasg2xchassgsgchannel
fi

echo "Enabling ping cron job"
./cron_control.sh --enable fabric_ping 2>/dev/null || true

end=`date +%s`
runtime=$((end-start))
echo "Initialization completed as of $(date)"
echo "Script Execution Time: ${runtime}"
