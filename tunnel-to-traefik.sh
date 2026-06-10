#!/bin/busybox ash
set -e

# ---------------------------------------------------------------------------- #
# CLI arg parsing                                                               #
# ---------------------------------------------------------------------------- #

_arg_host=""
_arg_interval=""
_arg_output=""
_arg_https_ep=""
_arg_http_ep=""
_arg_cert_resolver=""
_arg_no_cert_resolver=false
_arg_base_domain=""
_arg_no_auto_map=false
_arg_scheme=""
_arg_mappings=""
_arg_exclude=""
_arg_port_min=""
_arg_port_max=""
_watch=false
_dry_run=false
_arg_keep_config=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Scan for listening ports and write a Traefik dynamic configuration file.
By default runs once and exits. Use --watch to poll continuously.

Options:
  --host HOST               Hostname/IP used as the Traefik backend URL
                              (env: TUNNEL_HOST, default: \$(hostname))
  --output FILE             Traefik dynamic config output path
                              (env: TRAEFIK_DYNAMIC_FILE,
                               default: /conf.d/traefik/dynamic.yml)
  --https-entrypoint NAME   Traefik HTTPS entrypoint name
                              (env: TRAEFIK_HTTPS_ENTRYPOINT, default: websecure)
  --http-entrypoint NAME    Traefik HTTP entrypoint name
                              (env: TRAEFIK_HTTP_ENTRYPOINT, default: web)
  --cert-resolver NAME      ACME cert resolver name in Traefik static config
                              (env: TRAEFIK_CERT_RESOLVER, default: letsencrypt)
  --no-cert-resolver        Omit certResolver (use Traefik's default certificate)
  --base-domain DOMAIN      Base domain for auto-mapping (<port>.<domain>)
                              (env: AUTO_MAP_BASE_DOMAIN; required when auto-map
                               is enabled)
  --no-auto-map             Disable auto-mapping of unrecognised ports
                              (env: AUTO_MAP_ENABLED=false)
  --scheme http|https       Scheme for auto-mapped ports
                              (env: AUTO_MAP_SCHEME, default: http)
  --mappings MAPPINGS       Manual port→URL mappings (scheme prefix required)
                              (env: PORT_MAPPINGS)
                              e.g. "8080:https://app.example.com,9090:http://api"
  --exclude PORTS           Comma-separated ports to never expose
                              (env: EXCLUDE_PORTS, e.g. "9000,9001")
  --port-min PORT           Ignore ports below this value
                              (env: WATCH_PORT_MIN, default: 1024)
  --port-max PORT           Ignore ports above this value
                              (env: WATCH_PORT_MAX, default: below ephemeral range)
  --watch                   Poll continuously instead of running once
  --interval SECONDS        Poll interval for --watch mode
                              (env: WATCH_INTERVAL, default: 3)
  --keep-config             Keep Traefik config as-is when watcher exits
                              (env: WATCH_KEEP_CONFIG, default: false)
  --dry-run                 Print generated config to stdout; do not write file
  --debug                   Enable shell trace output (set -x)
  -h, --help                Show this help and exit

Environment variables are read first; CLI flags take precedence.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --host)               _arg_host="$2";               shift 2 ;;
        --interval)           _arg_interval="$2";           shift 2 ;;
        --output)             _arg_output="$2";             shift 2 ;;
        --https-entrypoint)   _arg_https_ep="$2";           shift 2 ;;
        --http-entrypoint)    _arg_http_ep="$2";            shift 2 ;;
        --cert-resolver)      _arg_cert_resolver="$2";      shift 2 ;;
        --no-cert-resolver)   _arg_no_cert_resolver=true;   shift ;;
        --base-domain)        _arg_base_domain="$2";        shift 2 ;;
        --no-auto-map)        _arg_no_auto_map=true;        shift ;;
        --scheme)             _arg_scheme="$2";             shift 2 ;;
        --mappings)           _arg_mappings="$2";           shift 2 ;;
        --exclude)            _arg_exclude="$2";            shift 2 ;;
        --port-min)           _arg_port_min="$2";           shift 2 ;;
        --port-max)           _arg_port_max="$2";           shift 2 ;;
        --watch)              _watch=true;                  shift ;;
        --keep-config)        _arg_keep_config=true;        shift ;;
        --dry-run)            _dry_run=true;                shift ;;
        --debug)              set -x;                       shift ;;
        -h|--help)            usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------- #
# Resolve configuration: CLI flags override env vars, env vars override defaults #
# ---------------------------------------------------------------------------- #

TUNNEL_HOST="${_arg_host:-${TUNNEL_HOST:-$(hostname)}}"
WATCH_INTERVAL="${_arg_interval:-${WATCH_INTERVAL:-3}}"
TRAEFIK_DYNAMIC_FILE="${_arg_output:-${TRAEFIK_DYNAMIC_FILE:-/conf.d/traefik/dynamic.yml}}"
TRAEFIK_HTTPS_ENTRYPOINT="${_arg_https_ep:-${TRAEFIK_HTTPS_ENTRYPOINT:-websecure}}"
TRAEFIK_HTTP_ENTRYPOINT="${_arg_http_ep:-${TRAEFIK_HTTP_ENTRYPOINT:-web}}"
AUTO_MAP_BASE_DOMAIN="${_arg_base_domain:-${AUTO_MAP_BASE_DOMAIN:-}}"
AUTO_MAP_SCHEME="${_arg_scheme:-${AUTO_MAP_SCHEME:-http}}"
PORT_MAPPINGS="${_arg_mappings:-${PORT_MAPPINGS:-}}"
EXCLUDE_PORTS="${_arg_exclude:-${EXCLUDE_PORTS:-}}"

if [ "${_arg_no_cert_resolver}" = "true" ]; then
    TRAEFIK_CERT_RESOLVER=""
elif [ -n "${_arg_cert_resolver}" ]; then
    TRAEFIK_CERT_RESOLVER="${_arg_cert_resolver}"
else
    TRAEFIK_CERT_RESOLVER="${TRAEFIK_CERT_RESOLVER:-}"
fi

if [ "${_arg_no_auto_map}" = "true" ]; then
    AUTO_MAP_ENABLED="false"
else
    AUTO_MAP_ENABLED="${AUTO_MAP_ENABLED:-true}"
fi

_ephemeral_min=32768
if [ -r /proc/sys/net/ipv4/ip_local_port_range ]; then
    # read + set -e + || true runs read in a subshell in busybox ash, losing assignments; use awk instead
    _ephemeral_min="$(awk '{print $1; exit}' /proc/sys/net/ipv4/ip_local_port_range)"
fi
WATCH_PORT_MIN="${_arg_port_min:-${WATCH_PORT_MIN:-1024}}"
WATCH_PORT_MAX="${_arg_port_max:-${WATCH_PORT_MAX:-$(( _ephemeral_min - 1 ))}}"

if [ "${_arg_keep_config}" = "true" ]; then
    WATCH_KEEP_CONFIG="true"
else
    WATCH_KEEP_CONFIG="${WATCH_KEEP_CONFIG:-false}"
fi

if [ "${AUTO_MAP_ENABLED}" = "true" ] && [ -z "${AUTO_MAP_BASE_DOMAIN}" ]; then
    printf 'ERROR: AUTO_MAP_ENABLED=true but AUTO_MAP_BASE_DOMAIN is not set\n' >&2
    printf 'Set AUTO_MAP_BASE_DOMAIN to your domain, or pass --no-auto-map to disable auto-mapping.\n' >&2
    exit 1
fi

# ---------------------------------------------------------------------------- #
# Helpers                                                                       #
# ---------------------------------------------------------------------------- #

log() { printf '[tunnel-to-traefik] %s\n' "$1" >&2; }

_cleanup_done=false
_cleanup_on_exit() {
    [ "${_cleanup_done}" = "true" ] && return 0
    _cleanup_done=true
    [ "${WATCH_KEEP_CONFIG}" = "true" ] && return 0
    [ "${_dry_run}" = "true" ] && return 0
    write_config
    log "Cleared Traefik config on exit (${TRAEFIK_DYNAMIC_FILE})"
}

# Resolves a port to "scheme://domain" via PORT_MAPPINGS first, then auto-map.
# Returns 1 (prints nothing) if no mapping applies.
resolve_domain() {
    _rd_port="${1}"
    _rd_found=false

    if [ -n "${PORT_MAPPINGS}" ]; then
        _rd_old_ifs="${IFS}"
        IFS=","
        for _rd_mapping in ${PORT_MAPPINGS}; do
            _rd_map_port="${_rd_mapping%%:*}"
            _rd_map_value="${_rd_mapping#*:}"
            if [ "${_rd_map_port}" = "${_rd_port}" ] && [ -n "${_rd_map_value}" ]; then
                _rd_found=true
                break
            fi
        done
        IFS="${_rd_old_ifs}"

        if [ "${_rd_found}" = "true" ]; then
            case "${_rd_map_value}" in
                http://*|https://*)
                    printf '%s\n' "${_rd_map_value}"
                    return 0
                    ;;
                *)
                    log "ERROR: PORT_MAPPINGS entry for port ${_rd_port} missing scheme prefix (use http:// or https://), skipping"
                    return 1
                    ;;
            esac
        fi
    fi

    if [ "${AUTO_MAP_ENABLED}" = "true" ] && [ -n "${AUTO_MAP_BASE_DOMAIN}" ]; then
        printf '%s://%s.%s\n' "${AUTO_MAP_SCHEME}" "${_rd_port}" "${AUTO_MAP_BASE_DOMAIN}"
        return 0
    fi

    return 1
}

# Returns ports bound on 0.0.0.0 or * (SSH GatewayPorts bind address) within
# [WATCH_PORT_MIN, WATCH_PORT_MAX], excluding port 22 and EXCLUDE_PORTS.
get_forwarded_ports() {
    ss -tlnH 2>/dev/null \
        | awk '$4 ~ /^(0\.0\.0\.0|\*):/{sub(/.*:/, "", $4); print $4}' \
        | sort -un \
        | while IFS= read -r _gfp_port; do
        [ "${_gfp_port}" = "22" ] && continue
        if [ "${_gfp_port}" -lt "${WATCH_PORT_MIN}" ] || [ "${_gfp_port}" -gt "${WATCH_PORT_MAX}" ]; then
            continue
        fi
        if [ -n "${EXCLUDE_PORTS}" ]; then
            _gfp_skip=false
            _gfp_old_ifs="${IFS}"
            IFS=","
            for _gfp_ep in ${EXCLUDE_PORTS}; do
                [ "${_gfp_ep}" = "${_gfp_port}" ] && { _gfp_skip=true; break; }
            done
            IFS="${_gfp_old_ifs}"
            [ "${_gfp_skip}" = "true" ] && continue
        fi
        printf '%s\n' "${_gfp_port}"
    done
}

write_config() {
    if [ "${_dry_run}" = "true" ]; then
        _wc_dest="/dev/stdout"
    else
        mkdir -p "$(dirname "${TRAEFIK_DYNAMIC_FILE}")"
        _wc_dest="${TRAEFIK_DYNAMIC_FILE}.tmp"
    fi

    # $1 is a pre-resolved "PORT|URL" list, one entry per line.
    _wc_pairs="${1:-}"

    if [ -z "${_wc_pairs}" ]; then
        printf 'http:\n  routers: {}\n  services: {}\n' > "${_wc_dest}"
    else
        {
            printf 'http:\n  routers:\n'
            while IFS='|' read -r _wc_port _wc_url; do
                [ -z "${_wc_port}" ] && continue
                _wc_scheme="${_wc_url%%://*}"
                _wc_domain="${_wc_url#*://}"
                _wc_name="tunnel-${_wc_port}"
                printf '    %s:\n' "${_wc_name}"
                printf '      rule: "Host(`%s`)"\n' "${_wc_domain}"
                printf '      entryPoints:\n'
                if [ "${_wc_scheme}" = "https" ]; then
                    printf '        - %s\n' "${TRAEFIK_HTTPS_ENTRYPOINT}"
                    if [ -n "${TRAEFIK_CERT_RESOLVER}" ]; then
                        printf '      tls:\n        certResolver: %s\n' "${TRAEFIK_CERT_RESOLVER}"
                    else
                        printf '      tls: {}\n'
                    fi
                else
                    printf '        - %s\n' "${TRAEFIK_HTTP_ENTRYPOINT}"
                fi
                printf '      service: %s\n' "${_wc_name}"
            done <<EOF
${_wc_pairs}
EOF
            printf '  services:\n'
            while IFS='|' read -r _wc_port _wc_url; do
                [ -z "${_wc_port}" ] && continue
                _wc_name="tunnel-${_wc_port}"
                printf '    %s:\n' "${_wc_name}"
                printf '      loadBalancer:\n'
                printf '        servers:\n'
                printf '          - url: "http://%s:%s"\n' "${TUNNEL_HOST}" "${_wc_port}"
            done <<EOF
${_wc_pairs}
EOF
        } > "${_wc_dest}"
    fi

    if [ "${_dry_run}" != "true" ]; then
        mv "${_wc_dest}" "${TRAEFIK_DYNAMIC_FILE}"
    fi
}

log_result() {
    _lr_pairs="$1"
    if [ -n "${_lr_pairs}" ]; then
        _summary=""
        while IFS='|' read -r _port _domain; do
            [ -z "${_port}" ] && continue
            if [ -n "${_summary}" ]; then
                _summary="${_summary}, ${_port} -> ${_domain}"
            else
                _summary="${_port} -> ${_domain}"
            fi
        done <<EOF
${_lr_pairs}
EOF
        if [ "${_dry_run}" = "true" ]; then
            log "Active tunnels: ${_summary}"
        else
            log "Active tunnels: ${_summary} (${TRAEFIK_DYNAMIC_FILE})"
        fi
    else
        if [ "${_dry_run}" = "true" ]; then
            log "No active tunnels"
        else
            log "No active tunnels -> cleared ${TRAEFIK_DYNAMIC_FILE}"
        fi
    fi
}

# ---------------------------------------------------------------------------- #
# Main                                                                          #
# ---------------------------------------------------------------------------- #

if [ "${_watch}" = "true" ]; then
    log "Watching (host=${TUNNEL_HOST}, domain=${AUTO_MAP_BASE_DOMAIN}, scheme=${AUTO_MAP_SCHEME}, ports=${WATCH_PORT_MIN}-${WATCH_PORT_MAX}, interval=${WATCH_INTERVAL}s)"
    trap '_cleanup_on_exit; exit' TERM INT
    trap _cleanup_on_exit EXIT
fi

_last_ports_key="__init__"

while true; do
    _ports="$(get_forwarded_ports)"
    _ports_key="${_ports}"

    _needs_write=false
    if [ "${_ports_key}" != "${_last_ports_key}" ]; then
        _needs_write=true
    elif [ "${_dry_run}" != "true" ] && [ ! -f "${TRAEFIK_DYNAMIC_FILE}" ]; then
        _needs_write=true
    fi

    if [ "${_needs_write}" = "true" ]; then
        _pairs=""
        while IFS= read -r _p; do
            [ -z "${_p}" ] && continue
            _u="$(resolve_domain "${_p}")" || continue
            _pairs="${_pairs}${_p}|${_u}
"
        done <<EOF
${_ports}
EOF
        write_config "${_pairs}"
        _last_ports_key="${_ports_key}"
        log_result "${_pairs}"
    fi

    [ "${_watch}" != "true" ] && exit 0

    sleep "${WATCH_INTERVAL}"
done
