FROM openjdk:8-alpine

ARG BUNGEECORD_BASE_URL=https://ci.md-5.net/job/BungeeCord/
ARG BUNGEECORD_JOB_ID=lastStableBuild
ARG BUNGEECORD_FILE_URL=/artifact/bootstrap/target/BungeeCord.jar
ARG BUNGEECORD_URL=${BUNGEECORD_BASE_URL}${BUNGEECORD_JOB_ID}${BUNGEECORD_FILE_URL}

WORKDIR /app
RUN set -eux; \
    apk update; \
    apk add --no-cache \
    bash curl \
    # Required for yq and yaml_cli (runs on Python)
    python3 py3-pip python py-pip \
    # Required to download yaml_cli
    git \
    # Required by yq
    jq; \
    # yq
    pip3 install yq; \
    # yaml_cli
    pip install git+https://github.com/Gallore/yaml_cli; \
    # Bungeecord
    curl -o /app/bungeecord.jar -fsSL "${BUNGEECORD_URL}"; \
    # Cleanup
    apk del git curl

COPY bin /usr/local/bin

EXPOSE 25565
VOLUME ["/data"]
WORKDIR /data
ENTRYPOINT ["docker-entrypoint.sh"]
