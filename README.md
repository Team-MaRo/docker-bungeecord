# docker-bungeecord

Use the BungeeCord Proxy as a Docker App.

**Project**
[Docker][docker] | [License][license]
--- | ---
![Docker Stars][docker-stars-icon]<br />![Docker Pulls][docker-pulls-icon] | ![License][license-icon]

**master**-branch (alias stable, latest)
[Travis][travis] | [Docs][rtfd]
--- | ---
![Build status][travis-master-icon] | ![Docs build status][rtfd-master-icon]

**develop**-branch (alias nightly)

[Travis][travis] | [Docs][rtfd]
--- | ---
![Build status][travis-develop-icon] | ![Docs build status][rtfd-develop-icon]

[license]: https://github.com/D3strukt0r/docker-bungeecord/blob/master/LICENSE.txt
[docker]: https://hub.docker.com/repository/docker/d3strukt0r/bungeecord
[travis]: https://travis-ci.com/github/D3strukt0r/docker-bungeecord
[docker-stars-icon]: https://img.shields.io/docker/stars/d3strukt0r/bungeecord.svg
[rtfd]: https://docker-bungeecord-docs.manuele-vaccari.ch/

[license-icon]: https://img.shields.io/github/license/d3strukt0r/docker-bungeecord
[docker-pulls-icon]: https://img.shields.io/docker/pulls/d3strukt0r/bungeecord.svg
[travis-master-icon]: https://img.shields.io/travis/com/D3strukt0r/docker-bungeecord/master
[travis-develop-icon]: https://img.shields.io/travis/com/D3strukt0r/docker-bungeecord/develop
[rtfd-master-icon]: https://img.shields.io/readthedocs/docker-bungeecord/master
[rtfd-develop-icon]: https://img.shields.io/readthedocs/docker-bungeecord/develop

## Getting Started

These instructions will cover usage information and for the docker container

For more in-depth docs, please visit the [Docs](https://docker-bungeecord-docs.manuele-vaccari.ch) page

### Prerequisities

In order to run this container you'll need docker installed.

* [Windows](https://docs.docker.com/docker-for-windows/install/)
* [OS X](https://docs.docker.com/docker-for-mac/install/)
* [Linux](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

### Usage

#### Starting a server

```shell script
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

```shell script
docker logs -f bungeecord
```

#### Sending commands

```shell script
docker exec bungeecord console "<command>"
```

#### Using Docker Compose (docker-compose.yml)

```yml
version: '2'

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

* [OpenJDK](https://hub.docker.com/_/openjdk) - The Java conatainer in Docker
* [BungeeCord](https://ci.md-5.net/job/BungeeCord/) - The main software
* [Travis CI](https://travis-ci.com/) - Automatic CI (Testing) / CD (Deployment)
* [Docker](https://www.docker.com/) - Building a Container for the Server

## Find Us

* [GitHub](https://github.com/D3strukt0r/docker-bungeecord)
* [Docker Hub](https://hub.docker.com/r/d3strukt0r/bungeecord)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

There is no versioning in this project. Only the develop for nightly builds, and the master branch which builds latest and all minecraft versions.

## Authors

* **Manuele Vaccari** - [D3strukt0r](https://github.com/D3strukt0r) - *Initial work*

See also the list of [contributors](https://github.com/D3strukt0r/docker-bungeecord/contributors) who
participated in this project.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.txt](LICENSE.txt) file for details

## Acknowledgments

* Geoff Bourne with [itzg/docker-bungeecord](https://github.com/itzg/docker-bungeecord)
* James Rehfeld with [rehf27/docker-bungeecord](https://github.com/rehf27/docker-bungeecord)
* Leopere with [Leopere/docker-bungeecord](https://github.com/Leopere/docker-bungeecord)
* Hat tip to anyone whose code was used
* Inspiration
* etc
