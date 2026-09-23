# Grafana v13.2.0 LoongArch64 adaptation

Source commit: `f681b1359f6a0b8ecb9f2c49a88ac72b75bde73b`
Target: `linux/loong64`
Accepted patch: `patches/loongarch.patch`

The successful image used the official Grafana v13.2.0 Docker build flow and changed only the following project inputs:

1. Mapped the Dockerfile frontend syntax image and Alpine/Node/Go base images to verified LoongArch images from `lcr.loongnix.cn`. The exact Go 1.26.6 Alpine tag was unavailable in the verified registry listing, so Go 1.26.7 Alpine was used; it satisfies the module's Go 1.26.6 minimum.
2. Replaced the Go-stage `COPY --parents **/go.mod **/go.sum ./` instruction with `COPY . .`. The accepted LoongArch Dockerfile frontend did not support the upstream `--parents` form; the replacement preserves the source consumed by `go mod download`.
3. Replaced `@swc/core@1.13.3` with the API-compatible `npm:@swc/wasm@1.13.3` in the root manifest and the two workspace manifests that declare it, then regenerated the Yarn lockfile. The native SWC 1.13.3 package set had no LoongArch binary, while the WebAssembly implementation allowed the official frontend build to complete.

No frontend bundle was copied from another architecture and no Grafana feature was intentionally removed. The final Docker build ran the Nx/Grafana frontend build and the Go backend build inside the image build. The build log reported that the Grafana frontend target and its five dependent tasks completed successfully; the backend stage ran `make build-go GO_BUILD_TAGS=oss WIRE_TAGS=oss` and produced a `linux/loong64` binary.

The accepted patch does not include trial adaptations or unused dependency changes. Only the `final-alpine` target was built and tested for this task; the upstream Ubuntu and distroless targets are not claimed as verified by this recipe.
