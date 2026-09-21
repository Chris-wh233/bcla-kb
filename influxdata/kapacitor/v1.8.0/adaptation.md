# LoongArch64 adaptation

Kapacitor v1.8.0's official Alpine definition downloads an amd64 archive, so that input was rejected for `linux/loong64`. The accepted build uses the official Alpine runtime layout and configuration, while compiling the two Kapacitor binaries in a LoongArch64 Alpine helper.

Kapacitor imports Flux's `libflux.Options` through cgo. A cgo-disabled Go build therefore cannot produce the requested feature-complete binaries. Flux v0.191.0 `libflux` was built natively with the helper's Rust toolchain after updating the helper-only Cargo dependency lock to `libc 0.2.172`; the build used `RUSTFLAGS=--cap-lints allow` because the old Flux source emits warnings rejected by modern Rust. These changes were confined to the helper module cache and are not present in the final image.

The helper creates a temporary `flux.pc` pointing at `libflux/target/release/libflux.a` and `libflux/include`, then builds both commands with cgo enabled, the `static_build` tag, and external static linking. The resulting ELF files are LoongArch64 and have no dynamic section. The final image copies only those binaries plus the official `entrypoint.sh` and `kapacitor.conf`; it contains no helper toolchain, Cargo cache, module proxy, or proxy environment variables.

No tracked Kapacitor source file was patched. The companion `patches/loongarch.patch` records that fact; the reproducible adaptation is the helper-side dependency/toolchain setup and the final Dockerfile.
