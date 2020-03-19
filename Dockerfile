# -------
# Builder
# -------

FROM alpine:latest AS build

RUN apk add curl

ARG BUNGEECORD_BASE_URL=https://ci.md-5.net/job/BungeeCord/
ARG BUNGEECORD_JOB_ID=lastStableBuild
ARG BUNGEECORD_FILE_URL=/artifact/bootstrap/target/BungeeCord.jar
ARG BUNGEECORD_URL=${BUNGEECORD_BASE_URL}${BUNGEECORD_JOB_ID}${BUNGEECORD_FILE_URL}

RUN curl -o /bungeecord.jar -fL ${BUNGEECORD_URL}

# -------
# Final Container
# -------

FROM openjdk:8-jre-slim

COPY --from=build /bungeecord.jar /app/

VOLUME ["/data"]

ENV JAVA_BASE_MEMORY=512M
ENV JAVA_MAX_MEMORY=512M

EXPOSE 25577

WORKDIR /data

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
