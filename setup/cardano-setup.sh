#!/bin/bash
# This script sets up the node for use as a stake pool.

# Remove autostart file
sed -i '$d' ${HOME}/.bashrc

# Make folder for build
mkdir -p ~/src

# Install dependencies
sudo apt-get install build-essential pkg-config libffi-dev libgmp-dev ccze libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ libgmp10 libffi6 libffi-dev libtinfo5  libncursesw5 libncurses-dev libtool autoconf -y

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

# Install Cabal
cd $HOME
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
reset
ghcup upgrade
ghcup install cabal 3.4.0.0
ghcup set cabal 3.4.0.0

# Install GHC Compiler
ghcup install ghc 8.10.4
ghcup set ghc 8.10.4

# Verify cabal & ghc
cabal update
cabal --version
ghc --version

# Instal Cardano Node
TAG=1.32.1
mkdir -p ~/src
cd ~/src
git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node 
git fetch --all --recurse-submodules --tags
git checkout tags/${TAG}
cabal configure -O0 -w ghc-8.10.4
echo <<EOF | tee -a cabal.project.local
package cardano-crypto-praos
  flags: -external-libsodium-vrf
EOF
sed -i $HOME/.cabal/config -e "s/overwrite-policy:/overwrite-policy: always/g"
cabal build cardano-cli cardano-node
cabal install --installdir ${HOME}/.local/bin cardano-cli cardano-node
cardano-node version
cardano-cli version

# Cardano config address
CARDANO_CONFIG="https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/"
NODE_HOME="${HOME}/cardano-node"

# Mainnet config
echo "Downloading mainnet files..."
mkdir -p ${NODE_HOME}/config
curl -sSL ${CARDANO_CONFIG}mainnet-config.json -o ${NODE_HOME}/config/config.json
curl -sSL ${CARDANO_CONFIG}mainnet-alonzo-genesis.json -o ${NODE_HOME}/config/mainnet-alonzo-genesis.json
curl -sSL ${CARDANO_CONFIG}mainnet-shelley-genesis.json -o ${NODE_HOME}/config/mainnet-shelley-genesis.json
curl -sSL ${CARDANO_CONFIG}mainnet-byron-genesis.json -o ${NODE_HOME}/config/mainnet-byron-genesis.json
curl -sSL ${CARDANO_CONFIG}mainnet-topology.json -o ${NODE_HOME}/config/topology.json


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
curl -s -o gLiveView.sh https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/gLiveView.sh ${HOME}/cardano-node/scripts/
curl -s -o env https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/env ${HOME}/cardano-node/scripts/
chmod 755 ${HOME}/cardano-node/scripts/gLiveView.sh
sed -i ${HOME}/cardano-node/scripts/env \
    -e "s/\#CONFIG=\"\${CCNODE_HOME}\/files\/config.json\"/CONFIG=\"\${CNODE_HOME}\/config/config.json\"/g" \
    -e "s/\#SOCKET=\"\${CCNODE_HOME}\/sockets\/node0.socket\"/SOCKET=\"\${CNODE_HOME}\/db\/node.socket\"/g"

# Cleaning
sudo rm ${HOME}/cardano-setup.sh
sudo rm -rf ${HOME}/src
