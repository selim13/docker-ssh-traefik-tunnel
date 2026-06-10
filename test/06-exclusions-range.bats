#!/usr/bin/env bats
load 'test_helper/common'

@test "exclude: single excluded port absent, other port present" {
    listen_on "$P1"
    listen_on "$P2"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P2" \
        --base-domain t.local --exclude "$P2"
    assert_output --partial "tunnel-${P1}"
    refute_output --partial "tunnel-${P2}"
}

@test "exclude: multiple ports all excluded yields empty config" {
    listen_on "$P1"
    listen_on "$P2"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P2" \
        --base-domain t.local --exclude "${P1},${P2}"
    assert_output --partial "routers: {}"
}

@test "port range: ports outside --port-min/--port-max are ignored" {
    listen_on "$P1"
    listen_on "$P2"
    listen_on "$P3"

    run "$SCRIPT" --dry-run --port-min "$P2" --port-max "$P2" --base-domain t.local
    refute_output --partial "tunnel-${P1}"
    assert_output --partial  "tunnel-${P2}"
    refute_output --partial "tunnel-${P3}"
}
