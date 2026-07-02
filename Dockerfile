# syntax=docker/dockerfile:1

FROM eclipse-temurin:25.0.3_9-jre-noble

ARG MC_VERSION
ARG BUILD_DATE
ARG VCS_REF
ARG IMAGE_VERSION
ARG IMAGE_SOURCE

LABEL org.opencontainers.image.title="Minecraft Server" \
      org.opencontainers.image.description="Vanilla Minecraft Java Edition server image built from the official Mojang server jar" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="Adora Laura Kalb <me@adora.codes>" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.url="${IMAGE_SOURCE}" \
      org.opencontainers.image.documentation="${IMAGE_SOURCE}#readme" \
      org.opencontainers.image.vendor="lila.network" \
      org.opencontainers.image.licenses="MIT" \
      io.minecraft.version="${MC_VERSION}" \
      io.minecraft.server.type="vanilla" \
      io.minecraft.eula-required="true" \
      io.minecraft.data-dir="/data"

RUN groupadd -g 10001 minecraft \
    && useradd -u 10001 -g minecraft -d /data -s /usr/sbin/nologin minecraft \
    && mkdir -p /opt/minecraft /data \
    && chown -R minecraft:minecraft /opt/minecraft /data

COPY ./server.jar /opt/minecraft/server.jar

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER minecraft
WORKDIR /data

VOLUME ["/data"]
EXPOSE 25565/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]