#!/bin/bash

# Verify versions
echo "[    ] Check if Java is available..."
if java -version 2>&1 >/dev/null | grep -q "openjdk version" ; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]" >&2
    exit 2
fi
java -version

# Download specified BungeeCord version if file doesn't already exist
BUNGEECORD_LOCATION=BungeeCord.jar
if [[ ! -e $BUNGEECORD_LOCATION ]]; then
    echo "[    ] Downloading ${BUNGEECORD_URL:=${BUNGEECORD_BASE_URL:=https://ci.md-5.net/job/BungeeCord/}${BUNGEECORD_VERSION:=lastStableBuild}${BUNGEECORD_FILE_URL:=/artifact/bootstrap/target/BungeeCord.jar}}"
    if ! curl -o $BUNGEECORD_LOCATION -fL $BUNGEECORD_URL; then
        echo -e "\e[1A\e[1A\e[1A\e[1A[\e[31mFAIL\e[39m]\n\n\n" >&2
        exit 2
    else
        echo -e "\e[1A\e[1A\e[1A\e[1A[ \e[32mOK\e[39m ]\n\n\n"
    fi
fi

# Link existing data if volume available
if [ -d /data ]; then
    # Link plugins folder
    echo "[    ] Linking plugins/ from the volume"
    mkdir -p /data/plugins
    ln -s /data/plugins .
    if [ $? -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    else
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
    fi

    # Link config.yml
    echo "[    ] Linking config.yml from the volume"
    touch /data/config.yml
    ln -s /data/config.yml .
    if [ $? -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    else
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
    fi

    # Link locations.yml
    echo "[    ] Linking locations.yml from the volume"
    touch /data/locations.yml
    ln -s /data/locations.yml .
    if [ $? -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    else
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
    fi

    # Link proxy.log.*
    echo "[    ] Linking proxy.log.* from the volume"
    touch /data/proxy.log.0
    ln -s /data/proxy.log.* .
    if [ $? -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    else
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
    fi

    # Link server-icon.png
    echo "[    ] Linking server-icon.png from the volume"
    if [ -f /data/server-icon.png ]; then
        ln -s /data/server-icon.png .
        if [ $? -eq 0 ]; then
            echo -e "\e[1A[ \e[32mOK\e[39m ]"
        else
            echo -e "\e[1A[\e[31mFAIL\e[39m]"
        fi
    else
        echo -e "\e[1A[\e[33mSKIP\e[39m]"
    fi
fi

# Set variables for java runtime
echo "[    ] Setting initial memory to ${JAVA_BASE_MEMORY:=${JAVA_MEMORY:=512M}} and max to ${JAVA_MAX_MEMORY:=${JAVA_MEMORY}}"
JAVA_OPTIONS="-Xms${JAVA_BASE_MEMORY} -Xmx${JAVA_MAX_MEMORY} ${JAVA_OPTIONS}"
echo -e "\e[1A[ \e[32mOK\e[39m ]"

exec java $JAVA_OPTIONS -jar BungeeCord.jar "$@"
