# Beszel Hub v0.19.0 - LoongArch64

This recipe records the locally built and smoke-tested Hub image `beszel:0.19.0-loong64` for `linux/loong64`, using upstream commit `ffcdb041670a501611727848649d28d886beb231`, user-supplied frontend assets, and a minimally adapted copy of the official Hub Dockerfile.

## Prepared inputs

- Source: https://github.com/henrygd/beszel, tag `v0.19.0`, resolved commit `ffcdb041670a501611727848649d28d886beb231`.
- Frontend archive: `beszel-hub-static-assets-v0.19.0.zip`, supplied by the user from an x86_64 v0.19.0 frontend build. SHA-256: `ba7ba509678667091d0e07a84d2f14c0061eccf40abb200a4fbe1526a22260a4`. It contains 83 regular files (3,041,236 uncompressed bytes) with `index.html`, `assets/` and `static/` at its root. This architecture-independent web content is consumed by `//go:embed all:dist` in `internal/site/embed.go`. The recipe does not include or regenerate it; supply this archive or a separately validated v0.19.0 equivalent.
- The official source does not track `internal/site/dist/`, and its v0.19.0 frontend lockfile lacks LoongArch native generator packages. The successful build used the supplied static output.
- Builder image: `lcr.loongnix.cn/library/golang:1.27.1-alpine`, verified as `linux/loong64`, Go 1.27.1 and Alpine 3.24.2. Its registry manifest digest observed for the task was `sha256:b1fdf1c4395bc47cc2e5be5398822742b92128ac2f4acde206912f6b5979a677`; the Dockerfile uses the tag rather than a digest-pinned FROM.
- `Dockerfile.hub` is the exact adapted file used by the successful build. `patches/loongarch.patch` records its changes from the official `internal/dockerfile_hub`.

## Prepare source and assets

Set `WORKSPACE`, `RECIPE_DIR` and `ASSET_ZIP` to local paths. Use a clean workspace and a native LoongArch64 host with Docker CLI/daemon access and `git`/ `unzip` in the helper. Check out the exact commit, verify the supplied archive, extract its root contents to the embed directory, and install the accepted Dockerfile:

~~~sh
set -eu
: "${WORKSPACE:?set WORKSPACE}"
: "${RECIPE_DIR:?set RECIPE_DIR}"
: "${ASSET_ZIP:?set ASSET_ZIP}"

mkdir -p "$WORKSPACE"
git clone https://github.com/henrygd/beszel.git "$WORKSPACE/beszel"
git -C "$WORKSPACE/beszel" checkout --detach ffcdb041670a501611727848649d28d886beb231
test "$(git -C "$WORKSPACE/beszel" rev-parse HEAD)" = ffcdb041670a501611727848649d28d886beb231

printf '%s  %s\n' ba7ba509678667091d0e07a84d2f14c0061eccf40abb200a4fbe1526a22260a4 "$ASSET_ZIP" | sha256sum -c -
unzip -tqq "$ASSET_ZIP"
mkdir -p "$WORKSPACE/beszel/internal/site/dist"
unzip -q "$ASSET_ZIP" -d "$WORKSPACE/beszel/internal/site/dist"
test -s "$WORKSPACE/beszel/internal/site/dist/index.html"

cp "$RECIPE_DIR/Dockerfile.hub" "$WORKSPACE/beszel/internal/dockerfile_hub"
~~~

The successful task used this normalized layout: `index.html`, `assets/` and `static/` directly under `internal/site/dist/`.

## Build

Run from the repository root on a native LoongArch64 Docker daemon. The build uses the verified Go 1.27.1 LoongArch builder, downloads modules using the upstream `go.mod`/`go.sum`, builds the Hub with CGO disabled and packages it in `scratch`.

~~~sh
cd "$WORKSPACE/beszel"
docker build --build-arg TARGETOS=linux --build-arg TARGETARCH=loong64 -f internal/dockerfile_hub -t beszel:0.19.0-loong64 .
~~~

The upstream v0.19.0 workflow uses repository-root context `./`. The accepted Dockerfile copies `go.mod` and `go.sum` from that context, which also works with Docker's legacy builder. The successful build used no Buildx platform emulation or proxy overlay.

## Verification

The recorded check inspected image identity/configuration, started the image natively with temporary data storage, then used the builder image as a network sidecar to fetch `http://127.0.0.1:8090/` until the Hub was ready:

~~~sh
set -eu
image_meta=$(docker image inspect --format '{{.Id}}|{{.Os}}/{{.Architecture}}|{{.Size}}|{{json .Config.Entrypoint}}|{{json .Config.Cmd}}' beszel:0.19.0-loong64)
printf 'IMAGE=%s\n' "$image_meta"
case "$image_meta" in *'|linux/loong64|'*) ;; *) exit 1 ;; esac
docker run -d --rm --name beszel-hub-smoke --tmpfs /beszel_data beszel:0.19.0-loong64
trap 'docker rm -f beszel-hub-smoke >/dev/null 2>&1 || true' EXIT
docker run --rm --network container:beszel-hub-smoke --entrypoint /bin/sh lcr.loongnix.cn/library/golang:1.27.1-alpine -c 'i=0; until wget -q -T 2 -O /tmp/beszel-index.html http://127.0.0.1:8090/; do i=$((i+1)); if [ "$i" -ge 30 ]; then echo "Hub did not return HTTP 200" >&2; exit 1; fi; sleep 1; done; test -s /tmp/beszel-index.html; grep -qi "<!doctype html" /tmp/beszel-index.html; echo "HTTP 200; HTML bytes=$(wc -c </tmp/beszel-index.html)"'
docker logs beszel-hub-smoke
~~~

The response was HTTP 200 with 1,214 bytes of dashboard HTML beginning with `<!doctype html>`; logs reported listening on `0.0.0.0:8090`. The test container was removed after verification. The verified image is `sha256:6415166519f88f83a9e5f3e97d6eefd61b1e01f5745305e2f640968fc857a32c`, `linux/loong64`, 31,770,236 bytes, entrypoint `/beszel`, default command `serve --http=0.0.0.0:8090`.

A normal deployment can publish port 8090 and persist `/beszel_data`:

~~~sh
docker run -d --name beszel \
  -p 8090:8090 \
  -v beszel_data:/beszel_data \
  beszel:0.19.0-loong64
~~~

The image was verified locally and was not pushed to a registry.
