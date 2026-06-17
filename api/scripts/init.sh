#!/bin/bash
# Initialise API and chaincodes for the 2-org network (MAS + BOFA).

start=`date +%s`
echo "1" > cc_version.txt
VERSION=`cat cc_version.txt`

echo "Disabling ping cron job"
./cron_control.sh --disable fabric_ping

if [ -e ./script_functions.sh ]; then
    . ./script_functions.sh
else
    . ~/ubin-fabric/api/scripts/script_functions.sh
fi

mkdir -p ../logs
RestartNodeJS

echo
echo "---------------- 2-ORG CONFIGURATION ----------------"
echo " NAME: ${ORG_NAME}"
echo " USER: ${ORG_USER}"
echo " PEER: ${ORG_PEER}"
echo " CONFIG FILE: ${NETWORK_CONFIG_FILE}"
echo "-------------------------------------------------------"
echo

Enroll
Install bilateralchannel
Install fundingchannel
Install nettingchannel

if [ "${ORG_NAME}" = "${REGULATOR_ORG}" ]; then
    sleep 20
    echo "Instantiating multilateral channels (funding + netting)..."
    InstantiateMultilateral fundingchannel
    InstantiateMultilateral nettingchannel
fi

echo "Enabling ping cron job"
./cron_control.sh --enable fabric_ping

end=`date +%s`
runtime=$((end-start))
echo "Initialization completed as of $(date)"
echo "Script Execution Time: ${runtime}"
