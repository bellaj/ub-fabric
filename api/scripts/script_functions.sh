#!/bin/bash

if [ -e ./config.sh ]
then
    echo "config.sh found in current folder"
    . ./config.sh
else
    echo "config.sh not found in current folder. Execute via direct path..."
    . ~/ubin-fabric-api/scripts/config.sh
fi

CURRENCY=SGD

SetPeers() {
    CHANNEL=$1

    CHANNEL_PEER0=`jq -r .channelMapping.${CHANNEL}[0] ${NETWORK_REFERENCE_FILE}`
    CHANNEL_PEER1=`jq -r .channelMapping.${CHANNEL}[1] ${NETWORK_REFERENCE_FILE}`

    echo
    echo "Channel peers:"
    echo ${CHANNEL_PEER0}
    echo ${CHANNEL_PEER1}
    echo
}


#==============================================
# 
# STARTUP FUNCTIONS
# 
#==============================================

RestartNodeJS() {
    STATE=`ps -ef | grep "app.js" | grep -v grep | wc -l`
    if [ "${STATE}" -ne 0 ] ; then
        echo "NodeJS currently running. Shutting down..."
        pm2 stop all
        echo "NodeJS has been shut down...."
    else
        echo "NodeJS server is not running"
    fi

    if [ ! -f ecosystem.config.js ]; then
        cp ecosystem.config-template.js ecosystem.config.js
    fi

    if [ ! -f "../node_modules/grpc/src/node/extension_binary/node-v93-linux-$(uname -m | sed 's/aarch64/arm64/')-glibc/grpc_node.node" ] \
       && [ ! -f "../node_modules/grpc/src/node/extension_binary/node-v93-linux-x64-glibc/grpc_node.node" ]; then
        echo "Building grpc native module..."
        (cd ../node_modules/grpc && npm run install)
    fi

    echo
    echo "Starting NodeJS and waiting 10 seconds..."
    pm2 start ecosystem.config.js
    sleep 10
}


#**********************************************
# FUNCTIONS FOR ENROLMENT
#**********************************************

Enroll() {
    EnrollOrg "${ORG_NAME}" "${ORG_USER}"
}

EnrollOrg() {
    local org=$1
    local user=$2
    echo "POST - Enrolling ${user} on ${org}"
    RESP=$(curl -s -X POST \
        http://localhost:8080/api/users \
        -H "content-type: application/x-www-form-urlencoded" \
        -d "username=${user}&orgName=${org}")
    echo "Enroll Response: ${RESP}"
    echo
    echo
}


#**********************************************
# FUNCTIONS FOR INSTALLATION/INSTANTIATION
#**********************************************

InstallOn() {
    local org=$1
    local peer=$2
    local user=$3
    local chaincode=$4

    echo "POST install chaincode ${chaincode} version ${VERSION} on ${org}/${user} with ${peer}"
    RESP=$(curl -s -X POST \
        http://localhost:8080/api/chaincodes \
        -H "content-type: application/json" \
        -d "{
        \"username\" : \"${user}\",
        \"orgname\" : \"${org}\",
        \"peers\" : [\"${peer}\"],
        \"chaincodeName\":\"${chaincode}_cc\",
        \"chaincodePath\":\"ubin-fabric/chaincode/${chaincode}\",
        \"chaincodeVersion\":\"${VERSION}\"
    }")
    echo "Installation response:"
    echo "$RESP"
    echo
    echo
}

Install() {
    InstallOn "${ORG_NAME}" "${ORG_PEER}" "${ORG_USER}" "$1"
}

InstantiateBilateral() {
    CHANNEL=$1

    PEER0=`jq -r .channelMapping.${CHANNEL}[0] ${NETWORK_REFERENCE_FILE}`
    PEER1=`jq -r .channelMapping.${CHANNEL}[1] ${NETWORK_REFERENCE_FILE}`

    echo
    echo "Channel peers:"
    echo ${PEER0}
    echo ${PEER1}
    echo

    echo "POST instantiate bilateral on ${CHANNEL} using ${ORG1_NAME}/${ORG1_BIC}"
    RESP=$(curl -s -X POST \
        http://localhost:8080/api/channels/${CHANNEL}/chaincodes \
        -H "content-type: application/json" \
        -d "{
        \"username\" : \"${ORG1_BIC}\",
        \"orgname\" : \"${ORG1_NAME}\",
        \"peers\" : [\"${PEER0}\", \"${PEER1}\"],
        \"functionName\" : \"init\",
        \"args\" : [],
        \"chaincodeName\":\"bilateralchannel_cc\",
        \"chaincodePath\":\"ubin-fabric/chaincode/bilateralchannel\",
        \"chaincodeVersion\":\"${VERSION}\"
    }")
    echo "Instantiation response:"
    echo "$RESP"
    echo
    echo
}

InstantiateMultilateralAs() {
    local org=$1
    local user=$2
    local peer=$3
    local channel=$4

    echo "POST instantiate chaincode on ${channel} using ${org}/${user} with ${peer}"
    RESP=$(curl -s -X POST \
        http://localhost:8080/api/channels/${channel}/chaincodes \
        -H "content-type: application/json" \
        -d "{
        \"username\" : \"${user}\",
        \"orgname\" : \"${org}\",
        \"peers\" : [\"${peer}\"],
        \"functionName\" : \"init\",
        \"args\" : [],
        \"chaincodeName\":\"${channel}_cc\",
        \"chaincodePath\":\"ubin-fabric/chaincode/${channel}\",
        \"chaincodeVersion\":\"${VERSION}\"
    }")
    echo "Instantiation response:"
    echo "$RESP"
    echo
    echo
}

InstantiateMultilateral() {
    InstantiateMultilateralAs "${ORG_NAME}" "${ORG_USER}" "${ORG_PEER}" "$1"
}

Upgrade() {
    CHANNEL=$1

    CHAINCODE=bilateralchannel
    if [ "${CHANNEL}" = "nettingchannel" -o "${CHANNEL}" = "fundingchannel" ]; then
        CHAINCODE=${CHANNEL}
    fi

    echo "POST upgrade chaincode on ${CHANNEL} using ${ORG_NAME}/${ORG_USER} with ${ORG_PEER}"
    RESP=$(curl -s -X POST \
        http://localhost:8080/api/channels/${CHANNEL}/chaincodes/upgrade \
        -H "content-type: application/json" \
        -d "{
        \"username\" : \"${ORG_USER}\",
        \"orgname\" : \"${ORG_NAME}\",
        \"peers\" : [\"${ORG_PEER}\"],
        \"functionName\" : \"init\",
        \"args\" : [],
        \"chaincodeName\":\"${CHAINCODE}_cc\",
        \"chaincodePath\":\"ubin-fabric/chaincode/${CHAINCODE}\",
        \"chaincodeVersion\":\"${VERSION}\"
    }")
    echo "Upgrade response:"
    echo "$RESP"
    echo
    echo
}

#==============================================
# 
# CHAINCODE FUNCTIONS
# 
#==============================================


#**********************************************
# FUNCTIONS FOR ASSET INITIALIZATION
#**********************************************

InitAccountOn() {
    local org=$1
    local user=$2
    local account=$3
    local amount=$4
    local channel=$5

    PEER0=`jq -r .channelMapping.${channel}[0] ${NETWORK_REFERENCE_FILE}`
    PEER1=`jq -r .channelMapping.${channel}[1] ${NETWORK_REFERENCE_FILE}`

    echo "POST - initAccount ${account} with ${amount} ${CURRENCY} in ${channel} as ${org}/${user}"
    RESP=$(curl -s -X POST \
        http://localhost:8080/api/channels/${channel}/chaincodes/bilateralchannel_cc \
        -H "content-type: application/json" \
        -d "{
        \"username\" : \"${user}\",
        \"orgname\" : \"${org}\",
        \"peers\": [\"${PEER0}\", \"${PEER1}\"],
        \"fcn\":\"initAccount\",
        \"args\":[\"${account}\",\"${CURRENCY}\",\"${amount}\",\"NORMAL\"] 
    }")
    echo "InitAccount response:"
    echo "$RESP"
    echo
}

InitAccount() {
    InitAccountOn "${ORG_NAME}" "${ORG_USER}" "$1" "$2" "$3"
}

InitNettingLedger() {
    CHANNEL=nettingchannel
    PEER0=`jq -r .channelMapping.${CHANNEL}[0] ${NETWORK_REFERENCE_FILE}`
    PEER1=`jq -r .channelMapping.${CHANNEL}[1] ${NETWORK_REFERENCE_FILE}`
    PEER2=`jq -r .channelMapping.${CHANNEL}[2] ${NETWORK_REFERENCE_FILE}`

    echo "POST - initLedger on ${CHANNEL} as ${ORG0_NAME}/${ORG0_BIC}"
    RESP=$(curl -s -X POST \
        http://localhost:8080/api/channels/${CHANNEL}/chaincodes/nettingchannel_cc \
        -H "content-type: application/json" \
        -d "{
        \"username\" : \"${ORG0_BIC}\",
        \"orgname\" : \"${ORG0_NAME}\",
        \"peers\": [\"${PEER0}\", \"${PEER1}\", \"${PEER2}\"],
        \"fcn\":\"initLedger\",
        \"args\":[]
    }")
    echo "InitNettingLedger response:"
    echo "$RESP"
    echo
}

InitChannelAccounts() {
    CHANNEL=$1

    ACCT1=`jq -r .channelBankMapping.${CHANNEL}[0] ${NETWORK_REFERENCE_FILE}`
    ACCT2=`jq -r .channelBankMapping.${CHANNEL}[1] ${NETWORK_REFERENCE_FILE}`

    InitAccountOn "${ORG1_NAME}" "${ORG1_BIC}" "${ACCT1}" 0 "${CHANNEL}"
    InitAccountOn "${ORG1_NAME}" "${ORG1_BIC}" "${ACCT2}" 0 "${CHANNEL}"
}

#**********************************************
# OTHER FUNCTIONS
#**********************************************


PingChaincode() {
    ORG_NAME=$1
    CHANNEL=$2

    SetOrg ${ORG_NAME}
    SetPeers ${CHANNEL}

    echo "GET - Ping all chaincodes"
    curl -X GET http://localhost:8080/api/ping -H 'content-type: application/json'
    echo
    echo
}


