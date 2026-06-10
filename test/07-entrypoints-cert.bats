#!/usr/bin/env bats
load 'test_helper/common'

@test "custom http entrypoint name is used in config" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --base-domain t.local --scheme http --http-entrypoint myhttp
    assert_output --partial "- myhttp"
}

@test "custom https entrypoint name is used in config" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --base-domain t.local --scheme https --https-entrypoint myhttps
    assert_output --partial "- myhttps"
}

@test "custom cert resolver name is used in config" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --base-domain t.local --scheme https --cert-resolver myresolver
    assert_output --partial "certResolver: myresolver"
}

@test "--no-cert-resolver: tls block present, certResolver absent" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --base-domain t.local --scheme https --no-cert-resolver
    assert_output --partial "tls: {}"
    refute_output --partial "certResolver:"
}
