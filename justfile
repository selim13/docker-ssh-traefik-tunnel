test_compose := "docker compose -f docker-compose.test.yml"

default:
    @just --list

# ── keys ──────────────────────────────────────────────────────────────────────

# Generate test SSH keypair (run once before `just up`)
[group('test')]
keygen:
    @[ -f test/keys/id_ed25519 ] && echo "Keys already exist" || \
        ssh-keygen -t ed25519 -N "" -f test/keys/id_ed25519 -C "tunnel-test"

# ── lint ──────────────────────────────────────────────────────────────────────

[group('lint')]
lint:
    shellcheck -S warning -s ash  entrypoint.sh tunnel-to-traefik.sh
    shellcheck -S warning -s bash test/test_helper/common.bash test/*.bats
    hadolint Dockerfile
    docker compose -f docker-compose.example.yml config --quiet
    docker compose -f docker-compose.test.yml config --quiet

# ── build ─────────────────────────────────────────────────────────────────────

[group('build')]
build:
    {{ test_compose }} build

[group('build')]
build-no-cache:
    {{ test_compose }} build --no-cache

# ── test ──────────────────────────────────────────────────────────────────────

[group('test')]
test:
    test/bats/bin/bats test/

[group('test')]
up:
    {{ test_compose }} up --force-recreate --build

[group('test')]
down:
    {{ test_compose }} down

[group('test')]
logs:
    {{ test_compose }} logs -f

[group('test')]
shell:
    docker exec -it sshd-web-tunnel-test /bin/ash

[group('test')]
forward port="8080":
    ssh -N -R {{ port }}:localhost:{{ port }} \
        -i test/keys/id_ed25519 \
        -p 2222 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        tunnel@localhost
