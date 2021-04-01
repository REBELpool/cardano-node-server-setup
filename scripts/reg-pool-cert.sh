#!/bin/bash

cardano-cli stake-pool registration-certificate \
    --cold-verification-key-file $HOME/cold-keys/node.vkey \
    --vrf-verification-key-file vrf.vkey \
    --pool-pledge 3000000000 \
    --pool-cost 340000000 \
    --pool-margin 0.039 \
    --pool-reward-account-verification-key-file stake.vkey \
    --pool-owner-stake-verification-key-file stake.vkey \
    --mainnet \
    --multi-host-pool-relay nodes.rebelscum.dev\
    --pool-relay-port 3001 \
    --metadata-url https://rebelscum.dev/poolMetaData.json \
    --metadata-hash $(cat poolMetaDataHash.txt) \
    --out-file pool.cert