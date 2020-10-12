FROM openjdk:8-alpine

# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG BUNGEECORD_BASE_URL=https://ci.md-5.net/job/BungeeCord/
ARG BUNGEECORD_JOB_ID=lastStableBuild
ARG BUNGEECORD_FILE_URL=/artifact/bootstrap/target/BungeeCord.jar
ARG BUNGEECORD_URL=${BUNGEECORD_BASE_URL}${BUNGEECORD_JOB_ID}${BUNGEECORD_FILE_URL}

WORKDIR /app

# hadolint ignore=DL3018, DL3013
RUN set -eux; \
    apk update; \
    apk add --no-cache \
        bash \
        bash-completion \
        curl \
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
    \
    # Cleanup
    apk del git; \
    \
    # Custom bash config
    { \
        echo 'source /etc/profile.d/bash_completion.sh'; \
        # <green> user@host <normal> : <blue> dir <normal> $#
        echo 'export PS1="🐳 \e[38;5;10m\u@\h\e[0m:\e[38;5;12m\w\e[0m\\$ "'; \
    } >"$HOME/.bashrc"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3020
ADD ${BUNGEECORD_URL} /opt/bungeecord.jar
COPY docker/console.sh /usr/local/bin/console

EXPOSE 25565

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
ENTRYPOINT ["docker-entrypoint"]
CMD ["bungeecord"]
