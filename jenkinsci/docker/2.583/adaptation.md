# Jenkins 2.583 Alpine LoongArch64 adaptation

Source: https://github.com/jenkinsci/docker at commit 42ea8b6681fac34a1a8b447644728e70b3eeaae0, upstream file alpine/hotspot/Dockerfile.

Target: linux/loong64 image jenkins:2.583-alpine-loongarch64. The exact accepted Dockerfile is Dockerfile.alpine-loongarch64.

The final Dockerfile keeps the upstream Jenkins user, support scripts, ports, volume, labels and entrypoint. It adapts the upstream build as follows:

1. Both stages use lcr.loongnix.cn/library/alpine:latest, which resolved to Alpine 3.24.3 and the recorded digest during the verified build.
2. The upstream JDK download and jlink stage is replaced with Alpine's openjdk25-loongarch-jre-headless package at 25.0.1_p8-r1. The image inspection confirmed OpenJDK 64-Bit Server VM and the server libjvm.so.
3. The matching openjdk25-loongarch-jre package is installed alongside the required headless package. It supplies libfontmanager.so, which Jenkins needs during startup.
4. The Jenkins 2.583 WAR and Plugin Installation Manager 2.15.0 JAR are staged in the build context. The Dockerfile checks their SHA-256 values and verifies the WAR with the Jenkins signing key before use.

All retained changes are in the separately saved Dockerfile. The accepted upstream diff changed no other tracked project files, so there is no separate loongarch.patch.
