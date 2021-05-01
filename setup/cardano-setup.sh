#!/bin/bash
# This script sets up the node for use as a stake pool.

# Remove autostart file
sed -i '$d' ${HOME}/.bashrc

CARDANO_CONFIG="https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/"
NODE_HOME="${HOME}/cardano-node"

# Mainnet config
echo "Downloading mainnet files..."
mkdir -p ${NODE_HOME}/config
curl -sSL ${CARDANO_CONFIG}mainnet-config.json -o ${NODE_HOME}/config/config.json
curl -sSL ${CARDANO_CONFIG}mainnet-shelley-genesis.json -o ${NODE_HOME}/config/mainnet-shelley-genesis.json
curl -sSL ${CARDANO_CONFIG}mainnet-byron-genesis.json -o ${NODE_HOME}/config/mainnet-byron-genesis.json
curl -sSL ${CARDANO_CONFIG}mainnet-topology.json -o ${NODE_HOME}/config/topology.json

# Make folder for build
mkdir -p ~/src

# Install dependencies
sudo apt-get install git jq bc make automake rsync htop curl build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ wget libncursesw5 libtool autoconf -y

# Install Libsodium
cd ~/src
git clone https://github.com/input-output-hk/libsodium
cd libsodium
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install
sudo ln -s /usr/local/lib/libsodium.so.23.3.0 /usr/lib/libsodium.so.23

# Install dependencies
sudo apt-get -y install pkg-config libgmp-dev libssl-dev libtinfo-dev libsystemd-dev libgmp10 zlib1g-dev build-essential curl libffi6 libffi-dev libncurses-dev libtinfo5 libncurses5 

# Install Cabal
cd ~/src
wget https://hackage.haskell.org/package/cabal-install-3.4.0.0/cabal-install-3.4.0.0.tar.gz
tar -xf cabal-install-3.4.0.0.tar.gz
rm cabal-install-3.4.0.0.tar.gz
mv cabal ${HOME}/.local/bin/
cabal update

# Install GHC Compiler
cd ~/src
wget https://downloads.haskell.org/~ghc/8.10.4/ghc-8.10.4-x86_64-deb10-linux.tar.xz
tar -xf ghc-8.10.4-x86_64-deb10-linux.tar.xz
cd ghc-8.10.4
./configure
sudo make install

# Verify cabal & ghc
cabal update
cabal --version
ghc --version

# Instal Cardano Node
TAG=1.26.2
mkdir -p ~/src
cd ~/src
git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node 
git fetch --all --recurse-submodules --tags
git checkout tags/${TAG}
cabal configure --with-compiler=ghc-8.10.2
echo <<EOF | tee -a cabal.project.local
package cardano-crypto-praos
  flags: -external-libsodium-vrf
EOF
cabal build all
cabal install --installdir ${HOME}/.local/bin cardano-cli cardano-node
cardano-node version
cardano-cli version

# Setup Cardano-node.service
mv $CNODE_HOME/scripts/run-cardano-node.sh $CNODE_HOME
cat > $CNODE_HOME/cardano-node.service << EOF 
# The Cardano node service (part of systemd)
# file: /etc/systemd/system/cardano-node.service 

[Unit]
Description         = Cardano node service
Wants               = network-online.target
After               = network-online.target 

[Service]
User                = ${USER}
Type                = simple
WorkingDirectory    = ${CNODE_HOME}
ExecStart           = /bin/bash -c '${CNODE_HOME}/run-cardano-node.sh'
StandardOutput      = syslog
StandardError       = syslog
SyslogIdentifier    = cardano-node
KillSignal          = SIGINT
TimeoutStopSec      = 2
LimitNOFILE         = 131072
Restart             = always
RestartSec          = 5

[Install]
WantedBy	        = multi-user.target
EOF
sudo mv $CNODE_HOME/cardano-node.service /etc/systemd/system/cardano-node.service
sudo chmod 644 /etc/systemd/system/cardano-node.service
sudo systemctl daemon-reload
sudo systemctl enable cardano-node

# Setup gLiveView
cd $CNODE_HOME
sudo apt install bc tcptraceroute -y
curl -s -o gLiveView.sh https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/gLiveView.sh
curl -s -o env https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/env
chmod 755 gLiveView.sh
sed -i env \
    -e "s/\#CONFIG=\"\${CCNODE_HOME}\/files\/config.json\"/CONFIG=\"\${CNODE_HOME}\/config/config.json\"/g" \
    -e "s/\#SOCKET=\"\${CCNODE_HOME}\/sockets\/node0.socket\"/SOCKET=\"\${CNODE_HOME}\/db\/node.socket\"/g"

# Cleaning
sudo rm ${HOME}/cardano-setup.sh
sudo rm -rf ${HOME}/src
