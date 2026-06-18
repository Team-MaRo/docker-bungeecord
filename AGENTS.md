# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## What this repo is

`docker-bungeecord` builds and pushes the Docker image (`d3strukt0r/bungeecord`)
that wraps the [BungeeCord](https://www.spigotmc.org/wiki/bungeecord/) Minecraft
proxy. There is **no app source code** — this repo is **CI/CD + a Docker
entrypoint + pinned version data**. The "architecture" is the flake, the version
files, and the workflows.

Unlike its sibling `docker-spigot` (which consumes jars from a separate
`spigot-build` repo because Spigot must be compiled), **BungeeCord jars are
prebuilt Jenkins artifacts**, so the version/hash data lives **inline here** — no
second repo.

## Big picture

- **Built with Nix**, not a Dockerfile (`flake.nix`, `dockerTools.streamLayeredImage`).
  One image per BungeeCord **Jenkins build number**: `packages.<sys>."<build>"`
  (+ `default`/`dockerImage` = newest). The jar is a **hash-pinned `fetchurl`**
  baked at `/opt/bungeecord.jar`; the version is chosen by **attribute**
  (`.#"<build>"`), not an env var.
- **Versioning is by Jenkins build number, not semver.** `versions.json` maps
  `build# → { mc, sha256 }`. We publish the **last build before each Minecraft
  version bump** (so there's an image per MC version BungeeCord ever supported),
  discovered from each jar's manifest `Implementation-Version`.
- **The jar is fetched from the SpigotMC Jenkins.** Cloudflare 403s non-browser
  User-Agents, so the `fetchurl` sends a browser UA via `curlOptsList` (the
  default Nix/curl UA gets blocked). Path rule: build **< 680 → `proxy/target`**,
  else **`bootstrap/target`** (`…/<build>/artifact/<sub>/target/BungeeCord.jar`).
- **Per-build runtime JRE** from `jdk-boundaries.json` — see below.
- **Multi-arch**: `forAllSystems` (x86_64-linux + aarch64-linux); `streamLayeredImage`
  is single-arch, so CI builds each arch on a native runner and stitches a manifest.
- **`--impure` is only for OCI labels** (`DOCKER_LABELS_JSON`); the jar + version
  are pure, so a plain `nix build .#"<build>"` works (empty labels).
- **The build matrix comes from `.#imageMatrix`** — `[{bungeecord, mc, java}]`
  derived from `versions.json` + `jdk-boundaries.json`, matching what can be built.
  `.#latestBuild` is the newest build number.

### Key files

| Path | Role |
|---|---|
| `flake.nix` | Builds the OCI image per build number. Inline version model (no `spigot-build` input): reads `versions.json` + `jdk-boundaries.json`. `jarUrl`/`fetchurl` (Cloudflare UA) → `/opt/bungeecord.jar`; JRE from `jdkMajorFor` (the **desired** JRE = last element of the matched boundary). Inputs: `nixpkgs`, `nix-utils`, `mc-server-init`. Exposes `.#imageMatrix` + `.#latestBuild`. |
| `versions.json` | `build# → { mc, sha256 }`, newest first. The set of images. Hashes are SRI (`sha256-…`). |
| `jdk-boundaries.json` | `[[<min build#> <min JRE> <desired JRE>], …]`, newest-first; first bound the build is `>=` to wins. The image **runs on the desired** JRE; min is the bytecode floor (reference). |
| `src/entrypoint.sh` | Renders `config.yml` from `BUNGEE__` env (via `yq`), defaults the listener to `0.0.0.0:25565`, builds the JVM command, forwards leading-option CLI args to BungeeCord, then `exec mc-server-init --stop-command end -- java …` (PID 1). Packaged with `writeShellApplication`. |
| `.github/workflows/docker.yml` | `matrix` (from `.#imageMatrix`; `workflow_dispatch` selector `all`/`latest`/`missing`/`<build#>`, default `all`; `missing` diffs vs Docker Hub tags via `dockerhub-tags.sh`; push→`all`, schedule→`missing`) → `docker-build` (Nix image per build × arch + SBOM) → `docker-manifest` (multi-arch manifest, cosign sign/attest; tags = `<build#>` + `<mc>` + `latest`-on-newest) → `docker-attest` (SLSA) → `tag` (git `build-<n>` tag per build). |
| `.github/workflows/bump-latest.yml` | Resolves `lastStableBuild` → concrete build#, prefetches the jar hash + MC version, updates `versions.json`, and **commits directly to the default branch** via `secrets.GH_PAT` (the CI account that bypasses branch protection; amends if the previous commit was a bump). Family model: a new build of the current MC version rolls that entry; a new version is added (freezing the previous). |
| `.github/workflows/check-outdated.yml` | Weekly watchdog over the newest build's **image**: builds the StopOnStart plugin, pulls + boots the image behind it, and on missing/broken/`this build is outdated` dispatches `docker.yml`. Also the keepalive (re-arms the schedules). |
| `.github/check-outdated/StopOnStart.java` + `plugin.yml` | Tiny BungeeCord plugin (`onEnable()` → delayed `ProxyServer.getInstance().stop()`). Built in CI (not committed; `StopOnStart.jar` is gitignored). Uses only the long-stable API so it loads on builds 251→current. |
| `.github/scripts/dockerhub-tags.sh` | Lists a public repo's Docker Hub tags (for the `missing` selector). |
| `mc-server-init` (flake input → `github:Team-MaRo/mc-server-init`) | First-party PID-1 init (Rust). Runs the proxy on a **PTY** (JLine keeps the `>` prompt), forwards container stdin **and** `/tmp/console-in` into the console, and turns SIGTERM/SIGINT into a clean stop. We pass `--stop-command end` (BungeeCord's shutdown command, not `stop`). Bump with `nix flake update mc-server-init`. |

### JRE-per-build mapping

Each image runs on the **JDK the build was compiled with** (its contemporary Java —
the manifest `Build-Jdk`), floored to JDK 8 (nixpkgs has no JRE 7). `jdkMajorFor`
returns the *desired* JRE (last element of the matched `jdk-boundaries.json` entry).
All boundaries were found empirically (manifest `Build-Jdk` + booting):

| Minecraft (shipped) | Build | JRE |
|---|---|---|
| 1.4.7 – 1.16 | 251 … 1575 | 8 |
| 1.17 – 1.19 | 1609 / 1636 / 1708 | 11 |
| 1.20 – 1.21 | 1848 / 2053 | 17 |
| 26.1 (year-based) | 2080 | 21 |

`Build-Jdk` transitions: **8→11 at build 1604, 11→17 at 1724, 17→21 at 2063**.
Two runtime constraints the contemporary choice steers clear of: the bytecode
**requires Java 17 from build 2054** (its `Bootstrap` gate), and builds
**948–1604 embed a `SecurityManager`** (removed in JDK 24) so they can't run on
JRE 24+. **Build 701 (MC 1.6.4) is intentionally not published** — its bootstrap
does `java.version.startsWith("1.7")` and needs Java 7 exactly, which isn't
available via nixpkgs (nor reliably on arm64).

## Commands

```bash
# Build matrix CI uses (build × mc × JRE), and the newest build number:
nix eval --json .#imageMatrix
nix eval --raw  .#latestBuild

# Build one image locally (needs Linux + Nix). --impure only feeds labels.
nix build --impure '.#"2080"'          # or .#default / .#dockerImage for the newest
docker load < result                   # then: docker run -p 25565:25565 d3strukt0r/bungeecord:2080

# No local Nix (Windows/macOS)? Build inside the nixos/nix container (cold /nix
# re-fetches ~1.2 GB each run; don't mount a volume over /nix — it hides nix itself):
docker run --rm -v "C:/path/to/docker-bungeecord:/work" -v "C:/tmp:/out" -w /work nixos/nix \
  sh -c "nix build --extra-experimental-features 'nix-command flakes' '.#default' -o /tmp/result \
         && rm -f /out/image.tar && install -m644 \$(readlink -f /tmp/result) /out/image.tar"
docker load -i /tmp/image.tar          # tag is :2080; re-tag :latest if needed

# Build the StopOnStart plugin (compile against a BungeeCord jar; --release 8):
javac --release 8 -cp BungeeCord.jar -d plugin-build .github/check-outdated/StopOnStart.java
cp .github/check-outdated/plugin.yml plugin-build/ && jar cf StopOnStart.jar -C plugin-build .
```

There is no test suite; validate by building an image and booting it (look for
`Listening on /0.0.0.0:25565`), and by triggering workflows via `workflow_dispatch`.

## Conventions & gotchas

- **`yq` is the Go (mikefarah) `yq`**, which has **no `//=` operator** — use the
  explicit alternative assign: `yq -i '.a = (.a // "default")'`. (`//=` is a jq-ism;
  it fails with `'//' expects 2 args but there is 1` and, under `set -e`, kills the
  entrypoint.)
- **The entrypoint is `writeShellApplication`, which runs shellcheck and fails the
  build on *any* finding** (even info). E.g. `tr 'A-Z' 'a-z'` trips SC2018/SC2019 —
  use POSIX classes (`tr '[:upper:]' '[:lower:]'`). `bash -n` is not enough; mind
  shellcheck.
- **Jar fetch needs a browser User-Agent** (`curlOptsList` in `flake.nix`) —
  Cloudflare in front of `hub.spigotmc.org` 403s the default Nix/curl UA. The
  bump/check workflows that hit the Jenkins set the same UA.
- **Every workflow job and step has a `name:`**; actions are pinned to major
  versions (Dependabot tracks minors).
- **Files must be LF.** Nix's inline `''…''` build scripts break on CRLF
  (`$'\r': command not found`); `.gitattributes` enforces `eol=lf`.
- **`flake.lock` must be committed** (generate with `nix flake lock`); CI builds against it.
- **Commits are GPG-signed; commit-message body paragraphs are single lines** (no
  hard wraps — let viewers soft-wrap). When inserting "move" commits to preserve
  `git log --follow` across a rename, do a **content-free rename commit** (R100)
  before the commit that rewrites the file — never `git reset --hard` with
  uncommitted/un-pushed work present (use `git update-ref`/`commit --amend`).

### Container configuration (entrypoint contract)

- **Env → `config.yml`:** any `BUNGEE__…` var is split on `__` into a key path;
  segments are lowercased **verbatim** (BungeeCord uses snake_case — `_` is **not**
  turned into `-`, unlike docker-spigot); an all-digits segment is a list index.
  Values are YAML-typed. Examples: `BUNGEE__ONLINE_MODE=false`,
  `BUNGEE__SERVERS__LOBBY__ADDRESS=lobby:25565`,
  `BUNGEE__LISTENERS__0__PRIORITIES__0=lobby`. List-heavy sections are easier as a
  mounted `config.yml`. All vars support the `_FILE` Docker-secret suffix.
- **No EULA** (that's a Minecraft *server* thing, not the proxy).
- **Port 25565, not 25577.** The entrypoint defaults the listener to
  `0.0.0.0:25565` (the conventional MC port the image EXPOSEs + health-checks),
  overriding BungeeCord's own 25577 default — only when unset, so a mounted config
  or `BUNGEE__LISTENERS__0__HOST` still wins.
- **CLI args:** trailing args whose first token starts with `-` are forwarded
  straight to BungeeCord (no `SERVER_ARGS` env needed); a non-option first arg is a
  full override (`docker run … bash`).
- **JVM:** `MEMORY`/`INIT_MEMORY`/`MAX_MEMORY` (no default → JVM default heap),
  `JVM_FLAGS_PRESET` (`none` default / `velocity` — a proxy doesn't want a server
  GC pack like aikars), `JVM_OPTS` (appended last).
- **Process model:** `exec mc-server-init --stop-command end -- java …` → mc-server-init
  is **PID 1**, runs the proxy on a **PTY** (JLine `>` prompt), graceful `end` on
  `docker stop`. The PTY means `docker logs`/`docker compose logs` contain terminal
  escapes — in a merged compose view JLine's carriage returns overwrite the
  `service |` prefix, so use per-service logs (`docker compose logs -f bungeecord`).
- **Console (no RCON):** `docker exec <c> console "<cmd>"` (writes to
  `/tmp/console-in`); or `docker attach` to type at the `>` prompt.
- **Persistence:** single `/srv/bungeecord` volume; jar stays in the image. Runs as
  `nonroot` uid `65532` — a bind-mounted volume must be writable by it. On first
  boot BungeeCord downloads its `modules/` from the Jenkins (needs outbound network).

## Required secrets / vars

- `docker.yml`: `vars.IMAGE_NAME` (= `d3strukt0r/bungeecord`),
  `vars.DOCKERHUB_USERNAME` + `secrets.DOCKERHUB_TOKEN` (pushes). If absent, the
  manifest/attest steps skip cleanly (build + SBOM still run). Per-job
  `id-token: write` / `attestations: write` / `packages: write` for cosign + SLSA.
- `bump-latest.yml`: **`secrets.GH_PAT`** — a PAT for the CI account that bypasses
  branch protection, so it commits the version bump directly (no PR).
