{
  description = "BungeeCord Minecraft proxy — Docker image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Shared OCI helpers (createdFromDate, fixOciImageHistory, secondsToNanos).
    nix-utils.url = "github:Team-MaRo/nix-utils";
    nix-utils.inputs.nixpkgs.follows = "nixpkgs";

    # Our PID-1 init (PTY console + named-pipe injection + signal→stop), built
    # from its own repo. The image bakes its binary in and execs it as PID 1.
    mc-server-init.url = "github:Team-MaRo/mc-server-init";
    mc-server-init.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-utils, mc-server-init }:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: lib.genAttrs systems
        (system: f (import nixpkgs { inherit system; }));

      dataDir = "/srv/bungeecord"; # FHS: site-specific data served by this system
      uid = "65532";
      port = 25565; # exposed/health-checked port; the entrypoint defaults the
                    # BungeeCord listener to this (the conventional Minecraft port)

      # BungeeCord jars are prebuilt Jenkins artifacts, identified by build NUMBER
      # (not semver). We pin each build's published jar by hash and fetch it
      # directly. `versions.json` is build# -> { mc, sha256 }; add/replace the
      # newest with .github/workflows/bump-latest.yml.
      versions = builtins.fromJSON (builtins.readFile ./versions.json);
      builds = builtins.attrNames versions;
      # Newest build number → `default`/`dockerImage` + the `latest` docker tag (CI).
      latest = lib.last (builtins.sort (a: b: lib.toInt a < lib.toInt b) builds);

      # Per-build JRE from ./jdk-boundaries.json. Each entry is
      # [ <min build#> <min JRE> <desired JRE> ], newest-first; the first bound the
      # build is >= to wins. The image runs on the DESIRED JRE (the last element) =
      # the JDK the build was COMPILED with — its manifest Build-Jdk, i.e. the Java
      # that was current when the build was made — floored to 8 (nixpkgs has no JRE
      # 7). <min JRE> is the bytecode floor, kept for reference. Build-Jdk transitions
      # (verified from manifests): Java 8→11 at build 1604, 11→17 at 1724, 17→21 at
      # 2063. Two runtime constraints (the contemporary JDK avoids both): the bytecode
      # REQUIRES >= 17 from build 2054 (Bootstrap gate), and builds 948–1604 embed a
      # SecurityManager (removed in JDK 24) so they cannot run on JRE 24+.
      jdkBoundaries = builtins.fromJSON (builtins.readFile ./jdk-boundaries.json);
      jdkMajorFor = build:
        let
          b = lib.toInt build;
          match = lib.findFirst (e: b >= builtins.elemAt e 0) null jdkBoundaries;
        in
        if match == null then "8" else lib.last match;

      jdkForPkgs = pkgs: {
        "8" = pkgs.jdk8_headless;
        "11" = pkgs.jdk11_headless;
        "17" = pkgs.jdk17_headless;
        "21" = pkgs.jdk21_headless;
        "25" = pkgs.jdk25_headless;
      };

      # Cloudflare in front of hub.spigotmc.org 403s non-browser User-Agents, so the
      # jar fetch must send a browser UA (the default Nix/curl UA gets blocked).
      jenkinsUA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
      # Builds < 680 published the jar under proxy/target; >= 680 under bootstrap/target.
      jarUrl = build:
        let sub = if lib.toInt build < 680 then "proxy" else "bootstrap";
        in "https://hub.spigotmc.org/jenkins/job/BungeeCord/${build}/artifact/${sub}/target/BungeeCord.jar";

      # docker/metadata-action labels (KEY=VAL\n…) serialised to JSON by CI and read
      # via `--impure`. The ONLY impure input — image metadata, not a build artifact.
      labelsJson = builtins.getEnv "DOCKER_LABELS_JSON";
      labels = if labelsJson == "" then { } else builtins.fromJSON labelsJson;
    in
    {
      packages = forAllSystems (pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          jdkFor = jdkForPkgs pkgs;

          # Ship a runtime, not the full JDK. Java 9+ → jlink a runtime with EVERY
          # module (ALL-MODULE-PATH) so any plugin still works; only dev tools/jmods/
          # debug are dropped. Java 8 predates jlink, so ship the (smaller) headless
          # JDK 8 as-is. The headless source keeps java.desktop's AWT libs (no X11).
          # jre_minimal takes both `jdk` (jmods to link) and `jdkOnBuild` (the jlink
          # binary); override BOTH so jlink can read the chosen JDK's jmods. jlink
          # bakes the source JDK store path into lib/modules (would drag the full
          # ~680 MB JDK into the closure) — scrub it and assert it's gone.
          mkJre = major: jdk:
            if major == "8" then jdk
            else
              let
                raw = pkgs.jre_minimal.override {
                  inherit jdk;
                  jdkOnBuild = jdk;
                  modules = [ "ALL-MODULE-PATH" ];
                };
              in
              pkgs.runCommand "bungeecord-jre-${major}"
                {
                  nativeBuildInputs = [ pkgs.removeReferencesTo ];
                  disallowedReferences = [ jdk ];
                } ''
                cp -r ${raw} $out
                chmod -R u+w $out
                find $out -type f -exec remove-references-to -t ${jdk} {} +
              '';

          # Our PID-1 init (github:Team-MaRo/mc-server-init): runs the server behind a
          # PTY (JLine keeps the `>` prompt), forwards the container's stdin AND a
          # named pipe at /tmp/console-in into the console, and on SIGTERM/SIGINT
          # sends a clean graceful-stop command, SIGKILL only after a timeout.
          mcServerInit = mc-server-init.packages.${system}.default;

          # `docker exec <c> console <cmd>` → inject a console command via the named
          # pipe mc-server-init feeds to the server's stdin (no RCON).
          console = pkgs.writeShellScriptBin "console" ''
            printf '%s\n' "$*" > /tmp/console-in
          '';

          inherit (nix-utils.lib.oci) secondsToNanos createdFromDate;
          fixHistoryScript = nix-utils.packages.${system}.fixOciImageHistory;

          jar = build: pkgs.fetchurl {
            url = jarUrl build;
            hash = versions.${build}.sha256;
            curlOptsList = [ "--user-agent" jenkinsUA ];
          };

          # Build the image for one BungeeCord build number.
          mkImage = build:
            let
              javaMajor = jdkMajorFor build;
              jre = mkJre javaMajor (jdkFor.${javaMajor} or pkgs.jdk21_headless);

              entrypoint = pkgs.writeShellApplication {
                name = "bungeecord-entrypoint";
                runtimeInputs = [ jre pkgs.yq-go pkgs.coreutils pkgs.gnugrep pkgs.bashInteractive mcServerInit ];
                text = builtins.readFile ./src/entrypoint.sh;
              };

              # Bake the (pinned) jar at /opt/bungeecord.jar — an image layer, never
              # in the data volume, so it is not on the host.
              jarLayer = pkgs.runCommand "bungeecord-jar-layer" { } ''
                mkdir -p $out/opt
                cp ${jar build} $out/opt/bungeecord.jar
              '';

              dockerImageStream = pkgs.dockerTools.streamLayeredImage {
                name = "d3strukt0r/bungeecord";
                tag = build;
                created = createdFromDate self.lastModifiedDate;

                contents = [
                  pkgs.dockerTools.usrBinEnv
                  (pkgs.dockerTools.fakeNss.override {
                    extraPasswdLines = [ "nonroot:x:65532:65532:nonroot:${dataDir}:/sbin/nologin" ];
                    extraGroupLines = [ "nonroot:x:65532:" ];
                  })
                  pkgs.bashInteractive
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.yq-go
                  jre
                  entrypoint
                  console
                  jarLayer
                ];

                enableFakechroot = true;
                fakeRootCommands = ''
                  mkdir -p .${dataDir}
                  chown -R ${uid}:${uid} .${dataDir}
                  chown ${uid}:${uid} etc/profile.d
                '';
                extraCommands = ''
                  mkdir -p tmp
                  chmod 1777 tmp
                  mkdir -p etc/profile.d
                  printf '%s\n' 'for f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done' > etc/profile
                '';

                config = {
                  User = "${uid}:${uid}";
                  WorkingDir = dataDir;
                  Entrypoint = [ "${entrypoint}/bin/bungeecord-entrypoint" ];
                  Env = [
                    "HOME=${dataDir}"
                    "JVM_FLAGS_PRESET=none" # a proxy doesn't want server GC packs (e.g. aikars)
                    "JAVA_MAJOR=${javaMajor}"
                    "PATH=/bin:/usr/bin"
                    ''PS1=🐳 \e[38;5;10m\u@\h\e[0m:\e[38;5;12m\w\e[0m\$ ''
                  ];
                  ExposedPorts = { "${toString port}/tcp" = { }; };
                  Volumes = { "${dataDir}" = { }; };
                  # /dev/tcp is a bash feature; opening the socket exits 0 if the port
                  # is accepting, proving the proxy is listening.
                  Healthcheck = {
                    Test = [ "CMD" "bash" "-c" "exec 3<>/dev/tcp/localhost/${toString port}" ];
                    Interval = secondsToNanos 30;
                    Timeout = secondsToNanos 5;
                    StartPeriod = secondsToNanos 120;
                  };
                  Labels = labels;
                };
              };
            in
            pkgs.runCommand "bungeecord-image-${build}.tar" { } ''
              ${dockerImageStream} | ${fixHistoryScript} > $out
            '';

          # One image per build: `nix build --impure .#"2080"`.
          perBuild = lib.genAttrs builds mkImage;
        in
        perBuild // {
          default = perBuild.${latest};
          dockerImage = perBuild.${latest}; # convenience alias for the newest build
        });

      # CI helper: each build × its MC version × runtime JDK, derived from the same
      # pinned data the images use. Read with `nix eval --json .#imageMatrix`.
      imageMatrix = builtins.map
        (b: { bungeecord = b; mc = versions.${b}.mc; java = jdkMajorFor b; })
        builds;

      # Newest build number (the one that also gets the `latest` docker tag).
      latestBuild = latest;
    };
}
