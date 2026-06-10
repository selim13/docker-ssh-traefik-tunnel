# Shared helpers loaded by every .bats file.
# Paths passed to `load` resolve relative to $BATS_TEST_DIRNAME (the .bats file).

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/bats-file/load'

export SCRIPT="${BATS_TEST_DIRNAME}/../tunnel-to-traefik.sh"

# Test ports — far from common services, below the ephemeral range
P1=18800
P2=18801
P3=18802

# Per-test listener tracking (lives in each test's subshell)
_listeners=""

# ── lifecycle ─────────────────────────────────────────────────────────────────

# Kill any stale listeners left by a previous interrupted run (called once per file)
kill_stale_listeners() {
    local port pids pid
    for port in $P1 $P2 $P3; do
        pids=$(ss -tlnp "sport = :${port}" 2>/dev/null \
            | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u || true)
        for pid in $pids; do
            kill "$pid" 2>/dev/null || true
        done
    done
    sleep 0.3
}

setup_file() { kill_stale_listeners; }

teardown() { kill_all_listeners; }

# ── listener helpers ──────────────────────────────────────────────────────────

# Start a TCP listener on $1. Sets _last_pid; appends to _listeners.
listen_on() {
    local port="$1"
    python3 -c "
import socket, time, sys
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('', ${port}))
s.listen(1)
sys.stdout.flush()
time.sleep(60)
" 2>/dev/null &
    _last_pid=$!
    _listeners="${_listeners} ${_last_pid}"
    sleep 0.3
}

# Kill a specific listener by PID and remove it from _listeners.
kill_listener() {
    kill -9 "$1" 2>/dev/null || true
    sleep 0.2
    local new="" p
    for p in $_listeners; do
        [ "$p" = "$1" ] || new="${new} ${p}"
    done
    _listeners="$new"
}

# Kill all registered listeners.
kill_all_listeners() {
    local p
    for p in $_listeners; do
        kill -9 "$p" 2>/dev/null || true
    done
    [ -n "${_listeners}" ] && sleep 0.2
    _listeners=""
}

# ── file assertion helpers (fixed-string, not regex) ─────────────────────────

assert_file_has() {
    if [ ! -f "$1" ]; then
        batslib_print_kv_single 4 'path' "$1" \
            | batslib_decorate 'file does not exist' \
            | fail
        return
    fi
    if ! grep -qF -- "$2" "$1"; then
        batslib_print_kv_single 8 'path' "$1" 'needle' "$2" \
            | batslib_decorate 'file does not contain string' \
            | fail
    fi
}

refute_file_has() {
    if [ -f "$1" ] && grep -qF -- "$2" "$1"; then
        batslib_print_kv_single 8 'path' "$1" 'needle' "$2" \
            | batslib_decorate 'file contains unexpected string' \
            | fail
    fi
}
