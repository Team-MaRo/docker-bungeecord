# -------
# Builder
# -------

FROM alpine:latest AS build

RUN apk add curl

ARG BUNGEECORD_BASE_URL=https://ci.md-5.net/job/BungeeCord/
ARG BUNGEECORD_JOB_ID=lastStableBuild
ARG BUNGEECORD_FILE_URL=/artifact/bootstrap/target/BungeeCord.jar
ARG BUNGEECORD_URL=${BUNGEECORD_BASE_URL}${BUNGEECORD_JOB_ID}${BUNGEECORD_FILE_URL}

# Download the application
RUN curl -o /bungeecord.jar -fL ${BUNGEECORD_URL}

# -------
# Final Container
# -------

FROM openjdk:8-jre-slim

COPY --from=build /bungeecord.jar /app/

COPY src/bungeecord-console.sh /usr/local/bin/console
RUN chmod 755 /usr/local/bin/console

COPY src/docker-entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]

WORKDIR /data
ENTRYPOINT ["docker-entrypoint.sh"]
