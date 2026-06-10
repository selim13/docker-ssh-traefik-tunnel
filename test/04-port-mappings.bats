#!/usr/bin/env bats
load 'test_helper/common'

@test "mappings: https custom domain with certResolver, auto-map domain absent" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --no-auto-map --cert-resolver letsencrypt \
        --mappings "${P1}:https://myapp.example.com"
    assert_output --partial "Host(\`myapp.example.com\`)"
    assert_output --partial "- websecure"
    assert_output --partial "certResolver: letsencrypt"
    refute_output --partial "${P1}.tunnel.example.com"
}

@test "mappings: http custom domain, no tls block" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --no-auto-map --mappings "${P1}:http://myapp.example.com"
    assert_output --partial "Host(\`myapp.example.com\`)"
    assert_output --partial "- web"
    refute_output --partial "tls:"
}

@test "mappings: port not listening is absent from config" {
    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --no-auto-map --mappings "${P1}:https://myapp.example.com"
    refute_output --partial "myapp.example.com"
}

@test "mappings: missing scheme prefix logs error and skips port" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --no-auto-map --mappings "${P1}:myapp.example.com"
    assert_output --partial "ERROR"
    assert_output --partial "scheme"
    assert_output --partial "routers: {}"
}
