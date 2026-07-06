#!/bin/sh
# BeatFinder container entrypoint.
#
# Hosts like Render mount persistent disks at runtime owned by root, which
# hides any build-time ownership of the mount point. When the container
# starts as root, prepare the state directory and drop privileges to the
# non-root runtime user; when already non-root, run as-is.
set -e

STATE_DIR="${BEATFINDER_STATE_DIR:-/data}"

if [ "$(id -u)" = "0" ]; then
    mkdir -p "$STATE_DIR"
    chown -R beatfinder:beatfinder "$STATE_DIR"
    exec gosu beatfinder "$@"
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true
exec "$@"
