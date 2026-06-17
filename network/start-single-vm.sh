#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ADVERTISE_ADDR="${UBIN_SWARM_ADDR:-}"

echo "=== Ubin Fabric single-VM startup ==="

if ! getent hosts FabricNx02 >/dev/null 2>&1; then
  "${SCRIPT_DIR}/setup-hosts.sh"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Run fabric-setup.sh first."
  exit 1
fi

if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
  if [ -n "${ADVERTISE_ADDR}" ]; then
    docker swarm init --advertise-addr "${ADVERTISE_ADDR}"
  else
    docker swarm init || docker swarm init --advertise-addr 127.0.0.1
  fi
fi

echo "Pulling Fabric images..."
docker pull hyperledger/fabric-orderer:2.5.15
docker pull hyperledger/fabric-peer:2.5.12
docker pull hyperledger/fabric-ca:1.5
docker pull couchdb:2.3.1
docker pull hyperledger/fabric-ccenv:2.5
docker pull hyperledger/fabric-baseos:2.5

echo "Building custom chaincode images (libltdl for vendored pkcs11)..."
docker build -t ubin-fabric-ccenv:2.5 -f docker/ccenv.Dockerfile docker/
docker build -t ubin-fabric-baseos:2.5 -f docker/baseos.Dockerfile docker/

cd "${SCRIPT_DIR}"
docker stack rm ubin 2>/dev/null || true
sleep 8
docker stack deploy -c docker-compose.yaml ubin

echo "Waiting 180s for containers to start..."
sleep 180

docker service ls
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo "Creating and joining channels..."
./channels.sh

echo
echo "Next steps:"
echo "  1. sudo hostnamectl set-hostname FabricNx02   # or: export UBIN_ORG=org0"
echo "  2. cd ${REPO_ROOT}/api/scripts"
echo "  3. cp ecosystem.config-template.js ecosystem.config.js   # if not done"
echo "  4. ./init.sh"
echo "  5. curl http://localhost:8080/api/ping"
