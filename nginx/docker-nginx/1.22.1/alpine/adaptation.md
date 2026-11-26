# Single-stage Alpine adaptation

Baseline: nginx/docker-nginx@fef51235521d1cdf8b05d8cb1378a526d2abf421, stable/alpine/Dockerfile. Dockerfile.upstream retains the original reference. Dockerfile is the exact successfully built maker version.

Preserve the baseline's single-stage source-build flow and formatting. For LoongArch64, use its source-build path directly; do not add another build stage or substitute separate host-built binaries. In one RUN, compile as nobody with pkg-oss alpine make all, sign/index packages, remove build dependencies, install the official runtime package selection and clean the temporary directory.

Required differences:

- Base image is the requested lcr.loongnix.cn/library/alpine:3.24.4.
- The temporary Alpine mirror substitution is restored before RUN finishes.
- Packaging is downloaded from fixed GitHub commit873a91379b6884c29e9cd00dc6a35a7c93102891. nginx1.22.1 and njs0.7.7 sources are downloaded in the Dockerfile; no source bundles or APK caches are copied into the image.
- abuild-compat.conf appends -Wno-error=unterminated-string-initialization to existing CFLAGS. Other -Werror checks stay enabled.
- njs-webcrypto.patch is upstream85ce59830cd54186c0125982614ff9a61efdc5b0, repairing the key-format string pointer lifetime. It is applied to the downloaded njs source before repacking. The packaging SHA512 entry is generated for that actual patched archive; a checksum patch for a previous tarball is not reused.
- apk index uses the generated .abuild key directory, and installation temporarily trusts the matching public key.
- patches/loongarch.patch records the IPv6 entrypoint adaptation to apk --no-network manifest nginx. The applied script remains included.
- The Dockerfile contains no SHA256 checks. Official packaging SHA512 and APK signature handling remain.

The new maker image and existing runtime checks are identified in verification/existing-evidence.json. Original BCLA task records remain historical source/patch evidence; they are not rewritten to claim that they produced the later maker image.
