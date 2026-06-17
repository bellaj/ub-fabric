#!/usr/bin/env bash
# FabricNx01=orderer, FabricNx02=MAS, FabricNx03=BOFA, FabricNx04=CHASSGSG
set -euo pipefail

HOST_IP="${UBIN_HOST_IP:-127.0.0.1}"
MARKER="# ubin-fabric single-vm"
HOSTS_FILE="/etc/hosts"

HOSTNAMES=(
  FabricNx01
  FabricNx02
  FabricNx03
  FabricNx04
)

if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi

if grep -q "${MARKER}" "${HOSTS_FILE}" 2>/dev/null; then
  ${SUDO} sed -i "/${MARKER}/d" "${HOSTS_FILE}"
fi

echo "Adding FabricNx01–04 -> ${HOST_IP} in ${HOSTS_FILE}"
for name in "${HOSTNAMES[@]}"; do
  echo "${HOST_IP} ${name} ${MARKER}" | ${SUDO} tee -a "${HOSTS_FILE}" > /dev/null
done

echo "Done. Verify: getent hosts FabricNx02 FabricNx04"
