# Flux libflux v0.191.0

Flux v0.191.0 (commit `b9d6eb68390c18de9f4e33f176337656babfc8cf`) was built as a native LoongArch64 musl library in the Alpine helper. The helper-only Cargo lock used `libc 0.2.172`, and the build used `RUSTFLAGS=--cap-lints allow` for this old source with the current Rust toolchain. The accepted output was `libflux.a` (65.9 MiB) plus `libflux.so` (10.4 MiB); Kapacitor consumed the static library through its cgo `static_build` path. No Flux library is copied into the final image.
