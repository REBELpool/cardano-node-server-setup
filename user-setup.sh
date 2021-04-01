#!/bin/bash
# This script sets up the node for use as a stake pool.

# Remove autostart file
sed -i '$d' ${HOME}/.bashrc

# Setup local bin folder
echo "Setting local 'bin' folder for Cardano apps"
mkdir -p $HOME/.local/bin
echo 'export PATH="~/.local/bin:$PATH"' | tee -a ~/.bashrc

# Setup Locale
echo "Setting LANG"
cat <<EOF | tee -a ${HOME}/.bashrc
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
EOF

# Setup library folders
echo "Setting PATH for lib files"
cat <<EOF | tee -a ${HOME}/.bashrc
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
EOF

# Setup Cardano node path
echo "Setting PATH for cardano node setup"
cat <<EOF | tee -a ${HOME}/.bashrc
export NODE_HOME="$HOME/cardano-node"
export CNODE_HOME="$HOME/cardano-node" # For CNCLI scripts
export CARDANO_NODE_SOCKET_PATH="$HOME/cardano-node/db/node.socket"
export NODE_CONFIG="mainnet"
EOF

# Disabling root account
echo "Disabling 'root' account"
sudo passwd -l root

# Cleaning after setup
rm user-setup.sh

# Add autostart script
echo "tmux new-session -d -s "Cardano" ~/cardano-setup.sh" | tee -a $HOME/.bashrc

# Reboot
sudo shutdown -r 0