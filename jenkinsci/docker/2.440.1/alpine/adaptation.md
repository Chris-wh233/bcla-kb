# Jenkins 2.440.1 Alpine LoongArch64 adaptation

Source: https://github.com/jenkinsci/docker at commit `6fda6fcea4b9cb1696f485ab2b31cbbfa33fe374`, upstream file `17/alpine/hotspot/Dockerfile`.

Target: `jenkins:2.440.1-alpine-loongarch64` for `linux/loong64`. The accepted adapted Dockerfile is `Dockerfile.alpine-loongarch64`; `patches/loongarch.patch` applies to the upstream file and recreates it byte-for-byte (SHA-256 `06d8ec31f4e5e6309e38f1ce8122028539c83223d2836b3edc1f1dc7e5de06b9`).

The adaptation keeps the upstream Jenkins user, home and reference directories, support scripts, ports, volume, labels, and entrypoint. It changes the runtime and artifact inputs as follows:

1. Uses `alpine:latest`, which resolved to Alpine 3.24.4 on LoongArch64 in the verified build.
2. Removes the upstream downloaded JDK/jlink stage and installs Alpine's `openjdk17-loongarch-jre-headless` and `openjdk17-loongarch-jre` packages. The image check confirmed both packages at `17.0.17_p10-r0`; Java reported `OpenJDK 64-Bit Server VM`, version 17.0.17, on `loongarch64`.
3. Stages the official Jenkins 2.440.1 WAR and Plugin Installation Manager 2.12.15 JAR in the build context instead of downloading them during the image build. The Dockerfile checks both artifact hashes; the WAR's published checksum was also verified during acquisition.

All project-owned changes are in the adapted Dockerfile and its patch. The final image retained Jenkins 2.440.1 behavior and passed the `/login` HTTP 200 startup smoke test.
