#!/bin/bash

set -eo pipefail

# If command starts with an option (`-f` or `--some-option`), prepend main command
if [ "${1#-}" != "$1" ]; then
    set -- bungeecord "$@"
fi

# Logging functions
entrypoint_log() {
    local type="$1"
    shift
    printf '%s [%s] [Entrypoint]: %s\n' "$(date '+%Y-%m-%d %T %z')" "$type" "$*"
}
entrypoint_note() {
    entrypoint_log Note "$@"
}
entrypoint_warn() {
    entrypoint_log Warn "$@" >&2
}
entrypoint_error() {
    entrypoint_log ERROR "$@" >&2
    exit 1
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
#
# Will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
# "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature
# Read more: https://docs.docker.com/engine/swarm/secrets/
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(<"${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

# Setup java
if [ "$1" = 'bungeecord' ]; then
    entrypoint_note 'Entrypoint script for Bungeecord started'

    # ----------------------------------------

    entrypoint_note 'Load various environment variables'
    envs=(
        JAVA_MEMORY
        JAVA_BASE_MEMORY
        JAVA_MAX_MEMORY
        JAVA_OPTIONS
    )

    # Set empty environment variable or get content from "/run/secrets/<something>"
    for e in "${envs[@]}"; do
        file_env "$e"
    done

    # Set default environment variable values
    : "${JAVA_MEMORY:=512M}"
    : "${JAVA_BASE_MEMORY:=${JAVA_MEMORY}}"
    : "${JAVA_MAX_MEMORY:=${JAVA_MEMORY}}"
    : "${JAVA_OPTIONS:=}"

    # ----------------------------------------

    # Start the main application
    entrypoint_note "Starting BungeeCord server ..."

    true >/tmp/input.buffer
    # shellcheck disable=SC2086
    tail -f /tmp/input.buffer | tee /dev/console | java $JAVA_OPTIONS -jar /opt/bungeecord.jar "${@:2}"

    exit
fi

exec "$@"
