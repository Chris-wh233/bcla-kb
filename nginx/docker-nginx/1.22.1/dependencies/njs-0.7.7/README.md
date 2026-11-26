# njs 0.7.7 for nginx 1.22.1 Alpine

Canonical source: https://github.com/nginx/njs at tag0.7.7, commit6af74b6c5e120595e11df74ca8749021e5f2a7e1. The original task compared all tracked release files. patches/loongarch.patch retains upstream WebCrypto fix85ce59830cd54186c0125982614ff9a61efdc5b0.

The parent's single-stage Dockerfile downloads this source and applies the byte-identical root njs-webcrypto.patch. It repacks the patched source, updates the packaging SHA512 entry and compiles with official pkg-oss make all. The module prebuild executes configure, make njs and moves build to build-cli; nginx then builds its HTTP/stream dynamic modules. There is no separate dependency build stage, cached source bundle, prebuilt APK input or host compilation.

Use the build command and context preparation in ../../README.md. GCC15 compatibility comes from ../../abuild-compat.conf. The signed module package is installed in the same RUN, and temporary source/package files are removed.

Accepted consumer: lcr.loongnix.cn/library/nginx:1.22.1-alpine, immutable image sha256:06fdb06b2cfec3cfaf6166fc054b9fefc7fc6937b16afc8e02a270db1639859f, linux/loong64 musl. njs -v reported0.7.7; all six nginx dynamic modules loaded, and AES-GCM/invalid key-format checks passed. Installed CLI/module content identities are in experience.json and ../../verification/runtime-inventory.txt. Old offline-build APK hashes do not identify this newly built image's packages and are not prerequisites.

Evidence codex-output:28feda is an existing conversation tool output, not a BCLA execution row. This recipe update reruns no builds/tests.
