# EMQX Enterprise 6.3.0 — Debian 14 / LoongArch64

This recipe records the verified emqx-enterprise:6.3.0-loong64-debian14 image. It uses the official EMQX Dockerfile from upstream commit 021c5ef13bf8c767058626ad9b760052c273736f, minimally adapted to support LoongArch64 and the requested Debian 14 slim base.

## Prepared inputs

- EMQX source: https://github.com/emqx/emqx.git, tag 6.3.0, resolved commit 021c5ef13bf8c767058626ad9b760052c273736f.
- EMQX runtime archive: https://github.com/loongarch64-releases/emqx/releases/download/6.3.0/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz, with its .sha256 sidecar. Verified archive SHA-256: fbf1f7a2df89598fc21b0ad0ba63de0677d28cd54f62f3283221286e7b43d48d. The archive contains the native beam.smp runtime and is consumed by the Dockerfile's builder_tgz stage; this recipe does not compile EMQX from source.
- Base: lcr.loongnix.cn/library/debian:14-slim, verified for linux/loong64, image ID sha256:b2ef0a3db09e1bb568ef1e5387fa71117cd202411fa6819c4a126bf9374bc72b.
- Static curl input: stunnel/static-curl 8.20.0 LoongArch64 glibc archive, https://github.com/stunnel/static-curl/releases/download/8.20.0/curl-linux-loongarch64-glibc-8.20.0.tar.xz, verified SHA-256 5fb7ee101c620556fa64faa1a72c2e000fb23108c8567ea1a1e297d4ce7c4c33. It is checksum-validated in the temporary curl stage; only the static curl binary is copied to the final image.
- Dockerfile.loong64-debian14 is the exact accepted Dockerfile used by the successful build. patches/loongarch.patch captures its changes relative to the official v6.3.0 Dockerfile.
- Build helper evidence: native LoongArch64 Docker daemon with Docker Buildx 0.29.1. BCLA direct=true was used for networked build and smoke commands; proxy settings are not baked into the image.

## Build

Set WORKSPACE to a clean working directory and RECIPE_DIR to this recipe directory. The prepared artifact and source checkout must match the versions and hashes above.

~~~sh
set -eu
cd "$WORKSPACE"
git clone --depth 1 --branch 6.3.0 https://github.com/emqx/emqx.git emqx-src
test "$(git -C emqx-src rev-parse HEAD)" = 021c5ef13bf8c767058626ad9b760052c273736f

mkdir -p emqx630-candidate
curl -fL --retry 2 -o emqx630-candidate/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz \
  https://github.com/loongarch64-releases/emqx/releases/download/6.3.0/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz
curl -fL --retry 2 -o emqx630-candidate/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz.sha256 \
  https://github.com/loongarch64-releases/emqx/releases/download/6.3.0/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz.sha256
expected=$(tr -d '\r\n ' < emqx630-candidate/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz.sha256)
actual=$(sha256sum emqx630-candidate/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz | cut -d ' ' -f1)
test "$actual" = "$expected"
test "$actual" = fbf1f7a2df89598fc21b0ad0ba63de0677d28cd54f62f3283221286e7b43d48d

cp emqx630-candidate/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz \
  emqx-src/emqx-enterprise-6.3.0-debian13-loong64.tar.gz
cp "$RECIPE_DIR/Dockerfile.loong64-debian14" emqx-src/deploy/docker/Dockerfile

src=emqx-src
pkg=emqx630-candidate/emqx-enterprise-6.3.0-debian-loongarch64.tar.gz
expected=fbf1f7a2df89598fc21b0ad0ba63de0677d28cd54f62f3283221286e7b43d48d
actual=$(sha256sum "$pkg" | cut -d ' ' -f1)
test "$actual" = "$expected"
test "$(sha256sum "$src/emqx-enterprise-6.3.0-debian13-loong64.tar.gz" | cut -d ' ' -f1)" = "$expected"
docker buildx build --load --progress=plain --platform linux/loong64 \
  --build-arg BUILD_FROM=lcr.loongnix.cn/library/debian:14-slim \
  --build-arg RUN_FROM=lcr.loongnix.cn/library/debian:14-slim \
  --build-arg SOURCE_TYPE=tgz \
  --build-arg PROFILE=emqx-enterprise \
  --build-arg PKG_VSN=6.3.0 \
  -t emqx-enterprise:6.3.0-loong64-debian14 \
  -f "$src/deploy/docker/Dockerfile" "$src"
~~~

The successful build used those exact build arguments and command. The BCLA build helper's base tag currently resolves apt packages from Debian unstable; apt-get upgrade and unpinned packages therefore make the image's package layer time-dependent even though the requested base image is pinned by the tag/digest above.

## Verification

~~~
set -eu
img=emqx-enterprise:6.3.0-loong64-debian14
docker image inspect --format 'ID={{.Id}} OS={{.Os}} ARCH={{.Architecture}} USER={{.Config.User}} ENTRYPOINT={{json .Config.Entrypoint}} CMD={{json .Config.Cmd}} ENV={{json .Config.Env}}' "$img"
docker run --rm --platform linux/loong64 --entrypoint /opt/emqx/bin/emqx "$img" check_config

name="emqx630-smoke-$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT
docker run -d --platform linux/loong64 --name "$name" "$img"
i=0
until [ "$i" -ge 45 ]; do
  state=$(docker inspect --format '{{.State.Status}}' "$name")
  if [ "$state" != running ]; then docker logs "$name"; exit 1; fi
  if docker exec "$name" /opt/emqx/bin/emqx ping; then
    docker logs "$name" 2>&1 | tail -n 30
    break
  fi
  i=$((i + 1))
  sleep 2
done
test "$i" -lt 45
~~~

Verified image ID is sha256:04bb3a1f5e998827b4d8f18724b00bbf011f91314459a79f2d5a9e1547182b1b, platform linux/loong64, user emqx, official entrypoint /usr/bin/docker-entrypoint.sh, and command /opt/emqx/bin/emqx foreground. check_config exited 0; the default entrypoint started and emqx ping returned pong. The TCP MQTT (1883), TLS MQTT (8883), WebSocket (8083) and secure WebSocket (8084) listeners appeared in startup logs. The image environment contained only PATH and locale values, with no HTTP/HTTPS/ALL proxy variables.

The release's OTP build warns that RLOG is incompatible and falls back to Mnesia. Startup also warns that its default Erlang cookie is insecure; production deployments should set EMQX_NODE__COOKIE. No image push was performed.

Local evidence is task bcla-845320c7a3544eeb9417b52d8c31c41f, checkpoint revision 15. Successful build: exec-e5736f1c860b4a50ab715fcc0414996a; passing configuration check: exec-e1bc2e9037be48b8b6b4fc85779bf5a2; passing startup probe: exec-e313de576a6149749d0e98d168f31260.
