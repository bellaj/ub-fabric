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
  python3-pip \
  git

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) GO_ARCH=amd64 ;;
  aarch64|arm64) GO_ARCH=arm64 ;;
  *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

echo
echo "==============================================="
echo " Installing Go (${GO_ARCH})"
echo "==============================================="
echo

GO_VERSION="1.22.6"
GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"

wget "https://go.dev/dl/${GO_TARBALL}"
sudo rm -rf /usr/local/go
sudo tar -zxvf "${GO_TARBALL}" -C /usr/local/
rm "${GO_TARBALL}"

mkdir -p "$HOME/go/src"
grep -q 'export GOPATH=' ~/.bashrc || echo 'export GOPATH=$HOME/go' >> ~/.bashrc
grep -q '/usr/local/go/bin' ~/.bashrc || echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
export PATH="$PATH:/usr/local/go/bin"
export GOPATH="$HOME/go"

echo
echo "==============================================="
echo " Installing Node.js 16 (via nvm)"
echo "==============================================="
echo

export NVM_DIR="$HOME/.nvm"
if [ ! -d "${NVM_DIR}" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck disable=SC1091
[ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
nvm install 16
nvm alias default 16
nvm use 16
npm install -g pm2@5

echo
echo "==============================================="
echo " Installing Docker (if missing)"
echo "==============================================="
echo

if ! command -v docker >/dev/null 2>&1; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "${USER}"
else
  echo "Docker already installed: $(docker --version)"
fi

echo
echo "==============================================="
echo " Verifying Installations"
echo "==============================================="
echo

echo -n "Go:      "; /usr/local/go/bin/go version
echo -n "Node:    "; node --version
echo -n "npm:     "; npm --version
echo -n "pm2:     "; pm2 --version
echo -n "Docker:  "; docker --version

echo
echo "Link repo into GOPATH (if cloned elsewhere):"
echo "  ln -sfn \$(pwd) \$GOPATH/src/ubin-fabric"
echo
echo "===== Initial setup complete. Log out/in for docker group, then run network/start-single-vm.sh ====="
