#!/usr/bin/env bash
#
# BungeeCord container entrypoint.
#
# Responsibilities, in order:
#   1. Render config.yml from BUNGEE__ environment variables (see "Config from
#      env" below).
#   2. Assemble the JVM command line (memory + a flags preset + user overrides).
#   3. exec mc-server-init as PID 1 (own repo github:Team-MaRo/mc-server-init, a
#      flake input). It runs BungeeCord on a PTY so the JLine console keeps its
#      `>` prompt, forwards the container stdin and a named pipe into the console,
#      and turns SIGTERM/SIGINT/Ctrl+C into a clean `end` (BungeeCord's graceful
#      shutdown command).
#
# BungeeCord has no EULA and a single config.yml (unlike a Spigot server's
# server.properties/bukkit.yml/spigot.yml).
#
# When packaged with Nix `writeShellApplication`, `set -euo pipefail` and a PATH
# containing java/yq/coreutils/grep are prepended; the lines below let the script
# also run standalone for local testing.
set -euo pipefail

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log()   { printf '%s [%s] [entrypoint] %s\n' "$(date '+%Y-%m-%d %T %z')" "${2:-note}" "$1"; }
note()  { log "$1" note; }
warn()  { log "$1" warn >&2; }
fatal() { log "$1" ERROR >&2; exit 1; }

# usage: file_env VAR [DEFAULT]
# Lets "${VAR}_FILE" supply the value of "$VAR" (Docker/Swarm secrets).
file_env() {
    local var="$1" fileVar="${1}_FILE" def="${2:-}" val
    if [ -n "${!var:-}" ] && [ -n "${!fileVar:-}" ]; then
        fatal "both $var and $fileVar are set (mutually exclusive)"
    fi
    val="$def"
    if   [ -n "${!var:-}" ];     then val="${!var}"
    elif [ -n "${!fileVar:-}" ]; then val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Config from env
#
# A variable name after the BUNGEE__ prefix is split on "__" into path segments
# of config.yml. Segments are lowercased but keep their underscores (BungeeCord
# uses snake_case keys); an all-digits segment is a list index. Examples:
#   BUNGEE__ONLINE_MODE=false        -> online_mode: false
#   BUNGEE__PLAYER_LIMIT=100         -> player_limit: 100
#   BUNGEE__LISTENERS__0__MOTD=Hi    -> listeners[0].motd: "Hi"
#
# Values are YAML-typed (`true` -> bool, `100` -> int). Quote a value that must
# stay a string but looks numeric. List-heavy sections (listeners, servers) are
# easier to manage by mounting your own config.yml.
# ---------------------------------------------------------------------------

# "LISTENERS__0__MOTD" -> '["listeners"][0]["motd"]'
env_to_path() {
    local rest="$1" seg path=""
    while IFS= read -r seg; do
        [ -z "$seg" ] && continue
        seg="$(printf '%s' "$seg" | tr '[:upper:]' '[:lower:]')" # keep underscores (snake_case)
        if printf '%s' "$seg" | grep -qE '^[0-9]+$'; then
            path="${path}[${seg}]"
        else
            path="${path}[\"${seg}\"]"
        fi
    done <<< "${rest//__/$'\n'}"
    printf '%s' "$path"
}

# usage: render <file> <PREFIX__>
render() {
    local file="$1" prefix="$2" var path
    [ -f "$file" ] || : > "$file"
    while IFS= read -r var; do
        path="$(env_to_path "${var#"$prefix"}")"
        [ -z "$path" ] && continue
        yq -i ".${path} = env(${var})" "$file"
        note "set ${path} in ${file} (from ${var})"
        # printenv lists exported env vars (NAME=value); grep -o keeps just the
        # names with our prefix. (compgen isn't available in the minimal bash.)
    done < <(printenv | grep -oE "^${prefix}[^=]*" || true)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
note 'BungeeCord entrypoint starting'

for v in MEMORY INIT_MEMORY MAX_MEMORY JVM_OPTS JVM_FLAGS_PRESET; do
    file_env "$v"
done

# No memory default: if MEMORY/INIT_MEMORY/MAX_MEMORY are all unset we pass no
# -Xms/-Xmx and the JVM uses its own (container-aware) default heap sizing.
: "${MEMORY:=}"
: "${INIT_MEMORY:=${MEMORY}}"
: "${MAX_MEMORY:=${MEMORY}}"
: "${JVM_OPTS:=}"
: "${JVM_FLAGS_PRESET:=none}"
: "${JAVA_MAJOR:=0}"

# Trailing args whose first token is an option (e.g. `--foo`) are passed straight
# to BungeeCord — no SERVER_ARGS-style env needed. A non-option first arg instead
# falls through to the override below (e.g. `docker run <image> bash`).
server_args=()
if [ "$#" -gt 0 ] && [ "${1#-}" != "$1" ]; then
    server_args=( "$@" )
    set --
fi

note 'Rendering config.yml from environment'
render config.yml 'BUNGEE__'

# Default the proxy listener to the conventional Minecraft port (25565, the one
# the image EXPOSEs and health-checks) instead of BungeeCord's own 25577 default.
# The `// default` alternative operator only fills it when unset, so a mounted
# config.yml or a BUNGEE__LISTENERS__0__HOST override still wins. (yq-go has no
# `//=` shorthand, so assign the alternative explicitly.)
[ -f config.yml ] || : > config.yml
yq -i '.listeners[0].host = (.listeners[0].host // "0.0.0.0:25565")' config.yml

# ---------------------------------------------------------------------------
# JVM flags. A proxy doesn't benefit from a Minecraft *server* GC pack (aikars),
# so the default is none. `velocity` offers the PaperMC proxy flag set.
# ---------------------------------------------------------------------------
preset_flags=()
case "$JVM_FLAGS_PRESET" in
    none)
        ;;
    velocity)
        # https://docs.papermc.io/velocity/ — sensible for a proxy JVM.
        read -r -a preset_flags <<< "-XX:+AlwaysPreTouch -XX:+ParallelRefProcEnabled -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:MaxInlineLevel=15"
        ;;
    *)
        warn "Unknown JVM_FLAGS_PRESET='${JVM_FLAGS_PRESET}', using none"
        ;;
esac

# Build the final argv as an array so flags with no values keep their boundaries.
java_args=()
[ -n "$INIT_MEMORY" ] && java_args+=( "-Xms${INIT_MEMORY}" )
[ -n "$MAX_MEMORY" ]  && java_args+=( "-Xmx${MAX_MEMORY}" )
[ "${#preset_flags[@]}" -gt 0 ] && java_args+=( "${preset_flags[@]}" )
if [ -n "$JVM_OPTS" ]; then read -r -a _o <<< "$JVM_OPTS"; java_args+=( "${_o[@]}" ); fi
java_args+=( -jar /opt/bungeecord.jar )
[ "${#server_args[@]}" -gt 0 ] && java_args+=( "${server_args[@]}" )

# Record the fully-resolved env so `docker exec -it <c> sh -l` can see it. A bare
# `docker exec` is a sibling of PID 1 and only inherits the container's CONFIGURED
# env (image ENV + run -e), never these runtime-computed defaults. Best-effort:
# a non-writable /etc/profile.d must never block startup.
{ for v in MEMORY INIT_MEMORY MAX_MEMORY JVM_OPTS JVM_FLAGS_PRESET JAVA_MAJOR; do
    printf 'export %s=%q\n' "$v" "${!v}"
  done; } > /etc/profile.d/bungeecord-env.sh 2>/dev/null || true

# Full escape hatch: a non-option CMD override replaces the launch entirely
# (`docker run <image> bash` drops you into a shell). Option-leading args were
# captured above as server args, so only a non-option first arg reaches here.
if [ "$#" -gt 0 ]; then
    note "Running override command: $*"
    exec "$@"
fi

# Launch via mc-server-init (PID 1). It runs BungeeCord behind a PTY (so JLine
# keeps the `>` prompt), forwards the container's stdin (interactive
# `docker run -it` / `docker attach`) AND a named pipe at /tmp/console-in
# (scripted `console <cmd>` injection, no RCON) into the console, and on SIGTERM /
# SIGINT / a typed Ctrl+C sends a clean `end` — BungeeCord's graceful shutdown —
# falling back to SIGKILL only after --stop-timeout.
note "Launching via mc-server-init: java ${java_args[*]}  (console: console <cmd>)"
exec mc-server-init --stop-command end -- java "${java_args[@]}"
