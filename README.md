# docker-bungeecord

Use the BungeeCord Proxy as a Docker App.

Project

[![License](https://img.shields.io/github/license/d3strukt0r/docker-bungeecord)][license]
[![Docker Stars](https://img.shields.io/docker/stars/d3strukt0r/bungeecord.svg)][docker]
[![Docker Pulls](https://img.shields.io/docker/pulls/d3strukt0r/bungeecord.svg)][docker]

master-branch (alias stable, latest)

[![GH Action CI/CD](https://github.com/D3strukt0r/docker-bungeecord/workflows/CI/CD/badge.svg?branch=master)][gh-action]
[![Codacy grade](https://img.shields.io/codacy/grade/80a7f4cf799248ccad6f24e504a88c24/master)][codacy]

<!--
develop-branch (alias nightly)

[![GH Action CI/CD](https://github.com/D3strukt0r/docker-bungeecord/workflows/CI/CD/badge.svg?branch=develop)][gh-action]
[![Codacy grade](https://img.shields.io/codacy/grade/80a7f4cf799248ccad6f24e504a88c24/develop)][codacy]
-->

## Getting Started

These instructions will cover usage information and for the docker container

### Prerequisities

In order to run this container you'll need docker installed.

-   [Windows](https://docs.docker.com/docker-for-windows/install/)
-   [OS X](https://docs.docker.com/docker-for-mac/install/)
-   [Linux](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

### Usage

#### Using Docker

##### Starting a server

```shell
docker run \
    --rm \
    -d \
    -p 25565:25577 \
    -v $(pwd)/bungeecord:/app \
    -e JAVA_MAX_MEMORY=1G \
    -e <other variables> \
    --name bungeecord \
    d3strukt0r/bungeecord
```

`--rm`: Removes the container after it has been shut down. This means we can reuse the name later on.

`-d`: Start detached. Or leave out to watch the logs. You can then leave using `CTRL + D`

<!--
`-i -t` (WORK IN PROGRESS): This will let you work with the console inside your container. However, this will not let you leave but not re-enter the console, without shutting down the server. Later on, you'll learn a workaround for this. To leave from the terminal, and let it run in the background click `CTRL + P + Q` (lift from `P` and click `Q` while still holding `CTRL`)
-->

`-p 25565:25577`: This opens the internal port (inside the container) to the outer worlds. You can open as many ports as you want. This would maybe look like `-p 25565:25577 -p 8192:8192`.

`-v $(pwd)/bungeecord:/app`: If you want to save your server somewhere, you need to link the directory inside your container to your host. Before the colon goes the place on your host. After the colon goes the directory inside the container, which is always `/app`.

`-e JAVA_MAX_MEMORY=1G`: This is the equivalent of `-Xmx1G`. For the required amount of RAM you will need, please consult Google.

`--name bungeecord`: Give the container a name, for easier referencing later on.

`d3strukt0r/bungeecord`: This is the repository where the container is maintained. You can also specify what version you want to use. e. g. `d3strukt0r/bungeecord:latest` or `d3strukt0r/bungeecord:548`. For all versions check the [Tags on Docker Hub](https://hub.docker.com/repository/docker/d3strukt0r/bungeecord/tags).

##### Reading the logs

While running you can access the output with `docker logs -f <container name>` and leave with `CTRL + Q`.

`-f`: To not just output the logs until now, but keep reading, until we exit with `CTRL + D`. This will not close the server, you'll just leave the logs.

##### Sending commands

To send a command through the console to BungeeCord, use `docker exec <container name> console "<command>"`.

Replace `<command>` with the command you need. This is what you would also usually enter
inside your regular console, like e. g. `op D3strukt0r`.

##### Stopping the server

At the end to shut everything down use `docker stop <container name>`

#### Using Docker Compose (docker-compose.yml)

Create a file called `docker-compose.yml`

```yaml
version: "2"

services:
  bungeecord:
    image: d3strukt0r/bungeecord
    ports:
      - 25565:25577
    networks:
      - internal
    dns:
      - 1.1.1.1
      - 1.0.0.1
    volumes:
      - ./bungeecord:/app
    environment:
      - JAVA_MAX_MEMORY=512M
  lobby:
    image: d3strukt0r/spigot
    networks:
      - internal
    dns:
      - 1.1.1.1
      - 1.0.0.1
    volumes:
      - ./lobby:/app
    environment:
      - JAVA_MAX_MEMORY=1G
      - EULA=true
      - BUNGEECORD=true

networks:
  internal:
    external: false
```

To be able to access the minecraft servers, you need to set the correct address in your `config.yml`. The address basically is the name of the container. The port is the one that is configured under `server.properties` inside Spigot (by default `25565`). With the example above, this would for example look like:

```yaml
...
servers:
  lobby:
    motd: '&1Lobby'
    address: lobby_1:25565
    restricted: false
...
```

Also IP needs to be forwared:

```yaml
...
ip_forward: true
...
```

##### Compose: Starting a server

To start the server use `docker-compose up` or `docker-compose up -d` for starting detached (in the background).  When running without `-d`, you can still detach with `CTRL + P` followed by `CTRL + Q`.

##### Compose: Reading the logs

While running you can access the output with `docker-compose logs -f` and leave with `CTRL + Q`.

##### Compose: Sending commands

To send a command through the console to BungeeCord, use `docker-compose exex <container name> console "<command>"`.

##### Compose: Stopping the server

At the end to shut everything down use `docker-compose down`

#### Environment Variables

All environment variables support Docker Secrets. To learn more about Docker Secrets, read [here](https://docs.docker.com/engine/swarm/secrets/).

Basically, after creating a secret, append a `_FILE` (e. g. `JAVA_OPTIONS_FILE`) after the environment variable and set the path to something like `/run/secrets/<something>`.

-   `JAVA_MEMORY` - The memory java can use. Any integer followed by `K` (Kilobyte), `M` (Megabyte) or `G` (Gigabyte) (Default: `512M`)
-   `JAVA_BASE_MEMORY` - The memory java can use at startup. Any integer followed by `K` (Kilobyte), `M` (Megabyte) or `G` (Gigabyte) (Default: `${JAVA_MEMORY}`)
-   `JAVA_MAX_MEMORY` - The maximum memory the application can use. Recommended is `512M` for each 500 users. Any integer followed by `K` (Kilobyte), `M` (Megabyte) or `G` (Gigabyte) (Default: `${JAVA_MEMORY}`)
-   `JAVA_OPTIONS` - Any `java` argument (Default: )

#### Volumes

-   `/app` - All the data, like: configs, plugins, logs, icons

#### Useful File Locations

-   `/usr/local/bin/console` - Can send a command to BungeeCord indirectly

## Built With

-   [OpenJDK](https://hub.docker.com/_/openjdk) - The Java conatainer in Docker
-   [BungeeCord](https://ci.md-5.net/job/BungeeCord/) - The main software
-   [Github Actions](https://github.com/features/actions) - Automatic CI (Testing) / CD (Deployment)
-   [Docker](https://www.docker.com/) - Building a Container for the Server

## Find Us

-   [GitHub](https://github.com/D3strukt0r/docker-bungeecord)
-   [Docker Hub](https://hub.docker.com/r/d3strukt0r/bungeecord)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

There is no versioning in this project. Only the develop for nightly builds, and the master branch which builds latest and all minecraft versions.

## Authors

-   **Manuele Vaccari** - [D3strukt0r](https://github.com/D3strukt0r) - _Initial work_

See also the list of [contributors](https://github.com/D3strukt0r/docker-bungeecord/contributors) who participated in this project.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.txt](LICENSE.txt) file for details

## Acknowledgments

-   Geoff Bourne with [itzg/docker-bungeecord](https://github.com/itzg/docker-bungeecord)
-   James Rehfeld with [rehf27/docker-bungeecord](https://github.com/rehf27/docker-bungeecord)
-   Leopere with [Leopere/docker-bungeecord](https://github.com/Leopere/docker-bungeecord)
-   Hat tip to anyone whose code was used
-   Inspiration
-   etc

[license]: https://github.com/D3strukt0r/docker-bungeecord/blob/master/LICENSE.txt
[docker]: https://hub.docker.com/repository/docker/d3strukt0r/bungeecord
[gh-action]: https://github.com/D3strukt0r/docker-bungeecord/actions
[codacy]: https://www.codacy.com/manual/D3strukt0r/docker-bungeecord
