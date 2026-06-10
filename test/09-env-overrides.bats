#!/usr/bin/env bats
load 'test_helper/common'

@test "env TUNNEL_HOST and AUTO_MAP_BASE_DOMAIN are respected" {
    listen_on "$P1"

    TUNNEL_HOST=envhost AUTO_MAP_BASE_DOMAIN=env.local \
        run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1"
    assert_output --partial "url: \"http://envhost:${P1}\""
    assert_output --partial "${P1}.env.local"
}

@test "env AUTO_MAP_ENABLED=false disables auto-mapping" {
    listen_on "$P1"

    AUTO_MAP_ENABLED=false \
        run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1"
    assert_output --partial "routers: {}"
}

@test "env PORT_MAPPINGS applies manual domain" {
    listen_on "$P1"

    PORT_MAPPINGS="${P1}:https://env-manual.example.com" \
        run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" --base-domain t.local
    assert_output --partial "env-manual.example.com"
}

@test "env EXCLUDE_PORTS skips the port" {
    listen_on "$P1"

    EXCLUDE_PORTS="$P1" \
        run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" --base-domain t.local
    assert_output --partial "routers: {}"
}

@test "CLI --base-domain overrides AUTO_MAP_BASE_DOMAIN env var" {
    listen_on "$P1"

    AUTO_MAP_BASE_DOMAIN=from-env.local \
        run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" --base-domain from-cli.local
    assert_output --partial "${P1}.from-cli.local"
    refute_output --partial "from-env.local"
}

@test "CLI --host overrides TUNNEL_HOST env var" {
    listen_on "$P1"

    TUNNEL_HOST=envhost \
        run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" --base-domain t.local --host clihost
    assert_output --partial "url: \"http://clihost:${P1}\""
}

@test "CLI --mappings works even when AUTO_MAP_ENABLED=false" {
    listen_on "$P1"

    AUTO_MAP_ENABLED=false \
        run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --mappings "${P1}:https://cli-map.example.com"
    assert_output --partial "cli-map.example.com"
}
