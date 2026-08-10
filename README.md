# docker-bungeecord

Run the [BungeeCord](https://www.spigotmc.org/wiki/bungeecord/) Minecraft proxy as a reproducible,
multi-architecture Docker image, built with Nix.

[![License](https://img.shields.io/github/license/Team-MaRo/docker-bungeecord)](LICENSE.txt)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa)][code-of-conduct]
[![Docker Stars](https://img.shields.io/docker/stars/d3strukt0r/bungeecord.svg)][docker]
[![Docker Pulls](https://img.shields.io/docker/pulls/d3strukt0r/bungeecord.svg)][docker]

[![Docker](https://github.com/Team-MaRo/docker-bungeecord/actions/workflows/docker.yml/badge.svg)][gh-action]
[![Codacy grade](https://img.shields.io/codacy/grade/80a7f4cf799248ccad6f24e504a88c24/master)][codacy]

## How it is built

`flake.nix` produces one image per BungeeCord Jenkins **build number** with
`dockerTools.streamLayeredImage`. The BungeeCord jar is a hash-pinned fetch from the SpigotMC
Jenkins (`versions.json`), the runtime JDK is chosen per build (`jdk-boundaries.json`), and the
proxy runs behind [`mc-server-init`](https://github.com/Team-MaRo/mc-server-init) as PID 1 (PTY
console, named-pipe command injection, and a graceful `end` on `SIGTERM`). Images are built for
`linux/amd64` and `linux/arm64` and published as a single multi-arch manifest, signed with cosign,
with an SBOM and SLSA provenance.

## Tags

Published on [Docker Hub][docker]:

| Tag | Meaning |
| --- | --- |
| `latest` | The newest stable build (also tagged with its build number) |
| `<build>` | A specific Jenkins build number, e.g. `2080`, `1119` |
| `<mc>` | The Minecraft version that build targets, e.g. `26.1`, `1.7.10` |

Every Minecraft version BungeeCord has supported is published — the **last build before support
moved to the next version** — each tagged with both its Minecraft version and its build number
(`1.21` and `2053` point at the same image). `latest` follows the newest. Modern BungeeCord is
multi-protocol, so e.g. the `1.16` image also accepts 1.8–1.16 clients; pick the tag for the
*newest* version you need.

| Minecraft | Build | Runtime JDK |
| --------- | ----- | ----------- |
| `26.1` (= `latest`) | `2080` | 21 |
| `1.21` | `2053` | 17 |
| `1.20` | `1848` | 17 |
| `1.19` | `1708` | 11 |
| `1.18` | `1636` | 11 |
| `1.17` | `1609` | 11 |
| `1.16` | `1575` | 8 |
| `1.15` | `1500` | 8 |
| `1.14` | `1425` | 8 |
| `1.13` | `1402` | 8 |
| `1.12` | `1329` | 8 |
| `1.11` | `1232` | 8 |
| `1.10` | `1199` | 8 |
| `1.9` | `1157` | 8 |
| `1.7.10` | `1119` | 8 |
| `1.6.2` | `666` | 8 |
| `1.5.2` | `548` | 8 |
| `1.5.0` | `386` | 8 |
| `1.4.7` | `251` | 8 |

Each image runs on the **JDK it was compiled with** — the Java that was current when that build was
made (its manifest `Build-Jdk`), floored to JDK 8 (nixpkgs has no JRE 7). Verified `Build-Jdk`
transitions: Java **8→11 at build 1604**, **11→17 at 1724**, **17→21 at 2063**. All assignments
verified by booting. `jdk-boundaries.json` records the minimum and desired JRE per range; the version
list is discovered from each jar's manifest and kept current by `bump-latest.yml`.

Two runtime constraints found while testing (the contemporary-JDK choice steers clear of both):

- **JDK 17 is required from build 2054** (Minecraft 26.1): its `Bootstrap` refuses to start on
  anything older — that's the `min` jump to 17 in `jdk-boundaries.json`.
- **Builds 948–1604** (Minecraft 1.8–1.16) embed a `SecurityManager`, which JDK **24 removed**, so
  those builds cannot run on JRE 24+ (they run fine on their contemporary 8/11).

> No dedicated `1.8` tag: build 1119 is both the last 1.7.10-protocol build and the last `1.8`
> project build, so it's published as `1.7.10`; any `1.9`+ image proxies 1.8 clients too. And build
> `701` (1.6.4) is **not published** — its bootstrap hard-requires Java **7**
> (`java.version.startsWith("1.7")`), and no Java 7 runtime is available via nixpkgs (nor reliably
> on arm64).

## Usage

```shell
docker run --rm -d \
    -p 25565:25565 \
    -v "$(pwd)/bungeecord:/srv/bungeecord" \
    --name bungeecord \
    d3strukt0r/bungeecord
```

- `-p 25565:25565` — the proxy listens on **25565** (the conventional Minecraft port). The image
  defaults BungeeCord's listener to 25565; override it with e.g. `-e BUNGEE__LISTENERS__0__HOST=0.0.0.0:25577`.
- `-v …:/srv/bungeecord` — persist `config.yml`, `modules/`, `plugins/`, and logs. The container
  runs as a non-root user (uid 65532); make sure the host directory is writable by it.
- Pick a tag (`d3strukt0r/bungeecord:1119`) to pin a specific build.

### Sending commands

```shell
docker exec bungeecord console "<command>"
```

`console` injects a line into the running proxy's stdin via a named pipe (no RCON). You can also
attach interactively with `docker attach bungeecord`.

### Stopping

```shell
docker stop bungeecord
```

`mc-server-init` turns `SIGTERM`/`SIGINT` into BungeeCord's graceful `end` command, then `SIGKILL`s
only if it doesn't shut down in time.

### Docker Compose

See [`compose.yml`](compose.yml) for a proxy + backend-server example.

## Configuration

### Environment variables

All variables also support Docker Secrets: append `_FILE` (e.g. `MEMORY_FILE`) and point it at a
file such as `/run/secrets/<name>`.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `MEMORY` | _(unset)_ | Heap size; sets both `-Xms` and `-Xmx`. `K`/`M`/`G` suffix. Unset = the JVM's own (container-aware) default heap sizing. |
| `INIT_MEMORY` | `${MEMORY}` | Initial heap (`-Xms`) override. |
| `MAX_MEMORY` | `${MEMORY}` | Max heap (`-Xmx`) override. |
| `JVM_FLAGS_PRESET` | `none` | GC/tuning flag set: `none` or `velocity` (PaperMC proxy flags). |
| `JVM_OPTS` | | Extra raw JVM arguments. |

To pass arguments to BungeeCord itself, just append them to the container command — if the first
one starts with `-` they're forwarded straight to the proxy, e.g.
`docker run … d3strukt0r/bungeecord --noconsole`. (A non-option command such as `bash` instead runs
as an override: `docker run -it … d3strukt0r/bungeecord bash`.)

### config.yml from the environment

Any `BUNGEE__…` variable is written into `config.yml`. `__` separates path segments, an all-digits
segment is a list index, and values are YAML-typed:

```shell
-e BUNGEE__ONLINE_MODE=false      # online_mode: false
-e BUNGEE__PLAYER_LIMIT=100       # player_limit: 100
-e BUNGEE__IP_FORWARD=true        # ip_forward: true
-e BUNGEE__LISTENERS__0__MOTD=Hi  # listeners[0].motd: "Hi"
```

Quote a value that must stay a string but looks numeric. For list-heavy sections (`listeners`,
`servers`) it is usually simpler to mount your own `config.yml` into `/srv/bungeecord`.

## Example configuration file

BungeeCord generates `config.yml` in the `/srv/bungeecord` volume on first start. The sample below
shows the defaults (the image only changes the listener `host` to `0.0.0.0:25565`); these are the
keys you can override with `BUNGEE__…` env vars.

<details>
<summary>Example <code>config.yml</code></summary>

```yml
connection_throttle_limit: 3
online_mode: true
log_commands: false
network_compression_threshold: 256
listeners:
- query_port: 25577
  motd: '&1Another Bungee server'
  tab_list: SERVER
  query_enabled: false
  proxy_protocol: false
  forced_hosts:
    pvp.md-5.net: pvp
  ping_passthrough: false
  priorities:
  - lobby
  bind_local_address: true
  host: 0.0.0.0:25565
  max_players: 500
  tab_size: 60
  force_default_server: false
connection_throttle: 4000
log_pings: true
ip_forward: true
prevent_proxy_connections: false
forge_support: false
stats: 287a5297-3c79-...
inject_commands: true
disabled_commands:
- disabledcommandhere
groups:
  D3strukt0r:
  - admin
  - moderator
timeout: 30000
permissions:
  default:
  - bungeecord.command.server
  - bungeecord.command.list
  moderator:
  - bungeecord.command.find
  - bungeecord.command.send
  - bungeecord.command.ip
  - bungeecord.command.alert
  admin:
  - bungeecord.command.end
  - bungeecord.command.reload
servers:
  lobby:
    motd: '&1Just another BungeeCord - Forced Host'
    address: localhost:25566
    restricted: false
player_limit: -1
```

</details>

## Volumes & ports

- `/srv/bungeecord` — server working directory (config, modules, plugins, logs).
- `25565/tcp` — proxy listener.

## Built with

- [Nix](https://nixos.org/) — reproducible, multi-arch image builds
- [BungeeCord](https://hub.spigotmc.org/jenkins/job/BungeeCord/) — the proxy software
- [mc-server-init](https://github.com/Team-MaRo/mc-server-init) — PID-1 console/signal handling
- [GitHub Actions](https://github.com/features/actions) — CI/CD

## Contributing

Please read [CONTRIBUTING.md][contributing] for details on our code of conduct and the process for submitting pull requests.

## Versioning

There is no project-specific versioning.

## Authors

### Special thanks for all the people who had helped this project so far

- **Manuele** - [D3strukt0r](https://github.com/D3strukt0r)

See also the full list of [contributors][gh-contributors] who participated in this project.

### I would like to join this list. How can I help the project?

We're currently looking for contributions for the following:

- [ ] Bug fixes
- [ ] Translations
- [ ] etc...

For more information, please refer to our [CONTRIBUTING.md][contributing] guide.

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.

## Acknowledgments

- Geoff Bourne with [itzg/docker-bungeecord](https://github.com/itzg/docker-bungeecord)
- James Rehfeld with [rehf27/docker-bungeecord](https://github.com/rehf27/docker-bungeecord)
- Leopere with [Leopere/docker-bungeecord](https://github.com/Leopere/docker-bungeecord)
- Hat tip to anyone whose code was used
- Inspiration
- etc

[docker]: https://hub.docker.com/r/d3strukt0r/bungeecord
[codacy]: https://www.codacy.com/manual/D3strukt0r/docker-bungeecord
[gh-action]: https://github.com/Team-MaRo/docker-bungeecord/actions
[gh-contributors]: https://github.com/Team-MaRo/docker-bungeecord/contributors
[contributing]: https://github.com/Team-MaRo/.github/blob/master/CONTRIBUTING.md
[code-of-conduct]: https://github.com/Team-MaRo/.github/blob/master/CODE_OF_CONDUCT.md
