#!/bin/bash
# This script sets up the node for use as a stake pool.

# Remove autostart file
sed -i '$d' ${HOME}/.bashrc

# Make folder for build
mkdir -p ~/src

# Install Cabal
cd ~/src
wget https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz
tar -xf cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz
mv cabal ${HOME}/.local/bin/
cabal update

# Install GHC Compiler
cd ~/src
wget https://downloads.haskell.org/ghc/8.10.2/ghc-8.10.2-x86_64-deb9-linux.tar.xz
tar -xf ghc-8.10.2-x86_64-deb9-linux.tar.xz
cd ghc-8.10.2
./configure
sudo make install

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

# Instal Cardano Node
TAG=1.25.1
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
