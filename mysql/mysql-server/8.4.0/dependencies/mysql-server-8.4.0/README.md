# MySQL 8.4.0 DEBs for Debian forky loong64

This dependency recipe produces twelve native DEBs, version 8.4.0-1debian14. No RPM is produced. The image recipe two directories above consumes nine runtime DEBs; the development and two testsuite packages remain separate deliverables. mysql-packages.json records the accepted bytes; a later rebuild need not be byte-reproducible (timestamps and a moving forky repository).

## Inputs and environment

Use a native LoongArch64 helper based on the immutable forky image in source-provenance.json. Supply ca-certificates, curl, git and a Docker CLI only if assembling/testing the image from that helper. GCC14 and g++14 must be selected explicitly. CMake 4 requires CMAKE_POLICY_VERSION_MINIMUM=3.5 for this upstream release. This is a historical verified combination, not a promise that future forky packages remain compatible.

Run in the helper with RECIPE_DIR set to this absolute recipe directory and WORKSPACE to a fresh writable build directory. All paths below are inside that helper. The source archive comes from the official MySQL archive; the recorded hash is locally calculated. Bundled Boost/ICU/libtirpc and other bundled code come from that archive. There are no independently source-built third-party dependencies. System FIDO/Kerberos/OpenSSL/Mecab/NUMA and other development dependencies are acquired through the helper's configured forky APT repositories.

```sh
apt-get update
apt-get install -y --no-install-recommends build-essential gcc-14 g++-14 cmake make debhelper bison libaio-dev libncurses-dev libjson-perl libldap-dev libsasl2-dev zlib1g-dev po-debconf psmisc elfutils lsb-release fakeroot libnuma-dev libmecab-dev libssl-dev pkg-config python3 file binutils patch xz-utils libtirpc-dev rpcsvc-proto libkrb5-dev libfido2-dev tzdata-legacy
mkdir -p "$WORKSPACE/downloads" "$WORKSPACE/src"
cd "$WORKSPACE"
curl -fL https://cdn.mysql.com/archives/mysql-8.4/mysql-8.4.0.tar.gz -o downloads/mysql-8.4.0.tar.gz
printf '%s  %s\n' 47a5433fcdd639db836b99e1b5459c2b813cbdad23ff2b5dd4ad27f792ba918e downloads/mysql-8.4.0.tar.gz | sha256sum -c -
tar -xzf downloads/mysql-8.4.0.tar.gz -C src
patch -d src/mysql-8.4.0 -p1 < "$RECIPE_DIR/patches/loongarch.patch"
for subdir in extra/tirpc/libtirpc-1.3.3 extra/icu/icu-release-73-1/source; do
  cp "$RECIPE_DIR/inputs/config.guess" "src/mysql-8.4.0/$subdir/config.guess"
  cp "$RECIPE_DIR/inputs/config.sub" "src/mysql-8.4.0/$subdir/config.sub"
done
cp "$RECIPE_DIR/configure-deb.sh" "$RECIPE_DIR/build-debs.sh" "$RECIPE_DIR/resume-debs.sh" .
bash configure-deb.sh
cp -a deb-config/debian src/mysql-8.4.0/debian
cp "$RECIPE_DIR"/packaging/* src/mysql-8.4.0/debian/
chmod +x src/mysql-8.4.0/debian/rules
(cd src/mysql-8.4.0 && dpkg-checkbuilddeps)
bash build-debs.sh
```

CMake generates the full upstream Debian tree under deb-config/debian. Overlay only the six retained final packaging inputs; the rest remains generated upstream packaging. The informational packaging-forky.patch also includes the authentication flags already present in configure-deb.sh, so do not blindly apply that whole patch again. Debian forky's libncurses-dev and libldap-dev satisfy the historical compatibility package names in upstream control. The systemd pkg-config module was available through the build dependencies in the accepted helper; dpkg-checkbuilddeps and CMake must both succeed before compiling.

This clean flow consolidates the exact accepted source/packaging inputs. The recorded final artifact production used an existing validated build tree: bash resume-debs.sh, then a clean service-only Debhelper repack. No fresh complete rebuild was performed while generating this recipe. The retained resume script clears both installation stamps. On an existing tree it runs cmake --build release --parallel 32 and dpkg-buildpackage -b -nc -uc -us -j32. Do not run it on a missing release directory. Fresh builds use build-debs.sh. Upstream rules run make test || true even with the recorded nocheck flag, so package-build success does not mean all unit tests passed.

Outputs are "$WORKSPACE/src/"*.deb. Preserve the twelve DEBs and .buildinfo/.changes separately; use dpkg-deb -f for architecture/version, readelf -h on extracted mysqld for LoongArch ELF, and calculate new SHA256 manifests. Existing prepared DEBs can be reused only when their bytes match mysql-packages.json. See ../../README.md for image assembly, adaptation.md for test limits, and experience.json for task-local successful execution provenance.
