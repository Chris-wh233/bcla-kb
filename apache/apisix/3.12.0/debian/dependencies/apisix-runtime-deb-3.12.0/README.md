# Required APISIX runtime image

This is Stage 1 of the APISIX 3.12.0 image recipe and a mandatory local base for Stage 2. It builds `apache/apisix-runtime-deb:3.12.0` on pinned Debian Forky for `linux/loong64`; the final image's first instruction is `FROM apache/apisix-runtime-deb:3.12.0`.

The runtime payload was built from API7 `apisix-runtime/1.3.0`, commit `0cd7a9b31cb7b03320c98b724c8b88335b9029da`. `build-apisix-runtime-debian-loong64.sh` is the exact adapted script used by the successful build. `loongarch.patch` is the complete effective adaptation diff from the captured API7 script. The runtime rootfs input consumed by the Dockerfile had deterministic tar SHA-256 `0bc44c4d446a599bdbc923d940859ae9a1a809e5b90a22aee5a11fcb54628752`.

From the API7 source directory, with the staged Wasmtime artifact and Loongson LuaJIT checkout at the paths expected by the saved script, the successful runtime source build command was:

~~~sh
runtime_version=1.3.0 bash build-apisix-runtime-debian-loong64.sh
~~~

Place the installed runtime files in the parent image context's `runtime-rootfs/`, then from the APISIX recipe root build the standalone runtime image:

~~~sh
docker build -f image-context/Dockerfile.runtime -t apache/apisix-runtime-deb:3.12.0 image-context
~~~

Verified output: image ID `sha256:1dc51b3e0a750b4cd0b9bbded4a5ff41f558ab87329071e932d5b1737863cb5`, `linux/loong64`, 321,085,033 bytes, 3 layers. Tests confirmed OpenResty 1.27.1.1, Loongson LuaJIT 2.1.1783997243 (`jit.arch=loongarch64`), no unresolved nginx shared libraries, and a valid OpenResty configuration. The pinned Debian base is `lcr.loongnix.cn/library/debian:forky@sha256:f5ef929388a56fb070c8c86cd572e70b0241f13a227c624c36260ef067f43d2b`.
