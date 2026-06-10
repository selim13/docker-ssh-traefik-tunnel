#!/usr/bin/env bats
load 'test_helper/common'

@test "mapping precedence: manual mapping wins over auto-map domain" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --base-domain auto.local \
        --mappings "${P1}:https://manual.example.com"
    assert_output --partial "manual.example.com"
    refute_output --partial "${P1}.auto.local"
}

@test "--no-auto-map: unmapped port produces empty config" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" --no-auto-map
    assert_output --partial "routers: {}"
}

@test "--no-auto-map: explicit PORT_MAPPINGS entry still works" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --no-auto-map --mappings "${P1}:https://explicit.example.com"
    assert_output --partial "explicit.example.com"
}
