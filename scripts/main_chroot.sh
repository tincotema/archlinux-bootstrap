#!/bin/bash

[[ "${EXECUTED_IN_CHROOT}" != true ]] \
	&& { echo "This script must not be executed directly!" >&2; exit 1; }

# Source the systems profile
source /etc/profile

# Set safe umask
umask 0077

# Export nproc variables
export NPROC="$(nproc || echo 2)"
export NPROC_ONE="$(($NPROC + 1))"

# Set default makeflags and emerge flags for parallel emerges
export MAKEFLAGS="-j$NPROC"
export EMERGE_DEFAULT_OPTS="--jobs=$NPROC_ONE --load-average=$NPROC"

# Execute the requested command
exec "$@"
