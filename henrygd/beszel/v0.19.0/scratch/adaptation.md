# LoongArch64 adaptation

The upstream v0.19.0 Hub Dockerfile uses Docker Hub's Go Alpine image with `--platform=$BUILDPLATFORM`. The official `golang:1.27.1-alpine` image index did not provide `linux/loong64`, so the successful native build uses the verified LoongNix builder `lcr.loongnix.cn/library/golang:1.27.1-alpine` and removes the host-platform selector. The pulled image runs Go 1.27.1 on `linux/loong64`.

The upstream workflow builds with repository-root context `./` and selects `internal/dockerfile_hub`. With that context, Docker's legacy builder rejected the original `COPY ../go.mod ../go.sum ./` as outside the build context. The accepted change to `COPY go.mod go.sum ./` uses the same root module files and matches the official workflow context.

No application Go source changed. The build embeds the user's x86_64-generated, architecture-independent v0.19.0 HTML/CSS/JS under `internal/site/dist/`, compiles the Hub with `CGO_ENABLED=0`, and retains the upstream `scratch` runtime layout, data volume and port.
