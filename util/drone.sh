#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
SSH_SIDE="TCP:${SSH_HOST:-localhost}:${SSH_PORT:-22}"
HIVE_SIDE="PROXY:${HIVE_HOST:-localhost}"
HIVE_SIDE+=":${REQ_HOST:-rev-ssh.test}:${REQ_PORT:-0}"
HIVE_SIDE+=",proxyport=${HIVE_PORT:-1212}"
exec -a revssh-drone socat "$SSH_SIDE" "$HIVE_SIDE"; exit $?
