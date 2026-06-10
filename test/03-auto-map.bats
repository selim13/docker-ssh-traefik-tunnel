#!/usr/bin/env bats
load 'test_helper/common'

@test "auto-map: http port generates correct router, service, and backend url" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" --base-domain tunnel.local
    assert_output --partial "tunnel-${P1}"
    assert_output --partial "${P1}.tunnel.local"
    assert_output --partial "- web"
    refute_output --partial "tls:"
    assert_output --partial "url: \"http://$(hostname):${P1}\""
    assert_output --partial "Active tunnels"
}

@test "auto-map: https scheme uses websecure entrypoint and certResolver" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --base-domain tunnel.local --scheme https --cert-resolver letsencrypt
    assert_output --partial "- websecure"
    assert_output --partial "certResolver: letsencrypt"
}

@test "auto-map: custom base domain applied" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" --base-domain alt.example.com
    assert_output --partial "${P1}.alt.example.com"
}
