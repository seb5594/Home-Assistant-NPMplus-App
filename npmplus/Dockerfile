# NPMplus for Home Assistant: the files of an upstream release on the shared Home Assistant base image.
# renovate: datasource=docker depName=docker.io/zoeyvid/npmplus
ARG NPMPLUS_VERSION=2026-11-18-r1
ARG BUILD_FROM=ghcr.io/seb5594/home-assistant-base:3.24-2026.11.0

FROM docker.io/zoeyvid/npmplus:${NPMPLUS_VERSION} AS npmplus

FROM ${BUILD_FROM}

# Runtime packages of NPMplus (taken from the final stage of its Dockerfile). They are not pinned on
# purpose: they come from the Alpine release of the base image, which Renovate keeps current.
RUN apk add --no-cache \
        bash bash-completion brotli coreutils curl fcgi findutils goaccess grep jq libc++ libldap \
        libmaxminddb-libs libxml2 llvm-libunwind logrotate lua5.1-cjson luajit nano nodejs openssl \
        pcre2 python3 quickjs-ng-libs shadow su-exec tzdata util-linux-misc zlib-ng zstd

# Everything NPMplus adds to Alpine: nginx with its libraries, the Lua modules and the Python
# environment of certbot (below /usr/local), the application, and a few files below /etc.
COPY --from=npmplus /usr/local /usr/local
COPY --from=npmplus /app /app
COPY --from=npmplus /etc/certbot.ini /etc/logrotate /etc/crowdsec.conf.example /etc/crowdsec.conf.original \
    /etc/ban.html.original /etc/captcha.html.original /etc/
COPY --from=npmplus /COPYING /LICENSE.MIT /

COPY rootfs/ /
COPY run.sh entrypoint.sh /

# Adjust the admin UI for ingress and a dark default (patch-frontend.sh), then compress its files
# once at the highest level (precompress-frontend.sh).
RUN chmod a+x /run.sh /entrypoint.sh \
    && /usr/local/lib/npmplus-app/patch-frontend.sh \
    && /usr/local/lib/npmplus-app/precompress-frontend.sh

ARG BUILD_VERSION=2026.11.21.6
ARG BUILD_ARCH=amd64
ENV NODE_ENV=production \
    NODE_OPTIONS=--use-openssl-ca \
    NPMPLUS_APP_VERSION=${BUILD_VERSION}
LABEL io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    org.opencontainers.image.source="https://github.com/seb5594/Home-Assistant-NPMplus-App"

WORKDIR /app
HEALTHCHECK CMD [ "healthcheck.sh" ]
ENTRYPOINT [ "/bin/bash", "/entrypoint.sh" ]
CMD [ "/run.sh" ]
