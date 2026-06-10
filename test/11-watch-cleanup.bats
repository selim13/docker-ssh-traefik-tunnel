#!/usr/bin/env bats
load 'test_helper/common'

@test "watch mode: SIGTERM writes inert config on exit (default)" {
    local wf="${BATS_TEST_TMPDIR}/cleanup-dynamic.yml"

    "$SCRIPT" --watch --interval 1 \
        --output "$wf" \
        --base-domain cleanup.local \
        --port-min "$P1" --port-max "$P1" \
        >/dev/null 2>&1 &
    local watcher=$!
    _listeners="${_listeners} ${watcher}"
    sleep 0.5

    listen_on "$P1"
    sleep 2
    assert_file_has "$wf" "tunnel-${P1}"

    kill -TERM "$watcher"
    wait "$watcher" 2>/dev/null || true

    assert_file_has "$wf" "routers: {}"
    refute_file_has "$wf" "tunnel-${P1}"
}

@test "watch mode: --keep-config suppresses cleanup on exit" {
    local wf="${BATS_TEST_TMPDIR}/keepflag-dynamic.yml"

    "$SCRIPT" --watch --interval 1 \
        --output "$wf" \
        --base-domain cleanup.local \
        --port-min "$P1" --port-max "$P1" \
        --keep-config \
        >/dev/null 2>&1 &
    local watcher=$!
    _listeners="${_listeners} ${watcher}"
    sleep 0.5

    listen_on "$P1"
    sleep 2
    assert_file_has "$wf" "tunnel-${P1}"

    kill -TERM "$watcher"
    wait "$watcher" 2>/dev/null || true

    assert_file_has "$wf" "tunnel-${P1}"
}

@test "watch mode: WATCH_KEEP_CONFIG=true suppresses cleanup on exit" {
    local wf="${BATS_TEST_TMPDIR}/keepenv-dynamic.yml"

    WATCH_KEEP_CONFIG=true "$SCRIPT" --watch --interval 1 \
        --output "$wf" \
        --base-domain cleanup.local \
        --port-min "$P1" --port-max "$P1" \
        >/dev/null 2>&1 &
    local watcher=$!
    _listeners="${_listeners} ${watcher}"
    sleep 0.5

    listen_on "$P1"
    sleep 2
    assert_file_has "$wf" "tunnel-${P1}"

    kill -TERM "$watcher"
    wait "$watcher" 2>/dev/null || true

    assert_file_has "$wf" "tunnel-${P1}"
}
