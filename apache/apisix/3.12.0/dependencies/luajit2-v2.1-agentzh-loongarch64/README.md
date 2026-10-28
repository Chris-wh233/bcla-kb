# Loongson LuaJIT for APISIX 3.12.0

Use `https://github.com/loongson/luajit2.git`, branch `v2.1-agentzh-loongarch64`, pinned to commit `99cd1bd492c480c8dc7bec44309ca29df86b82b5`. This is the runtime's required LuaJIT source; do not substitute the upstream LuaJIT repository.

On a native LoongArch64 helper, the successful build used:

~~~sh
git clone --depth=1 --branch v2.1-agentzh-loongarch64 https://github.com/loongson/luajit2.git luajit2-loongarch64
make -C luajit2-loongarch64 clean
make -C luajit2-loongarch64 -j"$(nproc)" XCFLAGS='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'
rm -rf /tmp/loongson-luajit-stage
make -C luajit2-loongarch64 install PREFIX=/tmp/loongson-luajit-stage
LD_LIBRARY_PATH=/tmp/loongson-luajit-stage/lib /tmp/loongson-luajit-stage/bin/luajit -e 'print(jit.arch, jit.version); local s=0; for i=1,1000000 do s=s+i end; print(s)'
~~~

The source build produced shared library SHA-256 `58ea3581915d84fbe68964d7fd16b1056c0257002523be2843ec3989147c6b31`. Runtime checks reported `loongarch64 LuaJIT 2.1.1783997243`, completed the numeric loop, resolved `libluajit-5.1.so.2`, and passed `openresty -t`.
