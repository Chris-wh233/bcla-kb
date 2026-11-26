# Grafana v13.2.0 - LoongArch64

This recipe records the verified Grafana `v13.2.0` image `grafana:13.2.0-loong64` for `linux/loong64`. It uses upstream commit `f681b1359f6a0b8ecb9f2c49a88ac72b75bde73b`, the official multi-stage Dockerfile, and the minimal accepted LoongArch adaptations in `patches/loongarch.patch`.

## Result

The build completed both consumers used by the image:

- The official JS builder ran the Grafana Nx frontend target and its five dependent tasks successfully, producing the frontend assets copied into the image.
- The official Go builder ran `make build-go GO_BUILD_TAGS=oss WIRE_TAGS=oss` and produced the backend binary for `linux/loong64`.

The resulting image is:

- Image: `grafana:13.2.0-loong64`
- ID: `sha256:a428a37ecb55132c74a7ea36b4a5a7d55dac29a6b0ee85e5d368cac80777976d`
- Platform: `linux/loong64`
- Runtime version: `13.2.0`
- Smoke result: `/api/health` returned `database=ok`, `version=13.2.0`, `commit=unknown`

No frontend bundle from another architecture was used. No Grafana feature was intentionally removed.

## Prepare source

Use a clean source directory on a native LoongArch64 Docker host. The Docker daemon/buildx installation must be able to build and load `linux/loong64` images; emulation is not used.

~~~sh
set -eu
: "${WORKSPACE:?set WORKSPACE}"
: "${RECIPE_DIR:?set RECIPE_DIR}"

mkdir -p "$WORKSPACE"
git clone https://github.com/grafana/grafana.git "$WORKSPACE/grafana"
git -C "$WORKSPACE/grafana" checkout --detach f681b1359f6a0b8ecb9f2c49a88ac72b75bde73b
test "$(git -C "$WORKSPACE/grafana" rev-parse HEAD)" = f681b1359f6a0b8ecb9f2c49a88ac72b75bde73b

cd "$WORKSPACE/grafana"
git apply "$RECIPE_DIR/patches/loongarch.patch"
sha256sum Dockerfile
# Expected: dc3627a6ea03fa9768f8d656650af62d0ccbe7fcb61b9de89072a5380d70896c
~~~

The patch changes the Dockerfile base-image mappings, replaces the unsupported Go-stage `COPY --parents` form, and maps the unavailable native SWC package to `@swc/wasm@1.13.3` in the manifests and lockfile. See `adaptation.md` for the exact scope.

## Build

Run from the repository root:

~~~sh
cd "$WORKSPACE/grafana"
docker buildx build --progress=plain --load \
  --platform=linux/loong64 \
  --target final-alpine \
  --build-arg JS_PLATFORM=linux/loong64 \
  -t grafana:13.2.0-loong64 .
~~~

The accepted task used the following verified LoongArch base images:

- `lcr.loongnix.cn/library/alpine:3.24.1`, manifest digest `sha256:409547fe91e3200310b558482055d111b01d50f89b13e4cb7769e8844c3aeb99`
- `lcr.loongnix.cn/library/node:24-alpine`, manifest digest `sha256:6800d7441c0ca15d2327df31a5a33c48ab2d4ac442f0ed3156f197f9b0f8efb3`
- `lcr.loongnix.cn/library/golang:1.26.7-alpine`, manifest digest `sha256:74fb0c429745307ca7dd175f74ec1afcb4fd783d0bd9835d868858d9ec26d2a8`
- `lcr.loongnix.cn/docker/dockerfile:1.17.1`

The exact upstream Go `1.26.6-alpine` tag was not available in the verified LoongArch registry listing. Go `1.26.7-alpine` satisfies the repository's Go `1.26.6` minimum.

## Verify

Inspect the loaded image, its architecture, the Grafana version, and the ELF header:

~~~sh
set -eu
docker image inspect grafana:13.2.0-loong64 \
  --format 'image={{.Id}} arch={{.Architecture}} os={{.Os}} user={{.Config.User}} ports={{json .Config.ExposedPorts}}'
docker run --rm --platform=linux/loong64 --entrypoint=/bin/sh grafana:13.2.0-loong64 \
  -c 'uname -m; grafana server -v; od -An -tx1 -N20 /usr/share/grafana/bin/grafana'
~~~

Expected relevant output includes `arch=loong64 os=linux`, `loongarch64`, `Version 13.2.0`, and a LoongArch64 ELF header.

Run the startup smoke test:

~~~sh
set -eu
docker rm -f bcla-grafana-13-2-0-smoke >/dev/null 2>&1 || true
docker run -d --name bcla-grafana-13-2-0-smoke \
  -e GF_DATABASE_TYPE=sqlite3 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana:13.2.0-loong64 >/tmp/grafana-container-id
for i in "$(seq 1 60)"; do
  if docker exec bcla-grafana-13-2-0-smoke wget -qO- http://127.0.0.1:3000/api/health; then
    docker rm -f bcla-grafana-13-2-0-smoke >/dev/null
    exit 0
  fi
  sleep 2
done
docker logs bcla-grafana-13-2-0-smoke
docker rm -f bcla-grafana-13-2-0-smoke >/dev/null
exit 1
~~~

The verified response was:

~~~json
{"database":"ok","version":"13.2.0","commit":"unknown"}
~~~

The task used a Debian forky LoongArch helper with `docker-buildx 0.29.1+ds1-4` installed from the Debian unstable LoongArch system repository. This is a host-side build prerequisite, not a runtime dependency of Grafana.

## Scope

Only the upstream `final-alpine` target was built and tested. This recipe does not claim verification for the upstream Ubuntu or distroless targets. The image was verified locally and was not pushed to a registry.
