#!/usr/bin/env bats
load 'test_helper/common'

@test "--help exits 0 and shows usage" {
    run "$SCRIPT" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "--watch"
    assert_output --partial "--dry-run"
}

@test "unknown flag exits 1 with error message" {
    run "$SCRIPT" --unknown-flag
    assert_failure
    assert_output --partial "Unknown option"
}

@test "auto-map enabled without base domain exits 1 with error" {
    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1"
    assert_failure
    assert_output --partial "ERROR"
    assert_output --partial "AUTO_MAP_BASE_DOMAIN"
}
