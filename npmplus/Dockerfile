# NPMplus for Home Assistant: the upstream image plus a thin integration layer.
# renovate: datasource=docker depName=docker.io/zoeyvid/npmplus
ARG NPMPLUS_VERSION=2026-11-18-r1
ARG BUILD_FROM=docker.io/zoeyvid/npmplus:${NPMPLUS_VERSION}

FROM ${BUILD_FROM}

COPY rootfs/ /
COPY run.sh entrypoint.sh /

# Adjust the admin UI for ingress and a dark default (see patch-frontend.sh).
RUN chmod a+x /run.sh /entrypoint.sh \
    && /usr/local/lib/npmplus-app/patch-frontend.sh

ARG BUILD_VERSION=2026.11.21
ARG BUILD_ARCH=amd64
ENV NPMPLUS_APP_VERSION=${BUILD_VERSION}
LABEL io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    org.opencontainers.image.source="https://github.com/seb5594/Home-Assistant-NPMplus-App"

ENTRYPOINT [ "/bin/bash", "/entrypoint.sh" ]
CMD [ "/run.sh" ]
