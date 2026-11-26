# Kapacitor v1.8.0 — Alpine/LoongArch64

This recipe reproduces the verified `kapacitor:1.8.0-alpine-loong64` image from Kapacitor commit `c5848b64d04a1dc4039611491891dd06872ef348`. The runtime follows the official `influxdata-docker` Alpine definition at commit `919cb35e19cfc9f48239b21455a5852f0ab4bd55`, using its `entrypoint.sh` and `kapacitor.conf`.

## Prepared inputs

- Source: `https://github.com/influxdata/kapacitor.git`, tag `v1.8.0`.
- Runtime inputs: `influxdata-docker/kapacitor/1.8/alpine/entrypoint.sh` and `kapacitor.conf` from the commit above.
- Base: `lcr.loongnix.cn/library/alpine@sha256:27cd2f3391166f399fa38eba6fe63a662114d99c1ccc62838471e03b9f4a0394` (Alpine 3.24.2, `linux/loong64`).
- Build helper: LoongArch64 Alpine with Go 1.26.8, Rust/Cargo 1.96.1, GCC/Clang, and pkg-config.
- Flux dependency: `github.com/influxdata/flux@v0.191.0`; its native `libflux` library is consumed by Kapacitor's cgo build.

The helper must have working Go and Cargo module access. Any access configuration is command-local and must not be copied into the Dockerfile or final image.

## Build flow

Run the following from a LoongArch64 Alpine helper with `WORKSPACE` set to the build workspace. The commands use the actual successful build entrypoints; paths are expressed through variables so they are not tied to a task directory.

```sh
set -eu
cd "$WORKSPACE"
P="$(go env GOMODCACHE)/github.com/influxdata/flux@v0.191.0"

# Native Flux/libflux prerequisite (helper-only)
cd "$P/libflux"
cargo update -p libc --precise 0.2.172
RUSTFLAGS='--cap-lints allow' cargo build --release

# Temporary pkg-config description for Flux's cgo bridge
FLUX_LIB="$P/libflux/target/release"
FLUX_INC="$P/libflux/include"
mkdir -p /tmp/flux-pkgconfig
cat >/tmp/flux-pkgconfig/flux.pc <<EOF
prefix=$P/libflux
libdir=$FLUX_LIB
includedir=$FLUX_INC
Name: flux
Description: InfluxDB Flux C library
Version: 0.154.0
Libs: -L\${libdir} -lflux
Libs.private: -ldl -lpthread -lm
Cflags: -I\${includedir}
EOF
export PKG_CONFIG_PATH=/tmp/flux-pkgconfig

# Kapacitor binaries
cd "$WORKSPACE/kapacitor"
go mod download
LDFLAGS='-s -linkmode external -extldflags "-static" -X main.version=1.8.0 -X main.branch=v1.8.0 -X main.commit=c5848b64d04a1dc4039611491891dd06872ef348 -X main.platform=OSS'
CGO_ENABLED=1 GOOS=linux GOARCH=loong64 CC=gcc \
  go build -trimpath -tags 'netgo osusergo static_build' \
  -ldflags "$LDFLAGS" -o "$WORKSPACE/out/kapacitord" ./cmd/kapacitord
CGO_ENABLED=1 GOOS=linux GOARCH=loong64 CC=gcc \
  go build -trimpath -tags 'netgo osusergo static_build' \
  -ldflags "$LDFLAGS" -o "$WORKSPACE/out/kapacitor" ./cmd/kapacitor

# Official-style Alpine runtime packaging
cd "$WORKSPACE"
docker build --pull=false -f Dockerfile.loong64-alpine \
  -t kapacitor:1.8.0-alpine-loong64 .
```

## Verification

```sh
docker image inspect kapacitor:1.8.0-alpine-loong64
docker run --rm --entrypoint /usr/bin/kapacitor \
  kapacitor:1.8.0-alpine-loong64 version
docker run --rm kapacitor:1.8.0-alpine-loong64 kapacitord version
```

The verified result is image ID `sha256:c9fd0584e116cc659ce0925bc58f848f186b96ac399567279f363d4fdd014e03`, platform `linux/loong64`, Alpine 3.24.2, entrypoint `/entrypoint.sh`, and command `kapacitord`. Both version probes report Kapacitor 1.8.0, the official runtime files and non-root `kapacitor` user are present, and the final image environment contains only `PATH` (no proxy or `GOPROXY`).

Local evidence is recorded in BCLA task `bcla-0565c87d0e2a422eab5ab5d1d30a8f55`, checkpoint revision 9. Successful build evidence is `exec-1856ab078db64e0f836857a3c66df526` (Flux), `exec-32fbee93b4fa4e7c8af450398b9f7054` (Kapacitor binaries), and `exec-ce2c17578c6745f08e5f5ca672af215e` (image); `exec-baf2ebbf4e784fcd80ac13aa82f41039` is the passing image inspection and smoke test.
