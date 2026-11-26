# Wasmtime v37.0.0 C API for APISIX

Acquire Wasmtime v37.0.0 from `https://github.com/bytecodealliance/wasmtime`, source commit `7b3d6ae79e9153a2477668062f5622c10333925f`; the source archive SHA-256 was `02630200bab84e7423fd39e6985bfe1929bf84149f1a0af321b57181a25d8126`.

The successful native LoongArch build used Rust/Cargo 1.97.1 and CMake 4.3.4:

~~~sh
export CARGO_NET_RETRY=5
export CARGO_BUILD_JOBS=4
export RUSTFLAGS='-C target-feature=-crt-static'
cargo build --locked --release --manifest-path crates/c-api/artifact/Cargo.toml
~~~

The resulting `libwasmtime.so` SHA-256 was `4e1cf2209f6cbc52c6de971675af473b443e01e348cfef78a1cef53722c68000`. The ELF was LoongArch64 and dynamically depended on glibc system libraries. A C API smoke test compiled against the library and ran a WASM function returning `42`. Stage the shared library and C API headers under `runtime-stage/wasmtime-c-api/` before running the APISIX runtime build.
