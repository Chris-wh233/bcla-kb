# Jenkins 2.583 LoongArch64 adaptation

Source: https://github.com/jenkinsci/docker at commit
`42ea8b6681fac34a1a8b447644728e70b3eeaae0`, upstream file
`debian/Dockerfile`.

Target: native Debian `linux/loong64`, image tag `jenkins:2.583`.

The accepted adaptation is recorded in `patches/loongarch.patch` and the exact
resulting Dockerfile is `Dockerfile.debian.loong64`.

## Changes

1. Both upstream base-image references are replaced with the verified
   LoongArch64 Debian Forky digest
   `lcr.loongnix.cn/library/debian@sha256:f5ef929388a56fb070c8c86cd572e70b0241f13a227c624c36260ef067f43d2b`.
2. Debian package installation in both stages is routed through
   `http://mirrors.ustc.edu.cn/debian`.
3. The LoongArch64 Debian packages provide OpenJDK 21 and Git LFS. Git LFS is
   pinned to `3.8.0-1`; `openssh-client` is used for the Debian package name.
4. Jenkins 2.583 and plugin manager 2.15.0 are supplied as verified local
   inputs, with WAR SHA-256/GPG verification and plugin-manager SHA-256/version
   verification.
5. `libharfbuzz0b` is installed because the generated JRE's
   `libfontmanager.so` requires `libharfbuzz.so.0` at Jenkins startup.
6. The generated runtime is copied before the plugin-manager verification, so
   that verification uses the final Java runtime.

No Jenkins features were removed. The verified image started Jenkins on port
8080 and returned HTTP 403 to the unauthenticated smoke request after startup.
