#!/bin/bash

tail -f ${NODE_HOME}/logs/node.json | ccze -A -o nolookups
