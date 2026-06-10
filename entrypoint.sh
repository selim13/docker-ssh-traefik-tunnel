#!/bin/busybox ash
set -e

if [ "${DEBUG}" = "true" ]; then
    set -x
fi

log() { echo "[entrypoint] ${1}"; }

# set_sshd_option <key> <value>
# Removes any existing line for <key> (commented or not) then appends the new
# value. Handles stock Alpine sshd_config shipping directives commented-out.
set_sshd_option() {
    sed -i "/^#\?${1}[[:space:]].*/d" /etc/ssh/sshd_config
    echo "${1} ${2}" >> /etc/ssh/sshd_config
}

if [ ! -f "/etc/ssh/sshd_config" ]; then
    cp -a "${CACHED_SSH_DIRECTORY}"/* /etc/ssh/.
fi

ssh-keygen -A 1>/dev/null

# Copy authorized keys to a root-owned path — avoids sshd StrictModes rejecting
# bind-mounted files whose ownership/permissions don't match what sshd expects.
_keys_dst="/etc/ssh/authorized_keys"
if [ -f "${AUTHORIZED_KEYS_FILE}" ]; then
    cp "${AUTHORIZED_KEYS_FILE}" "${_keys_dst}"
    chmod 644 "${_keys_dst}"
else
    log "WARNING: ${AUTHORIZED_KEYS_FILE} not found — no keys loaded"
    : > "${_keys_dst}"
    chmod 644 "${_keys_dst}"
fi

set_sshd_option "PermitRootLogin"        "no"
set_sshd_option "PasswordAuthentication" "no"
set_sshd_option "AuthorizedKeysFile"     "${_keys_dst}"
set_sshd_option "AllowTcpForwarding"     "yes"
set_sshd_option "GatewayPorts"           "yes"

log "authorized keys : ${AUTHORIZED_KEYS_FILE} → ${_keys_dst}"
log "GatewayPorts=yes, AllowTcpForwarding=yes, PasswordAuthentication=no"

_watcher_pid=""
if [ "${WATCHER_ENABLED}" = "true" ]; then
    log "starting tunnel watcher ..."
    /tunnel-to-traefik.sh --watch &
    _watcher_pid=$!
fi

# Stay as PID 1 so we can forward signals and give the watcher time to clean up.
# On TERM/INT, stop sshd; after sshd exits we signal the watcher and wait for it.
_sshd_pid=""
_stop() { [ -n "${_sshd_pid}" ] && kill "${_sshd_pid}" 2>/dev/null || true; }
trap _stop TERM INT

/usr/sbin/sshd -D -e "$@" &
_sshd_pid=$!
wait "${_sshd_pid}" || true

if [ -n "${_watcher_pid}" ]; then
    kill "${_watcher_pid}" 2>/dev/null || true
    wait "${_watcher_pid}" 2>/dev/null || true
fi
