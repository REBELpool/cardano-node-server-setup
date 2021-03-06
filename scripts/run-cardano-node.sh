#!/bin/bash
# run-cardano-node
# Arguments:
#   1 - node mode: Node operation mode, "relay" or "pool" [default: relay]
#   2 - node port [default: 3001]
#   3 - host address [default: 0.0.0.0]

# Default parameters
NODE_HOME="/home/rebel"
CARDANO_NODE="/home/rebel/.local/bin/cardano-node"

if [ $# -ge 1 ]; then
  NODE_MODE=$1
else
  NODE_MODE="relay"
fi

if [ $# -ge 2 ]; then
  NODE_PORT=$2
else
  NODE_PORT=3001
fi

if [ $# -ge 3 ]; then
  HOST_ADDR=$3
else
  HOST_ADDR="x.x.x.x"
fi

echo "Running cardano-node with the following parameters:"
echo "  CARDANO_NODE = $CARDANO_NODE"
echo "  NODE_HOME = $NODE_HOME"
echo "  NODE_MODE = $NODE_MODE"
echo "  NODE_PORT = $NODE_PORT"
echo "  HOST_ADDR = $HOST_ADDR"

if [ "$NODE_MODE" = "relay" ]; then
  eval $CARDANO_NODE run \
    --database-path $NODE_HOME/cardano-node/db/ \
    --socket-path $NODE_HOME/cardano-node/db/node.socket \
    --port $NODE_PORT \
    --host-addr $HOST_ADDR \
    --config $NODE_HOME/cardano-node/config/config.json \
    --topology $NODE_HOME/cardano-node/config/topology.json
elif [ "$NODE_MODE" = "pool" ]; then
  eval $CARDANO_NODE run \
    --database-path $NODE_HOME/cardano-node/db/ \
    --socket-path $NODE_HOME/cardano-node/db/node.socket \
    --host-addr $HOST_ADDR \
    --port $NODE_PORT \
    --config $NODE_HOME/cardano-node/config/config.json \
    --topology $NODE_HOME/cardano-node/config/topology.json \
    --shelley-kes-key $NODE_HOME/cardano-node/priv/kes.skey \
    --shelley-vrf-key $NODE_HOME/cardano-node/priv/vrf.skey \
    --shelley-operational-certificate $NODE_HOME/cardano-node/priv/node.cert
fi
