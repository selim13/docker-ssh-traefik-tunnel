# SSH to Traefik Tunnel

A self-hosted SSH tunnel server that automatically exposes forwarded ports as
HTTP/HTTPS subdomains through Traefik. 

Run a service locally, forward it over SSH,
and it appears at `https://<port>.tunnel.example.com` - no client-side tools
beyond a standard SSH client required.

## Usage

- Set up a Docker container and Traefik on your server,
  see [docker-compose.example.yml](./docker-compose.example.yml) for an example.
- Expose a local web app at port 3000 under 8080.tunnel.example.com:
  `ssh -N -R 8080:localhost:3000 tunnel@server-ip -p 2222`
- Observe your local service on `https://8080.tunnel.example.com`.

## Port mapping

### Auto-mapping

With `AUTO_MAP_ENABLED=true`, any forwarded port is automatically mapped to
`<port>.<AUTO_MAP_BASE_DOMAIN>`:

```bash
ssh -N -R 8080:localhost:3000 tunnel@vds -p 2222  # → https://8080.tunnel.example.com
ssh -N -R 9090:localhost:8080 tunnel@vds -p 2222  # → https://9090.tunnel.example.com
```

You will probably want to issue a wildcard certificate like `*.tunnel.example.com`
for convenience.


### Manual mapping

Set `PORT_MAPPINGS` to override specific ports with custom domains:
`PORT_MAPPINGS="8080:https://myapp.example.com,9090:http://api.example.com"`.

Manual mappings take precedence over auto-mapping. Ports not listed in
`PORT_MAPPINGS` still auto-map if `AUTO_MAP_ENABLED=true`.

## Environment

- `TUNNEL_HOST` (default: hostname) - used as the Traefik backend URL, usually should match service's name
- `AUTO_MAP_ENABLED` (default: `true`) - auto-map `<port>.<AUTO_MAP_BASE_DOMAIN>`
- `AUTO_MAP_BASE_DOMAIN` - base domain for auto-mapping, e.g.: `tunnel.example.com`
- `AUTO_MAP_SCHEME` (default: `http`) - scheme for auto-mapped ports: `http` or `https`
- `PORT_MAPPINGS` - manual port → URL: `8080:https://svc.example.com,9090:http://api.example.com`
- `EXCLUDE_PORTS` - ports to never expose: `9000,9001`
- `WATCH_PORT_MIN` (default: `1024`) - ignore ports below this value
- `WATCH_PORT_MAX` (default: below ephemeral range) - ignore ports above this value
- `TRAEFIK_DYNAMIC_FILE` (default: `/conf.d/traefik/dynamic.yml`) - output path on shared volume
- `TRAEFIK_HTTPS_ENTRYPOINT` (default: `websecure`) - Traefik entrypoint for HTTPS routers
- `TRAEFIK_HTTP_ENTRYPOINT` (default: `web`) - Traefik entrypoint for HTTP routers
- `TRAEFIK_CERT_RESOLVER` (default: empty) - ACME resolver name in Traefik static config; set to use a specific resolver (e.g. `letsencrypt`), leave empty to use Traefik's default cert

## Volumes

- `/etc/ssh` - SSH host keys; mount a named volume to persist across restarts
- `/conf.d/authorized_keys` - standard `authorized_keys` file (mount read-only)
- `/conf.d/traefik/` - Traefik dynamic config output; mount shared with Traefik

## AI usage scale

🤖💩 5/5 - pure slop.

## Attribution

Based on [hermsi/alpine-sshd](https://github.com/Hermsi1337/docker-sshd) by Hermsi1337.