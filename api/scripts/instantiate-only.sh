#!/bin/bash
# Re-run instantiate steps after peer timeout increases (chaincode v3 already installed).

. ./script_functions.sh
VERSION=`cat cc_version.txt 2>/dev/null || echo 3`

InstantiateMultilateralAs "${ORG0_NAME}" "${ORG0_BIC}" "${ORG0_PEER}" fundingchannel
sleep 20
InstantiateMultilateralAs "${ORG0_NAME}" "${ORG0_BIC}" "${ORG0_PEER}" nettingchannel
sleep 20
InitNettingLedger
sleep 10
InstantiateBilateral bofasg2xchassgsgchannel
sleep 10
InitChannelAccounts bofasg2xchassgsgchannel
