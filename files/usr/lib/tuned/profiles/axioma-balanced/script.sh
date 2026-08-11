#!/usr/bin/bash
. /usr/lib/tuned/functions
start() {
    if systemctl is-enabled --quiet scx_loader.service; then
        scxctl switch -m auto
    fi
    return 0
}
stop() { return 0; }
process "$@"

