# Apache APISIX 3.12.0 on Debian for LoongArch64

This verified recipe produces two local images in order. Stage 1 creates the required runtime image `apache/apisix-runtime-deb:3.12.0` from a pinned Debian Forky base. Stage 2 creates `apache/apisix:3.12.0` with `FROM apache/apisix-runtime-deb:3.12.0`. The runtime image must be present locally before Stage 2; the accepted `image-context/build-images.sh` builds the stages in that order.

The source identities are APISIX commit `75d94c051fc940a174fbdba4ce0588c13fecf864` from [apache/apisix](https://github.com/apache/apisix), and the official Debian Dockerfile at commit `b96636c559c05a118b4bfed1f193288bbad912a0` from [apache/apisix-docker](https://github.com/apache/apisix-docker). The original Dockerfile is retained as `Dockerfile.upstream.debian`; its SHA-256 is `0b1c8df229da1c754b920a6e327a58def5e129e060fb661b16b6021a3d2d35f3`.

## Prepared inputs

The image build context consumes two prepared trees that are intentionally not copied into this knowledge checkout:

| Input | Consumer | Verified identity and preparation |
| --- | --- | --- |
| `image-context/runtime-rootfs/` | Stage 1 `Dockerfile.runtime` | Deterministic tar SHA-256 `0bc44c4d446a599bdbc923d940859ae9a1a809e5b90a22aee5a11fcb54628752`. Build the OpenResty runtime with the API7 runtime recipe at source commit `0cd7a9b31cb7b03320c98b724c8b88335b9029da`, using the saved LoongArch adaptation and the LuaJIT, PCRE, and Wasmtime dependency recipes. Stage its installed files under this directory. |
| `image-context/apisix-rootfs/` | Stage 2 `Dockerfile` | Deterministic tar SHA-256 `392eed1ed3a411a66921af6758d529f96e74736b47e319ad7e82e8725f9cca1f`. From APISIX commit above, the successful task installed rockspec dependencies with `lua5.1 /usr/local/openresty/luajit/bin/luarocks install apisix-master-0.rockspec --tree=/usr/local/apisix/deps --only-deps`, then ran `make install ENV_INST_PREFIX=/usr/local ENV_INST_BINDIR=/usr/bin ENV_NGINX_EXEC=/usr/local/openresty/bin/openresty`. Stage the resulting application tree here. |
| `image-context/docker-entrypoint.sh` | Stage 2 | Included in this recipe; copied from the accepted official Debian image context. |

The rootfs hashes identify the successful task outputs, not a promise that package repositories or source archives will remain byte-identical. The Debian base is pinned to `lcr.loongnix.cn/library/debian:forky@sha256:f5ef929388a56fb070c8c86cd572e70b0241f13a227c624c36260ef067f43d2b`; the runtime Dockerfile installs a small set of Debian runtime packages at build time.

## Build

Use a native `linux/loong64` Debian helper with a working Docker daemon and the prepared inputs above. From a build workspace whose current directory contains this recipe's `image-context/` directory, the accepted stage driver is:

~~~sh
sh -n image-context/build-images.sh
./image-context/build-images.sh
~~~

The successful task execution built Stage 1 through that driver, then built the accepted, corrected Stage 2 Dockerfile directly. These commands show the concrete image build steps:

~~~sh
docker build -f image-context/Dockerfile.runtime -t apache/apisix-runtime-deb:3.12.0 image-context
docker build -f image-context/Dockerfile -t apache/apisix:3.12.0 image-context
~~~

The runtime Dockerfile creates `/usr/local/openresty` with LuaJIT reporting `jit.arch=loongarch64`. The final Dockerfile starts from the runtime image, copies the APISIX application rootfs, and applies the LoongArch JIT-stack guard. Do not build Stage 2 from Debian directly.

## Verified output

Both images are `linux/loong64`:

| Stage | Image ID | Size | Layers |
| --- | --- | ---: | ---: |
| 1, required runtime base | `sha256:1dc51b3e0a750b4cd0b9bbded4a5ff41f558ab87329071e932d5b1737863cb5` | 321,085,033 bytes | 3 |
| 2, APISIX | `sha256:739cd0baf0e69545c23c90bd0ac4b98aef7d85c27d6340e7ab2576332965d994` | 425,787,844 bytes | 6 |

Runtime checks confirmed OpenResty 1.27.1.1, Loongson LuaJIT 2.1.1783997243, resolved nginx shared libraries, and `openresty -t`. The APISIX startup smoke kept the container running and returned HTTP 503 from the deliberately unavailable `web1` upstream; there was no PCRE JIT allocation failure or worker crash. The 503 is the expected result for that smoke fixture.

For adaptation and architecture-specific constraints, see `adaptation.md`. The separate runtime image and source-built dependency recipes are under `dependencies/`.
