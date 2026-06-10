#!/usr/bin/env bats
load 'test_helper/common'

@test "--host: backend url uses custom host name" {
    listen_on "$P1"

    run "$SCRIPT" --dry-run --port-min "$P1" --port-max "$P1" \
        --base-domain t.local --host mycontainer
    assert_output --partial "url: \"http://mycontainer:${P1}\""
}

@test "output file: written with correct content, no .tmp leftover" {
    listen_on "$P1"
    local outfile="${BATS_TEST_TMPDIR}/nested/dir/dynamic.yml"

    run "$SCRIPT" --port-min "$P1" --port-max "$P1" \
        --base-domain t.local --output "$outfile"
    assert_success
    assert_file_has "$outfile" "tunnel-${P1}"
    assert_file_has "$outfile" "${P1}.t.local"
    [ ! -f "${outfile}.tmp" ]
}

@test "output file: cleared to empty config when no ports are listening" {
    local outfile="${BATS_TEST_TMPDIR}/dynamic.yml"

    run "$SCRIPT" --port-min "$P1" --port-max "$P1" --output "$outfile" --base-domain t.local
    assert_file_has "$outfile" "routers: {}"
}
