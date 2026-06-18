#!/bin/bash
# Fabric 2.x chaincode lifecycle (package / install / approve / commit) via peer CLI in Docker.

ORDERER=orderer.example.com:7050
CC_SRC_ROOT=/opt/gopath/src/ubin-fabric/chaincode

declare -A ORG_MSP=(
    [masgsgsg]=masgsgsgMSP
    [bofasg2x]=bofasg2xMSP
    [chassgsg]=chassgsgMSP
)

declare -A ORG_PEER_ADDR=(
    [masgsgsg]=peer0.masgsgsg.example.com:7051
    [bofasg2x]=peer0.bofasg2x.example.com:7051
    [chassgsg]=peer0.chassgsg.example.com:7051
)

find_peer_container() {
    docker ps --format '{{.ID}} {{.Names}}' \
        | grep -E "peer0[.-]${1}" \
        | grep -v 'dev-peer' \
        | head -1 | awk '{print $1}'
}

peer_exec() {
    local org=$1
    local container=$2
    shift 2
    docker exec \
        -e CORE_PEER_LOCALMSPID="${ORG_MSP[$org]}" \
        -e CORE_PEER_MSPCONFIGPATH="/etc/hyperledger/crypto/msp/users/Admin@${org}.example.com/msp" \
        -e CORE_PEER_ADDRESS="${ORG_PEER_ADDR[$org]}" \
        -e CORE_PEER_TLS_ENABLED=false \
        "${container}" peer "$@"
}

lifecycle_package() {
    local cc_dir=$1
    local version=$2
    local repo_root=$3
    local label="${cc_dir}_cc_${version}"
    local pkg_dir="${repo_root}/api/scripts/.packages"
    local pkg="${pkg_dir}/${label}.tar.gz"

    mkdir -p "${pkg_dir}"
    echo "Packaging ${cc_dir} label=${label}..." >&2
    docker run --rm \
        -v "${repo_root}/chaincode/${cc_dir}:${CC_SRC_ROOT}/${cc_dir}:ro" \
        -v "${pkg_dir}:/packages" \
        hyperledger/fabric-tools:2.5 \
        peer lifecycle chaincode package "/packages/${label}.tar.gz" \
        --path "${CC_SRC_ROOT}/${cc_dir}" \
        --lang golang \
        --label "${label}"
    echo "${pkg}"
}

lifecycle_install() {
    local org=$1
    local container=$2
    local pkg=$3
    local pkg_name
    pkg_name="$(basename "${pkg}")"

    echo "Installing ${pkg_name} on ${org} (${container})..." >&2
    peer_exec "${org}" "${container}" lifecycle chaincode install "/packages/${pkg_name}" \
        || echo "Install skipped or already present on ${org}" >&2
}

lifecycle_package_id() {
    local org=$1
    local container=$2
    local label=$3

    peer_exec "${org}" "${container}" lifecycle chaincode queryinstalled --output json \
        | jq -r ".installed_chaincodes[] | select(.label==\"${label}\") | .package_id" | head -1
}

lifecycle_approve() {
    local org=$1
    local container=$2
    local channel=$3
    local cc_name=$4
    local version=$5
    local sequence=$6
    local package_id=$7
    local policy=$8

    echo "Approve ${cc_name} v${version} seq${sequence} on ${channel} for ${org}..."
    peer_exec "${org}" "${container}" lifecycle chaincode approveformyorg \
        -o "${ORDERER}" \
        --channelID "${channel}" \
        --name "${cc_name}" \
        --version "${version}" \
        --package-id "${package_id}" \
        --sequence "${sequence}" \
        --signature-policy "${policy}"
}

lifecycle_commit() {
    local channel=$1
    local cc_name=$2
    local version=$3
    local sequence=$4
    local policy=$5
    local commit_org=$6
    local commit_container=$7
    shift 7
    local orgs=("$@")
    local peer_args=()

    for org in "${orgs[@]}"; do
        peer_args+=(--peerAddresses "${ORG_PEER_ADDR[$org]}")
    done

    echo "Commit ${cc_name} v${version} seq${sequence} on ${channel}..."
    peer_exec "${commit_org}" "${commit_container}" lifecycle chaincode commit \
        -o "${ORDERER}" \
        --channelID "${channel}" \
        --name "${cc_name}" \
        --version "${version}" \
        --sequence "${sequence}" \
        --signature-policy "${policy}" \
        "${peer_args[@]}"
}

lifecycle_check_committed() {
    local org=$1
    local container=$2
    local channel=$3
    local cc_name=$4

    peer_exec "${org}" "${container}" lifecycle chaincode querycommitted \
        --channelID "${channel}" --name "${cc_name}" --output json 2>/dev/null \
        | jq -r '.chaincode_definitions[0].version // empty'
}

# Deploy one chaincode to a channel using Fabric 2 lifecycle.
# Usage: lifecycle_deploy <cc_dir> <cc_name> <channel> <version> <sequence> <policy> <org1> [org2 ...]
lifecycle_deploy() {
    local cc_dir=$1
    local cc_name=$2
    local channel=$3
    local version=$4
    local sequence=$5
    local policy=$6
    shift 6
    local orgs=("$@")
    local label="${cc_dir}_cc_${version}"

    ORG_FOR_PACKAGE="${orgs[0]}"
    local package_container
    package_container="$(find_peer_container "${ORG_FOR_PACKAGE}")"
    if [ -z "${package_container}" ]; then
        echo "No peer container for ${ORG_FOR_PACKAGE}"
        return 1
    fi

    local repo_root
    repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
    local pkg
    pkg="$(lifecycle_package "${cc_dir}" "${version}" "${repo_root}")"

    declare -A PACKAGE_IDS=()
    for org in "${orgs[@]}"; do
        local c
        c="$(find_peer_container "${org}")"
        if [ -z "${c}" ]; then
            echo "Peer container not found for ${org}"
            return 1
        fi
        lifecycle_install "${org}" "${c}" "${pkg}"
        local pid
        pid="$(lifecycle_package_id "${org}" "${c}" "${label}")"
        if [ -z "${pid}" ]; then
            echo "Failed to resolve package id for ${label} on ${org}"
            return 1
        fi
        PACKAGE_IDS["${org}"]="${pid}"
        echo "Package ID on ${org}: ${pid}"
    done

    for org in "${orgs[@]}"; do
        local c
        c="$(find_peer_container "${org}")"
        lifecycle_approve "${org}" "${c}" "${channel}" "${cc_name}" "${version}" "${sequence}" \
            "${PACKAGE_IDS[$org]}" "${policy}"
    done

    lifecycle_commit "${channel}" "${cc_name}" "${version}" "${sequence}" "${policy}" \
        "${orgs[0]}" "$(find_peer_container "${orgs[0]}")" "${orgs[@]}"

    local committed
    committed="$(lifecycle_check_committed "${orgs[0]}" "$(find_peer_container "${orgs[0]}")" "${channel}" "${cc_name}")"
    if [ -n "${committed}" ]; then
        echo "Committed ${cc_name} version ${committed} on ${channel}"
    else
        echo "WARNING: ${cc_name} not visible in querycommitted on ${channel}"
        return 1
    fi
}

POLICY_FUNDING="AND('masgsgsgMSP.member')"
POLICY_NETTING="AND('masgsgsgMSP.member','bofasg2xMSP.member','chassgsgMSP.member')"
POLICY_BILATERAL="AND('bofasg2xMSP.member','chassgsgMSP.member')"

LifecycleDeployFunding() {
    lifecycle_deploy fundingchannel fundingchannel_cc fundingchannel "${VERSION}" "${VERSION}" \
        "${POLICY_FUNDING}" masgsgsg bofasg2x chassgsg
}

LifecycleDeployNetting() {
    lifecycle_deploy nettingchannel nettingchannel_cc nettingchannel "${VERSION}" "${VERSION}" \
        "${POLICY_NETTING}" masgsgsg bofasg2x chassgsg
}

LifecycleDeployBilateral() {
    local channel=$1
    lifecycle_deploy bilateralchannel bilateralchannel_cc "${channel}" "${VERSION}" "${VERSION}" \
        "${POLICY_BILATERAL}" bofasg2x chassgsg
}

# Build vendor/ for chaincode using Go in Docker (needed before lifecycle package).
VendorChaincodes() {
    local repo_root=$1
    for cc in bilateralchannel fundingchannel nettingchannel; do
        echo "Vendoring ${cc}..."
        docker run --rm \
            -v "${repo_root}/chaincode/${cc}:/work" \
            -w /work \
            golang:1.22-bookworm \
            sh -c 'go mod tidy && go mod vendor'
    done
}
