# docker-bungeecord

Use the BungeeCord Proxy as a Docker App.

**Project**

[![License](https://img.shields.io/github/license/d3strukt0r/docker-bungeecord)][license]
[![Docker Stars](https://img.shields.io/docker/stars/d3strukt0r/bungeecord.svg)][docker]
[![Docker Pulls](https://img.shields.io/docker/pulls/d3strukt0r/bungeecord.svg)][docker]
[![GH Action CI/CD](https://github.com/D3strukt0r/docker-bungeecord/workflows/Update%20versions/badge.svg)][gh-action]

**master**-branch (alias stable, latest)

[![GH Action CI/CD](https://github.com/D3strukt0r/docker-bungeecord/workflows/CI/CD/badge.svg?branch=master)][gh-action]
[![Docs build status](https://img.shields.io/readthedocs/docker-bungeecord/master)][rtfd]

**develop**-branch (alias nightly)

[![GH Action CI/CD](https://github.com/D3strukt0r/docker-bungeecord/workflows/CI/CD/badge.svg?branch=develop)][gh-action]
[![Docs build status](https://img.shields.io/readthedocs/docker-bungeecord/develop)][rtfd]

[license]: https://github.com/D3strukt0r/docker-bungeecord/blob/master/LICENSE.txt
[docker]: https://hub.docker.com/repository/docker/d3strukt0r/bungeecord
[gh-action]: https://github.com/D3strukt0r/docker-spigot-build/actions
[rtfd]: https://docker-bungeecord-docs.manuele-vaccari.ch/

## Getting Started

These instructions will cover usage information and for the docker container

For more in-depth docs, please visit the [Docs](https://docker-bungeecord-docs.manuele-vaccari.ch) page

### Prerequisities

In order to run this container you'll need docker installed.

-   [Windows](https://docs.docker.com/docker-for-windows/install/)
-   [OS X](https://docs.docker.com/docker-for-mac/install/)
-   [Linux](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

### Usage

#### Starting a server

```shell
docker run \
      --rm \
      -d \
      -p 25565:25577 \
      -v $(pwd)/data:/data \
      -e JAVA_MAX_MEMORY=1G \
      --name bungeecord \
      d3strukt0r/bungeecord
```

**Hint**

If you need to add another port to your docker container, use `-p xxxxx:xxxxx` in your command.

#### Reading the logs

```shell
docker logs -f bungeecord
```

#### Sending commands

```shell
docker exec bungeecord console "<command>"
```

#### Using Docker Compose (docker-compose.yml)

```yaml
version: "2"

services:
  bungeecord:
    image: d3strukt0r/bungeecord
    ports:
      - 25565:25577
    volumes:
      - ./data:/data
    environment:
      - JAVA_MAX_MEMORY=1G
```

And then use `docker-compose up` or `docker-compose up -d` for detached.

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

See also the list of [contributors](https://github.com/D3strukt0r/docker-bungeecord/contributors) who
participated in this project.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.txt](LICENSE.txt) file for details

## Acknowledgments

-   Geoff Bourne with [itzg/docker-bungeecord](https://github.com/itzg/docker-bungeecord)
-   James Rehfeld with [rehf27/docker-bungeecord](https://github.com/rehf27/docker-bungeecord)
-   Leopere with [Leopere/docker-bungeecord](https://github.com/Leopere/docker-bungeecord)
-   Hat tip to anyone whose code was used
-   Inspiration
-   etc
