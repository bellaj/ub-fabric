#!/bin/bash

NETWORK_CONFIG_PATH=../config
NETWORK_REFERENCE_FILE=${NETWORK_CONFIG_PATH}/network-reference.json
REGULATOR_ORG=org0

ORG0_NAME=org0
ORG0_HOST=FabricNx02
ORG0_CONFIG=network-config_masgsgsg

ORG1_NAME=org1
ORG1_HOST=FabricNx03
ORG1_CONFIG=network-config_bofasg2x

ORG2_NAME=org2
ORG2_HOST=FabricNx04
ORG2_CONFIG=network-config_chassgsg

jq --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Please Install 'jq' https://stedolan.github.io/jq/ to execute this script"
    echo
    exit 1
fi

if [ -n "${UBIN_ORG:-}" ]; then
    case ${UBIN_ORG} in
        ${ORG0_NAME}) NETWORK_CONFIG=${ORG0_CONFIG}; ORG_NAME=${ORG0_NAME} ;;
        ${ORG1_NAME}) NETWORK_CONFIG=${ORG1_CONFIG}; ORG_NAME=${ORG1_NAME} ;;
        ${ORG2_NAME}) NETWORK_CONFIG=${ORG2_CONFIG}; ORG_NAME=${ORG2_NAME} ;;
        *) echo "Invalid UBIN_ORG (${UBIN_ORG}). Use org0, org1, or org2."; exit 1 ;;
    esac
else
    case $(hostname) in
        ${ORG0_HOST}) NETWORK_CONFIG=${ORG0_CONFIG}; ORG_NAME=${ORG0_NAME} ;;
        ${ORG1_HOST}) NETWORK_CONFIG=${ORG1_CONFIG}; ORG_NAME=${ORG1_NAME} ;;
        ${ORG2_HOST}) NETWORK_CONFIG=${ORG2_CONFIG}; ORG_NAME=${ORG2_NAME} ;;
        *) echo "Invalid Hostname ($(hostname)). Run setup-hosts.sh, set hostname FabricNx02, or export UBIN_ORG=org0."; exit 1 ;;
    esac
fi

NETWORK_CONFIG_FILE=${NETWORK_CONFIG_PATH}/${NETWORK_CONFIG}.json

ORG_PEER=`jq -r .networkConfig.${ORG_NAME}.orgPeers[0] ${NETWORK_CONFIG_FILE}`
ORG_USER=`jq -r .networkConfig.${ORG_NAME}.bic ${NETWORK_CONFIG_FILE}`
ORG_ACCT=${ORG_USER}

ORG0_BIC=`jq -r .networkConfig.${ORG0_NAME}.bic ${NETWORK_CONFIG_FILE}`
ORG1_BIC=`jq -r .networkConfig.${ORG1_NAME}.bic ${NETWORK_CONFIG_FILE}`
ORG2_BIC=`jq -r .networkConfig.${ORG2_NAME}.bic ${NETWORK_CONFIG_FILE}`

# Single-VM orchestration uses the MAS config file for all org peer addresses.
MAS_CONFIG=${NETWORK_CONFIG_PATH}/network-config_masgsgsg.json
ORG0_PEER=`jq -r .networkConfig.org0.orgPeers[0] ${MAS_CONFIG}`
ORG1_PEER=`jq -r .networkConfig.org1.orgPeers[0] ${MAS_CONFIG}`
ORG2_PEER=`jq -r .networkConfig.org2.orgPeers[0] ${MAS_CONFIG}`
