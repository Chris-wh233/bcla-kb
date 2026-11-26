# FastDFS 6.15.3 / LoongArch64

Verified image: `happyfish100/fastdfs:6.15.3-loong64`, alias `fastdfs:6.15.3-loong64`.
Image ID: `sha256:54ff834850f7bb5790aed8260af9e44c362c7578d6342168208cded8b0fe9ad7` (linux/loong64, 165069159 bytes).

## Prepared inputs and consumers

| Input | Identity / acquisition | Consumer |
|---|---|---|
| FastDFS | happyfish100/fastdfs V6.15.3, 3aa443ce6b2a65b4f60986c6f3943b8b2bf25631 | tracker, storage, clients, libfdfsclient, configuration |
| libfastcommon | V1.0.83 ccc84945d397762e9d043a8436048966b9f95fe4 + exact upstream e009d75 backport | libserverframe, FastDFS, Nginx module |
| libserverframe | V1.2.11 848077797b9de6cbb47abad14a472cce78896d41 | FastDFS and Nginx module |
| fastdfs-nginx-module | e685b56bceb490c80368c57713686ebeb1729b55 | statically compiled into Nginx |
| Nginx | https://nginx.org/download/nginx-1.22.1.tar.gz; SHA256 9ebb333a9e82b952acd3e2b4aeb1d4ff6406f72491bab6cd9fe69f0dea737f31 | FastDFS HTTP endpoint |
| Native base | lcr.loongnix.cn/library/debian@sha256:f5ef929388a56fb070c8c86cd572e70b0241f13a227c624c36260ef067f43d2b | helper and final runtime; already contains glibc, PCRE2, zlib, libcrypt |

The recorded acquisition assessment checked distribution packages, configured LoongArch resources and release/CI repositories, then upstream assets. No suitable FastDFS/libraries/custom-module binary was found; native source build was selected. Refresh availability when reusing this recipe. Source-built dependencies have flat recipes under dependencies/.

## Native project artifact flow

All project commands run inside a bootstrapped native LoongArch64 helper with the workspace mounted at the identical host path and Docker socket available. Do not compile on the host. Use GCC 16.2.0, GNU Make 4.4.1 and glibc 2.43 for the recorded environment. `$RECIPE` is this recipe directory, accessible in the helper; `$WORKSPACE` is a fresh, writable build workspace.

The original official Dockerfile compiles internally. This accepted derived flow builds the install tree first using the captured build-native.sh, then packages that exact tree via COPY. The final Dockerfile has no compile or network step.

Install the same development package set in the helper:

```sh
apt-get update
apt-get install -y --no-install-recommends build-essential libpcre2-dev zlib1g-dev libssl-dev file libcrypt-dev
```

Recorded direct packages: build-essential 12.12+b1, libpcre2-dev 10.49-1, zlib1g-dev 1:1.3.dfsg+really1.3.2-4, libssl-dev 3.6.5-1, libcrypt-dev 1:4.5.2+20251210-1. Baseline tools include git, curl, ca-certificates, docker-cli and ripgrep. These are historical package versions, not a guarantee that moving distribution repositories retain them.

Prepare the exact consumed revisions and apply the accepted dependency patch:

```sh
cd "$WORKSPACE"
mkdir -p deps patches
git clone --depth 1 --branch V6.15.3 https://github.com/happyfish100/fastdfs.git source
git clone --depth 1 --branch V1.0.83 https://github.com/happyfish100/libfastcommon.git deps/libfastcommon
git clone --depth 1 --branch V1.2.11 https://github.com/happyfish100/libserverframe.git deps/libserverframe
git clone https://github.com/happyfish100/fastdfs-nginx-module.git deps/fastdfs-nginx-module
git -C deps/fastdfs-nginx-module checkout e685b56bceb490c80368c57713686ebeb1729b55
curl -fsSL https://nginx.org/download/nginx-1.22.1.tar.gz -o deps/nginx-1.22.1.tar.gz
tar xzf deps/nginx-1.22.1.tar.gz -C deps
cp "$RECIPE/dependencies/libfastcommon-1.0.83/patches/loongarch.patch" patches/libfastcommon-applied.patch
git -C deps/libfastcommon apply ../../patches/libfastcommon-applied.patch
cp "$RECIPE/build-native.sh" "$RECIPE/Dockerfile" "$RECIPE/.dockerignore" .
chmod +x build-native.sh
./build-native.sh
artifacts/rootfs/usr/bin/fdfs_storaged -V
file artifacts/rootfs/usr/bin/fdfs_storaged
```

Check clone commits and archive hash against the input table before compiling. Build order is libfastcommon → libserverframe → FastDFS (including libfdfsclient) → Nginx with fastdfs-nginx-module. Both helper installs (headers/libraries for subsequent compilation) and DESTDIR installs (preserved artifacts/rootfs) are necessary. The accepted script adjusts tracker stack size after copying official configs. It does not apply the libfastcommon patch; that is a preparation step above.

## Final image flow

Still inside the helper at `$WORKSPACE`:

```sh
DOCKER_BUILDKIT=0 docker build --network=none -t happyfish100/fastdfs:6.15.3-loong64 -t fastdfs:6.15.3-loong64 .
docker image inspect happyfish100/fastdfs:6.15.3-loong64
tar czf artifacts/fastdfs-6.15.3-linux-loong64.tar.gz -C artifacts/rootfs .
docker save happyfish100/fastdfs:6.15.3-loong64 | gzip > artifacts/fastdfs-6.15.3-loong64.docker.tar.gz
```

Retain artifacts/rootfs/usr/bin/fdfs_*, usr/lib/libfdfsclient.so, libfastcommon.so, libserverframe.so, and usr/local/nginx/sbin/nginx. Binary archive SHA256: a6096307ce81bdcd7334cfc6493db0e174b236f71056a47937e8a68f3b7e7d14. Docker archive SHA256: eb95290fdcca76b2b02dc05f9f523822e5bb4d17e022dea8285de9544179bbd5. The archives remain with the task; they are not embedded in the KB. Debug paths, timestamps and archive metadata can change hashes on a fresh rebuild; these identify the accepted outputs, not a bit-reproducibility promise.

## Functional verification

`$SMOKE_CONTAINER` is a fresh caller-chosen container name; the tested topology uses one container with self hostname fdfs-smoke. No helper environment overlays are passed to it.

```sh
mkdir -p smoke
docker run -d --name "$SMOKE_CONTAINER" --hostname fdfs-smoke -e FASTDFS_IPADDR=fdfs-smoke happyfish100/fastdfs:6.15.3-loong64
# Wait for fdfs_monitor to report ACTIVE before proceeding.
docker exec "$SMOKE_CONTAINER" sh -c '/usr/local/nginx/sbin/nginx -t; /usr/bin/fdfs_monitor /etc/fdfs/client.conf'
docker cp "$RECIPE/tests/read-write.sh" "$SMOKE_CONTAINER":/tmp/read-write.sh
docker exec "$SMOKE_CONTAINER" sh /tmp/read-write.sh
docker cp "$SMOKE_CONTAINER":/tmp/payload.txt smoke/payload.txt
docker cp "$SMOKE_CONTAINER":/tmp/uploaded-file-id smoke/file-id.txt
SMOKE_IP=$(docker inspect "$SMOKE_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
curl --noproxy '*' -fsS "http://$SMOKE_IP:8888/$(cat smoke/file-id.txt)" -o smoke/http-downloaded.txt
cmp smoke/payload.txt smoke/http-downloaded.txt
curl --noproxy '*' -fsS "http://$SMOKE_IP/" -o smoke/nginx-index.html
```

Create smoke/ before saving test files. Recorded results: tracker/storage ACTIVE, storage version 6.15.3; valid Nginx config; client upload/download and HTTP8888 download byte-for-byte equal; HTTP80 served; all dynamic libraries resolved; clean final environment. Payload/client-download/HTTP-download SHA256 was 2189987ae18dae086c082bb5413eed35ca33454f0989e2b86b1e9acd697d6f0a. Final image project-binary hashes exactly matched evidence/PROJECT-SHA256SUMS.

For external clients, configure FASTDFS_IPADDR and advertised storage addressing for a reachable deployment address. The smoke hostname topology verifies the image, not arbitrary NAT deployment. Native archives require compatible system libraries; use the image for the recorded runtime boundary.

No functionality was intentionally omitted. No helper cleanup or remote publication is part of this recipe. See adaptation.md for accepted changes. Task-local execution IDs in metadata identify evidence in the originating BCLA installation, not public URLs. Validation checks structure and file hashes; generation does not rerun the build.
