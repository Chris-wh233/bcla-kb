# Alibaba Nacos 3.2.2

Native Linux/loong64 image recipe for `nacos:3.2.2-loong64`.

## Official inputs

- `nacos-server-3.2.2.tar.gz`: official Alibaba Nacos 3.2.2 release asset, consumed by the registered official `nacos-docker/build/Dockerfile.Lite`; SHA-256 `fae7bc641429dd660084ff24226bdc92ae9a0f40e2713f46f6285e5bd9d024eb`.
- Dockerfile source: `github.com/nacos-group/nacos-docker`, commit `e7257840821a4b74128b2186635bdd226d35c7a1`, file `build/Dockerfile.Lite`.

## Build

Working directory: `nacos-docker/build`.

```sh
docker build --pull=false --file Dockerfile.Lite --tag nacos:3.2.2-loong64 .
```

The `alpine:latest` base is resolved to the verified loong64 LCR image `lcr.loongnix.cn/library/alpine@sha256:409547fe91e3200310b558482055d111b01d50f89b13e4cb7769e8844c3aeb99`.

## Verification

Run with no network access:

```sh
docker run --rm --network none --entrypoint sh nacos:3.2.2-loong64 -c 'test -r /home/nacos/target/nacos-server.jar && java -version'
```

Verified image digest: `sha256:bf6d69eb0974651e65e640ae50213fd5af2c67afa09e8e392937963fb0cf19e7`.
