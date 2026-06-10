#!/usr/bin/env bats
load 'test_helper/common'

@test "no active ports: outputs empty config and logs message" {
    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" --base-domain t.local
    assert_success
    assert_output --partial "routers: {}"
    assert_output --partial "services: {}"
    assert_output --partial "No active tunnels"
}
