#!/bin/bash

# Set variables for java runtime
echo "[    ] Setting initial memory to ${JAVA_BASE_MEMORY:=${JAVA_MEMORY:=512M}} and max to ${JAVA_MAX_MEMORY:=${JAVA_MEMORY}}"
JAVA_OPTIONS="-Xms${JAVA_BASE_MEMORY} -Xmx${JAVA_MAX_MEMORY} ${JAVA_OPTIONS}"
echo -e "\e[1A[ \e[32mOK\e[39m ]"

# Console buffers
_console_input="/app/input.buffer"
# Clear console buffers
true >$_console_input

# Start the main application
echo "[    ] Starting BungeeCord server..."
# shellcheck disable=SC2086
tail -f $_console_input | tee /dev/console | java $JAVA_OPTIONS -jar /app/bungeecord.jar "$@"
