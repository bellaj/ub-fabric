#!/usr/bin/env bash
set -euo pipefail

echo "==============================================="
echo " Installing Pre-Requisites"
echo "==============================================="
echo

sudo apt-get update
sudo apt-get -y install \
  build-essential \
  jq \
  curl \
  wget \
  ca-certificates \
  gnupg \
  lsb-release \
  python3 \
  python3-pip

echo
echo "==============================================="
echo " Installing Go"
echo "==============================================="
echo

GO_VERSION="1.22.4"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"

wget "https://go.dev/dl/${GO_TARBALL}"
sudo rm -rf /usr/local/go
sudo tar -zxvf "${GO_TARBALL}" -C /usr/local/
rm "${GO_TARBALL}"

mkdir -p "$HOME/go/src"

{
  echo 'export PATH=$PATH:/usr/local/go/bin'
  echo 'export GOPATH=$HOME/go'
} >> ~/.bashrc

export PATH="$PATH:/usr/local/go/bin"
export GOPATH="$HOME/go"

echo
echo "==============================================="
echo " Installing Node JS"
echo "==============================================="
echo

NODE_MAJOR=20

curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
  | sudo tee /etc/apt/sources.list.d/nodesource.list

sudo apt-get update
sudo apt-get install -y nodejs

sudo npm install pm2@latest -g

echo
echo "==============================================="
echo " Installing Docker"
echo "==============================================="
echo

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker "${USER}"

echo
echo "==============================================="
echo " Verifying Installations"
echo "==============================================="
echo

echo -n "Go:      "; /usr/local/go/bin/go version
echo -n "Node:    "; node --version
echo -n "npm:     "; npm --version
echo -n "Docker:  "; docker --version
echo -n "Compose: "; docker compose version

echo
echo "===== Initial setup complete. Please restart your machine for changes to take effect. ====="