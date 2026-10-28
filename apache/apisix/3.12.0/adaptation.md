# LoongArch adaptations

The runtime image uses API7's APISIX runtime builder at `apisix-runtime/1.3.0` commit `0cd7a9b31cb7b03320c98b724c8b88335b9029da`. `patches/apisix-runtime/debian-loong64.patch` preserves the captured runtime adaptation. `patches/apisix-runtime/loongarch.patch` consolidates the complete effective delta from a clean upstream build script; use that consolidated patch alone when starting from upstream. The exact adapted script is retained in `dependencies/apisix-runtime-deb-3.12.0/`.

LuaJIT is built from `https://github.com/loongson/luajit2.git`, branch `v2.1-agentzh-loongarch64`, commit `99cd1bd492c480c8dc7bec44309ca29df86b82b5`. The installed runtime reports `jit.arch=loongarch64`; the dependency recipe records its tested build.

PCRE is PCRE1 8.45 and was built without `--enable-jit`. OpenResty was configured without `--with-pcre-jit`: LoongArch PCRE1 does not support JIT. The APISIX init change also skips `ngx.re` JIT stack sizing on LoongArch. The exact source-level one-line change is recorded in `patches/loongarch.patch`, and the final Dockerfile performs the equivalent guarded replacement in the image.

Wasmtime v37's C API library was built natively for LoongArch and staged into the runtime. Its smoke test executed a WASM function returning 42. The C API shared library is loaded from `/usr/local/openresty/wasmtime-c-api/lib`.

The runtime adaptation reuses a verified OpenSSL 3.2.0 prefix, stages the already-built Wasmtime C API into OpenResty, avoids `sudo` in the helper build, and omits `etcdctl`, which the official Debian APISIX image does not ship. No proxy settings are part of the image recipe.
