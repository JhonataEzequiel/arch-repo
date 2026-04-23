keep_alive(){
    echo "This script requires administrator privileges."
    sudo -v || { echo "ERROR: sudo authentication failed."; exit 1; }

    ( while true; do sudo -v; sleep 60; done ) &
    _SUDO_KEEPALIVE_PID=$!

    _cleanup() {
        kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null
        sudo -k
    }

    trap '_cleanup; echo ""; echo "ERROR: failed at line $LINENO (exit code $?). Check the output above." >&2' ERR
    trap '_cleanup' EXIT
}