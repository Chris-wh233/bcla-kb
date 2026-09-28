# Jenkins 2.583 Debian LoongArch64

This recipe builds the Jenkins 2.583 Debian image for native LoongArch64
(`linux/loong64`) from the official Docker repository.

## Source

- Repository: https://github.com/jenkinsci/docker
- Version: `2.583`
- Resolved source commit: `42ea8b6681fac34a1a8b447644728e70b3eeaae0`
- Upstream Dockerfile: `debian/Dockerfile`

The exact-trixie LoongArch64 base tag requested by the upstream Dockerfile was not
available in the target registry. The verified build uses
`lcr.loongnix.cn/library/debian@sha256:f5ef929388a56fb070c8c86cd572e70b0241f13a227c624c36260ef067f43d2b`
(Debian Forky, LoongArch64) in both stages.

## Prepared inputs

Place these files in the Jenkins repository root before building:

- `.bcla-inputs/jenkins-2.583.war`
  - Source: https://get.jenkins.io/war/2.583/jenkins.war
  - SHA-256: `2eb6df14b0c1cda704ad88800395a071856774cadc4f64d9527d8ec8380b41c6`
  - Verify with the matching `.asc` signature and the Jenkins signing key
    `jenkins.io-2026.key` from the source repository.
- `.bcla-inputs/jenkins-2.583.war.asc`
  - Source: https://get.jenkins.io/war/2.583/jenkins.war.asc
- `.bcla-inputs/jenkins-plugin-manager-2.15.0.jar`
  - Source: https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.15.0/jenkins-plugin-manager-2.15.0.jar
  - SHA-256: `a86853ec2e2933f37a4b471ba65099b61e03c87a80c2ef8fe2315eb135672d43`

The accepted Dockerfile performs SHA-256 and GPG verification of the WAR and
SHA-256 plus `java -jar --version` verification of the plugin manager.

## Build

Check out the source at the resolved commit, then copy
`Dockerfile.debian.loong64` from this recipe to
`debian/Dockerfile`. From the Jenkins repository root, run:

```sh
DOCKER_BUILDKIT=0 docker build -f debian/Dockerfile -t jenkins:2.583 .
```

The build uses the USTC Debian mirror
`http://mirrors.ustc.edu.cn/debian` in both Dockerfile stages. The resulting
image observed in the verified build was:

- Image ID: `sha256:aa8b2baf898740872c3d8abff6cc4173af492fb041462c28f13af0803d4c812b`
- Platform: `linux/loong64`

## Verification

Run the accepted smoke test after the build. It verifies the LoongArch64 Java
runtime, Git LFS, WAR and plugin-manager files, the HarfBuzz dependency used by
the JRE, and Jenkins startup on port 8080. The Jenkins endpoint returned HTTP
403 after 18 seconds in the successful run; this is an HTTP response from the
running service, so it confirms that the listener was available.

The image was built and tested locally and was not pushed to a registry.
