#!/bin/bash

BASELINK="https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/"
NODE_HOME="${HOME}/cardano-node"

# # Mainnet
echo "Downloading mainnet files..."
mkdir -p ${NODE_HOME}/config
curl -sSL ${BASELINK}mainnet-config.json -o ${NODE_HOME}/config/config.json
curl -sSL ${BASELINK}mainnet-alonzo-genesis.json -o ${NODE_HOME}/config/mainnet-alonzo-genesis.json
curl -sSL ${BASELINK}mainnet-shelley-genesis.json -o ${NODE_HOME}/config/mainnet-shelley-genesis.json
curl -sSL ${BASELINK}mainnet-byron-genesis.json -o ${NODE_HOME}/config/mainnet-byron-genesis.json
curl -sSL ${BASELINK}mainnet-topology.json -o ${NODE_HOME}/config/topology.json
