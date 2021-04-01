#!/bin/bash

sudo journalctl --unit=cardano-node --follow | ccze -A -o nolookups