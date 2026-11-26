# MySQL 8.4.0 native LoongArch64 adaptations

`patches/loongarch.patch` contains the two accepted source patches, concatenated without editing their hunks.

* `include/my_rdtsc.h`, `mysys/my_rdtsc.cc`: register timer routine 31 and use GNU LoongArch64 `rdtime.d` for the stable counter. Preserve upstream runtime frequency calibration; do not infer this counter frequency from CPU GHz. Repeated consecutive values are valid, but regressions, no progress and zero frequency are failures.
* `unittest/gunit/mysys_my_rdtsc-t.cc`: allow equal consecutive counter readings while requiring monotonic progress and a selected routine.
* `storage/ndb/src/common/util/NodeCertificate.cpp`: set PKCS#10 CSR version to zero using checked `X509_REQ_set_version(req, 0)`. New OpenSSL rejects the previous unset (-1) version. The native A/B test and NodeCertificate unit executable passed after this change. This is compatibility with the newer build environment, not an architecture-specific OpenSSL defect.

Bundled ICU/libtirpc GNU config.guess and config.sub were refreshed by Debian's autotools configuration handling during the successful build. Exact consumed bytes are retained in the DEB recipe's inputs/ directory and must be copied to both documented destinations. These are build inputs, not a separately source-built toolchain dependency.

The DEB recipe retains final CMake/compiler flags and the required packaging changes. Systemd builds do not supply the obsolete mysqld_multi wrapper/manpages. System libfido2 does not supply a private bundled libfido2. Enable all authentication client plugins with system FIDO and Kerberos. Use upstream Debian mysql.service and mysql@.service plus their tmpfiles integration, excluding duplicate RPM-style mysqld service definitions.

For incremental packaging, remove both override_dh_auto_install and override_dh_installinit stamps before dpkg-buildpackage -nc: dh_prep removes package staging while stale stamps skip repopulating it. The accepted service DEB was regenerated from clean per-package Debhelper outputs with the upstream install-init target and standard Debhelper phases, preserving the payload and project-owned maintainer logic. Other eleven DEBs remained byte-identical. Avoid appending Debhelper-generated maintainer snippets repeatedly. A fresh build performs these phases once.

## Verified scope and limitations

Final runtime CYCLE frequency: 99800995 Hz, resolution 1. A requested SLEEP(0.2) produced a 0.20046488952 second Performance Schema wait; no CYCLE warning during startup or restart. Five timer unit tests, native monotonic/frequency/CPU migration probe, CSR tests and final SQL/TLS/persistence checks passed.

The full raw CTest run passed 134/136 groups and returned 8; the wrapper's zero exit code is not an all-tests-passed claim. Mysys.CreateTempFile failed on the helper backing filesystem and passed on tmpfs in the final image. The synthetic ut0rnd.hash_uint64_pair_distribution quality assertion still fails. Source review found key verification/fallback paths and no identified correctness or availability failure; adaptive hash indexing defaults OFF. Workload-specific efficiency has not been benchmarked. Keep this limitation visible rather than suppressing or changing the assertion. CET testing passes with tzdata-legacy. Full NDB cluster integration was not exercised; passing CSR/NDB unit tests do not certify it. MySQL Shell and Router are omitted intentionally.
