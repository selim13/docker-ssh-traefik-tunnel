FROM alpine:3.24

LABEL org.opencontainers.image.source="https://github.com/selim13/docker-ssh-traefik-tunnel" \
    org.opencontainers.image.description="SSH tunnel server that exposes forwarded ports as HTTP/HTTPS subdomains through Traefik" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.authors="Dmitry Seleznev <selim013@gmail.com>"

ENV CONF_VOLUME="/conf.d"
ENV CACHED_SSH_DIRECTORY="${CONF_VOLUME}/ssh" \
    AUTHORIZED_KEYS_FILE="${CONF_VOLUME}/authorized_keys" \
    WATCHER_ENABLED="true" \
    WATCH_INTERVAL="3" \
    TUNNEL_HOST="" \
    AUTO_MAP_BASE_DOMAIN="" \
    AUTO_MAP_ENABLED="true" \
    AUTO_MAP_SCHEME="http" \
    PORT_MAPPINGS="" \
    EXCLUDE_PORTS="" \
    WATCH_PORT_MIN="1024" \
    WATCH_PORT_MAX="" \
    WATCH_KEEP_CONFIG="false" \
    TRAEFIK_DYNAMIC_FILE="${CONF_VOLUME}/traefik/dynamic.yml" \
    TRAEFIK_HTTPS_ENTRYPOINT="websecure" \
    TRAEFIK_HTTP_ENTRYPOINT="web" \
    TRAEFIK_CERT_RESOLVER="letsencrypt"

# hadolint ignore=DL3018
RUN apk add --upgrade --no-cache \
        iproute2 \
        openssh \
    && adduser -D -H -s /sbin/nologin -u 1000 tunnel \
    && sed -i 's/^tunnel:[^:]*/tunnel:*/' /etc/shadow \
    && mkdir -p "${CONF_VOLUME}" \
    && cp -a /etc/ssh "${CACHED_SSH_DIRECTORY}" \
    && rm -rf /var/cache/apk/*

COPY entrypoint.sh tunnel-to-traefik.sh /
RUN chmod +x /entrypoint.sh /tunnel-to-traefik.sh
EXPOSE 22
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD nc -z 127.0.0.1 22
ENTRYPOINT ["/entrypoint.sh"]
