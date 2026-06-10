#!/usr/bin/env bats
load 'test_helper/common'

@test "watch mode: detects port changes and updates config file" {
    local wf="${BATS_TEST_TMPDIR}/watch-dynamic.yml"

    "$SCRIPT" --watch --interval 1 \
        --output "$wf" \
        --base-domain watch.local \
        --port-min "$P1" --port-max "$P1" \
        >/dev/null 2>&1 &
    local watcher=$!
    _listeners="${_listeners} ${watcher}"
    sleep 0.5

    # No listener yet — initial write should produce empty config
    assert_file_has "$wf" "routers: {}"

    # Bring a port up and wait for detection
    listen_on "$P1"
    # shellcheck disable=SC2154  # _last_pid set by listen_on in common.bash
    local listener_pid=$_last_pid
    sleep 2
    assert_file_has "$wf" "tunnel-${P1}"
    assert_file_has "$wf" "${P1}.watch.local"

    # Remove the listener and wait for detection
    kill_listener "$listener_pid"
    sleep 2
    refute_file_has "$wf" "tunnel-${P1}"
}
