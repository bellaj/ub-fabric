# Running Ubin Fabric in a Single Virtual Machine

This guide explains how to set up and run the entire Project Ubin Phase 2 - Hyperledger Fabric prototype in a single Virtual Machine, instead of the default 13-VM distributed setup.

## Overview

The standard setup uses 13 VMs:
- 1 Orderer node
- 1 Central Bank node (MAS)
- 11 Bank nodes

This guide shows how to consolidate all components into a single VM using Docker containers on a single machine.

## Prerequisites

Your VM should meet the following requirements:

- **Operating System**: Ubuntu 16.04.3 LTS (64-bit) or later
- **CPU**: Minimum 4 cores (8+ recommended)
- **RAM**: Minimum 8GB (16GB recommended)
- **Disk Space**: Minimum 10GB free space
- **Docker**: 17.09.0-ce or later
- **Fabric**: 1.0.1
- **Go**: 1.7.6 or later
- **Node JS**: 6.9.5 or later
- **NPM**: 3.10.10 or later
- **PM2**: 2.7.2 or later

### Installation of Prerequisites

Run the provided setup script to install all prerequisites:

```bash
cd $GOPATH/src/ubin-fabric
bash fabric-setup.sh
```

After the script completes, reboot the VM:

```bash
sudo reboot
```

## Single VM Architecture

In a single VM setup, all containers will run on the same machine:

```
┌─────────────────────────────────────────────────┐
│           Single Virtual Machine                │
├─────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────┐   │
│  │  Docker Daemon & Docker Swarm (Manager)  │   │
│  ├──────────────────────────────────────────┤   │
│  │ ┌─────────────┐  ┌─────────────┐         │   │
│  │ │   Orderer   │  │   MAS Peer  │         │   │
│  │ │  Container  │  │  Container  │         │   │
│  │ └─────────────┘  └─────────────┘         │   │
│  │ ┌─────────────┐  ┌─────────────┐         │   │
│  │ │  Bank Peers │  │   CouchDB   │         │   │
│  │ │ (11x or 1x) │  │ Containers  │         │   │
│  │ └─────────────┘  └─────────────┘         │   │
│  │ ┌──────────────────────────────────────┐ │   │
│  │ │      API Layer (Node.js + PM2)      │ │   │
│  │ └──────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────┐   │
│  │       Localhost Network Binding           │   │
│  │     (All services via 127.0.0.1)         │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## Step-by-Step Setup

### Step 1: Clone the Repository

```bash
cd $GOPATH/src
git clone https://github.com/bellaj/ub-fabric.git
cd ub-fabric
```

### Step 2: Install Node.js Dependencies

```bash
cd api
npm install
cd ..
```

### Step 3: Configure for Single VM Deployment

#### Modify `docker-compose.yaml`

The default `docker-compose.yaml` assumes multiple VMs. For a single VM, modify it:

1. Update all hostname references to `localhost`
2. Remove inter-VM networking requirements
3. Ensure all services bind to localhost

```bash
cd network
# Backup original
cp docker-compose.yaml docker-compose.yaml.backup

# Edit the file
nano docker-compose.yaml
```

**Key changes to make:**
- Replace all peer/orderer hostname references with `localhost`
- Ensure CouchDB binds to `localhost:5984` (and additional ports for multiple peers)
- Set environment variables to use localhost addresses

#### Example Configuration

```yaml
version: '3.1'

services:
  orderer:
    image: hyperledger/fabric-orderer:2.5.15
    environment:
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/orderer.genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
    volumes:
      - ./channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
      - ./crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp
    ports:
      - "7050:7050"
    command: orderer

  peer0-mas:
    image: hyperledger/fabric-peer:2.5.12
    environment:
      - CORE_PEER_ID=peer0.mas.example.com
      - CORE_PEER_ADDRESS=localhost:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=localhost:7051
      - CORE_PEER_LOCALMSPID=MASMSSP
    depends_on:
      - orderer
    ports:
      - "7051:7051"
      - "7053:7053"

  # Add similar configurations for other bank peers with different port mappings
```

### Step 4: Update Hostname Configuration

Modify the crypto configuration to use localhost:

```bash
# Edit crypto-config.yaml
nano crypto-config.yaml
```

For single VM, use patterns like:
```yaml
Hostname: localhost
```

### Step 5: Generate Cryptographic Materials

```bash
cd network

# Generate certificates and keys
../bin/cryptogen generate --config=./crypto-config.yaml

# Generate channel artifacts
mkdir -p channel-artifacts
../bin/configtxgen -profile OrdererGenesis -outputBlock ./channel-artifacts/genesis.block
../bin/configtxgen -profile Channel -outputCreateChannelTx ./channel-artifacts/channel.tx
```

### Step 6: Initialize Docker Swarm

Since we're on a single machine, initialize the swarm in manager mode:

```bash
docker swarm init
```

### Step 7: Deploy Docker Stack

```bash
# Start all containers
docker stack deploy -c docker-compose.yaml ubin

# Wait approximately 2 minutes for containers to initialize
sleep 120

# Verify containers are running
docker ps
```

### Step 8: Create and Join Channels

```bash
# Execute from the network folder
./channels.sh
```

This script will:
- Create channels (bilateral, funding, netting)
- Join all peers to the appropriate channels

### Step 9: Configure and Initialize API Layer

```bash
cd api/scripts

# Copy template configuration
cp ecosystem.config-template.js ecosystem.config.js

# Edit configuration to point to localhost
nano ecosystem.config.js
```

Update the configuration to reflect localhost addresses:

```javascript
module.exports = {
  apps: [
    {
      name: 'ubin-api',
      script: '../app.js',
      instances: 1,
      exec_mode: 'cluster',
      args: '--orgname mas --port 8080',
      env: {
        NODE_ENV: 'production',
        FABRIC_CFG_PATH: process.cwd()
      }
    }
  ]
};
```

### Step 10: Install and Instantiate Chaincodes

```bash
# From api folder
cd $GOPATH/src/ubin-fabric/api

# Install chaincodes on all peers
./init.sh

# Wait for installation to complete (2-3 minutes)
```

The script will:
- Install bilateral chaincode
- Install funding chaincode
- Install netting chaincode
- Instantiate all chaincodes on each channel

### Step 11: Start the API Layer

```bash
cd api/scripts

# Start API using PM2
pm2 start ecosystem.config.js

# Verify API is running
pm2 status

# Check logs
pm2 logs ubin-api
```

### Step 12: Configure Cron Jobs (Optional)

Set up periodic keep-alive transactions:

```bash
# Edit crontab
crontab -e

# Add the following line to maintain container liveliness
*/10 * * * * [ -f /var/tmp/croncontrol/fabric_ping ] || curl -X GET http://localhost:8080/api/ping -H 'content-type: application/json' -o $HOME/ping.log
```

## Port Mapping for Single VM

When running multiple components on a single VM, ensure unique port mappings:

| Service | Local Port | Container Port | Notes |
|---------|-----------|-----------------|-------|
| Orderer | 7050 | 7050 | Consensus service |
| Peer 0 (MAS) | 7051 | 7051 | Peer gRPC endpoint |
| Peer 0 Events | 7053 | 7053 | Event endpoint |
| Peer 1 (Bank1) | 8051 | 7051 | Separate peer port |
| Peer 1 Events | 8053 | 7053 | |
| CouchDB 0 | 5984 | 5984 | State database for Peer 0 |
| CouchDB 1 | 6984 | 5984 | State database for Peer 1 |
| API | 8080 | 8080 | REST API endpoint |

**Example for multiple peers:**
```bash
# Port allocation pattern
Peer 0: 7051, 7053, CouchDB: 5984
Peer 1: 8051, 8053, CouchDB: 6984
Peer 2: 9051, 9053, CouchDB: 7984
```

## Verification

### Check Docker Containers

```bash
# List running containers
docker ps

# Expected output should show:
# - orderer container
# - peer containers
# - couchdb containers
```

### Test API Endpoint

```bash
# Test the API is responding
curl -X GET http://localhost:8080/api/ping

# Expected response:
# {"status":"pong"}
```

### Test Chaincode Invocation

```bash
# Example transaction through REST API
curl -X POST http://localhost:8080/api/transaction \
  -H 'content-type: application/json' \
  -d '{
    "channel": "bilateral",
    "chaincode": "bilateral",
    "function": "transfer",
    "args": ["value"]
  }'
```

### View Container Logs

```bash
# View orderer logs
docker service logs ubin_orderer

# View peer logs
docker service logs ubin_peer0

# View API logs
pm2 logs ubin-api
```

## Managing the Single VM Setup

### Stop All Services

```bash
# Stop API
pm2 stop ubin-api

# Stop Docker stack
docker stack rm ubin
```

### Resume Services

```bash
# Start Docker stack
cd $GOPATH/src/ubin-fabric/network
docker stack deploy -c docker-compose.yaml ubin

# Wait for containers to be ready
sleep 60

# Start API
cd api/scripts
pm2 start ecosystem.config.js
```

### Complete Teardown

```bash
# Stop and remove everything
cd $GOPATH/src/ubin-fabric/network

# Kill PM2 process
pm2 kill

# Remove Docker stack
docker stack rm ubin

# Clean up Docker images and volumes (optional)
docker system prune -a
```

## Troubleshooting

### Container Fails to Start

```bash
# Check container logs
docker service logs ubin_orderer

# Inspect specific container
docker ps -a
docker logs <container_id>
```

### API Connection Issues

```bash
# Verify API is running
pm2 status

# Check API logs
pm2 logs ubin-api

# Restart API
pm2 restart ubin-api
```

### Port Already in Use

```bash
# Find process using port
lsof -i :<port_number>

# Kill the process if necessary
kill -9 <pid>
```

### Insufficient Disk Space

```bash
# Check disk usage
df -h

# Clean up Docker
docker system prune -a

# Remove unused volumes
docker volume prune
```

## Performance Considerations for Single VM

When running all components in a single VM, consider:

1. **Resource Allocation**: Allocate sufficient CPU and memory to Docker
   ```bash
   # Set Docker memory limit (example: 12GB)
   docker info | grep Memory
   ```

2. **Network Performance**: All communication is localhost-based; no network latency

3. **Storage**: CouchDB databases for all peers will consume significant disk space

4. **Scalability**: Not suitable for production; intended for development and testing

## Next Steps

After successful setup:

1. Run test scripts using Postman (see [tests/postman](tests/postman) folder)
2. Deploy the UI from [`ubin-ui`](https://github.com/project-ubin/ubin-ui)
3. Set up the external service from [`ubin-ext-service`](https://github.com/project-ubin/ubin-ext-service)
4. Execute transactions through the REST API

## Additional Resources

- **Project Ubin Phase 2 Report**: [bit.ly/ubin2017rpt](http://bit.ly/ubin2017rpt)
- **Hyperledger Fabric Documentation**: [hyperledger.readthedocs.io](https://hyperledger.readthedocs.io)
- **Docker Documentation**: [docs.docker.com](https://docs.docker.com)

## Support

For issues or questions:
- Review the main [README.md](README.md)
- Check the [Hyperledger Fabric documentation](https://hyperledger-fabric.readthedocs.io/)
- Refer to container logs for detailed error messages

---

**Last Updated**: 2026-06-17  
**Compatibility**: Ubin Fabric 1.0.1, Docker 17.09+, Node.js 6.9.5+
